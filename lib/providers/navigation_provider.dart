import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import '../services/websocket_service.dart';
import '../services/location_service.dart';
import '../services/ola_maps_service.dart';
import '../providers/group_provider.dart';
import '../utils/polyline_decoder.dart';

/// Navigation Provider — manages live navigation state.
///
/// Holds member positions, route data, alerts, and nearby POIs.
class NavigationProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final LocationService _locationService = LocationService();
  final OlaMapsService _olaMapsService = OlaMapsService();
  final FlutterTts _tts = FlutterTts();

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // State
  String? _currentGroupId;
  GroupModel? _navigatingGroup;
  String? _currentUserId;
  String? _currentUserName;
  bool _isNavigating = false;
  Map<String, MemberPosition> _memberPositions = {};
  List<LatLng> _routePolyline = [];
  List<RouteStep> _routeSteps = [];
  double _routeDistance = 0; // meters (initial total)
  double _routeDuration = 0; // seconds (initial total)
  double _remainingDistance = 0; // meters (dynamic, updates as you drive)
  double _remainingDuration = 0; // seconds (dynamic)
  List<AlertData> _activeAlerts = [];
  List<NearbyPlace> _nearbyPlaces = [];
  bool _isSosActive = false;
  String? _sosUserId;
  double? _initialRouteBearing;

  // Step tracking
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;

  // Rerouting
  bool _isRerouting = false;
  DateTime? _lastRerouteTime;
  int _consecutiveOffRoute = 0; // Tracks consecutive off-route GPS readings
  static const _rerouteCooldown = Duration(seconds: 10);
  static const _deviationThreshold = 15.0; // meters — perpendicular to segment

  // Arrival
  bool _hasArrived = false;
  DateTime? _tripStartTime;
  double _totalDistanceTraveled = 0; // meters

  // TTS
  bool _ttsEnabled = true;
  bool _hasSpokenApproachWarning = false;

  // Getters
  WebSocketService get wsService => _wsService;
  LocationService get locationService => _locationService;
  OlaMapsService get olaMapsService => _olaMapsService;
  bool get isNavigating => _isNavigating;
  Map<String, MemberPosition> get memberPositions => _memberPositions;
  List<LatLng> get routePolyline => _routePolyline;
  List<RouteStep> get routeSteps => _routeSteps;
  RouteStep? get currentStep => _routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length ? _routeSteps[_currentStepIndex] : null;
  double get distanceToNextStep => _distanceToNextStep;
  double get routeDistance => _routeDistance;
  double get routeDuration => _routeDuration;
  double get remainingDistance => _remainingDistance;
  double get remainingDuration => _remainingDuration;
  List<AlertData> get activeAlerts => _activeAlerts;
  List<NearbyPlace> get nearbyPlaces => _nearbyPlaces;
  bool get isSosActive => _isSosActive;
  String? get sosUserId => _sosUserId;
  double? get initialRouteBearing => _initialRouteBearing;
  bool get isRerouting => _isRerouting;
  bool get hasArrived => _hasArrived;
  DateTime? get tripStartTime => _tripStartTime;
  double get totalDistanceTraveled => _totalDistanceTraveled;
  bool get ttsEnabled => _ttsEnabled;

  /// Initialize with auth token
  void initialize(String token, String currentUserId, String currentUserName) {
    _currentUserId = currentUserId;
    _currentUserName = currentUserName;
    _olaMapsService.setToken(token);
    _wsService.connect(token);
    _setupListeners();
    _initTts();
  }

  /// Initialize TTS engine
  void _initTts() {
    _tts.setLanguage('en-IN');
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  /// Toggle TTS on/off
  void toggleTts() {
    _ttsEnabled = !_ttsEnabled;
    if (!_ttsEnabled) {
      _tts.stop();
    }
    notifyListeners();
  }

  /// Speak a navigation instruction
  void _speak(String text) {
    if (_ttsEnabled) {
      _tts.speak(text);
    }
  }

  /// Set up WebSocket and location listeners
  void _setupListeners() {
    // Location updates from other members
    _subscriptions.add(
      _wsService.locationUpdates.listen((data) {
        final userId = data['userId'] as String?;
        // Don't overwrite local user's position from WS since we update it locally instantly
        if (userId != null && userId != _currentUserId) {
          _memberPositions[userId] = MemberPosition(
            userId: userId,
            name: data['name'] ?? '',
            lat: (data['lat'] as num).toDouble(),
            lng: (data['lng'] as num).toDouble(),
            speed: (data['speed'] as num?)?.toDouble() ?? 0,
            heading: (data['heading'] as num?)?.toDouble() ?? 0,
            status: data['status'] ?? 'on-route',
            timestamp: DateTime.now(),
          );
          notifyListeners();

          if (_routePolyline.isEmpty && _navigatingGroup != null && userId == _navigatingGroup!.leaderId && !_navigatingGroup!.isLeader(_currentUserId!)) {
            _calculatePersonalRoute();
          }
        }
      }),
    );

    // Initial member locations
    _subscriptions.add(
      _wsService.memberLocations.listen((members) {
        for (final m in members) {
          final userId = m['userId'] as String?;
          final loc = m['location'] as Map<String, dynamic>?;
          if (userId != null && loc != null && loc['lat'] != null) {
            _memberPositions[userId] = MemberPosition(
              userId: userId,
              name: m['name'] ?? '',
              lat: (loc['lat'] as num).toDouble(),
              lng: (loc['lng'] as num).toDouble(),
              speed: (loc['speed'] as num?)?.toDouble() ?? 0,
              heading: (loc['heading'] as num?)?.toDouble() ?? 0,
              status: m['status'] ?? 'waiting',
              timestamp: loc['updatedAt'] != null
                  ? DateTime.tryParse(loc['updatedAt']) ?? DateTime.now()
                  : DateTime.now(),
            );
          }
        }
        notifyListeners();

        if (_routePolyline.isEmpty && _navigatingGroup != null && _memberPositions.containsKey(_navigatingGroup!.leaderId) && !_navigatingGroup!.isLeader(_currentUserId!)) {
          _calculatePersonalRoute();
        }
      }),
    );

    // Alerts
    _subscriptions.add(
      _wsService.alerts.listen((data) {
        final type = data['type'] ?? 'unknown';
        final userId = data['userId'] ?? '';

        // Prevent flooding: ignore if an alert of this type for this user is already showing
        if (_activeAlerts.any((a) => a.type == type && a.userId == userId)) {
          return;
        }

        final alert = AlertData(
          type: type,
          userId: userId,
          name: data['name'] ?? '',
          message: data['message'] ?? '',
          timestamp: DateTime.now(),
        );

        _activeAlerts.add(alert);
        
        // Prevent screen overflow by capping at 3 alerts
        if (_activeAlerts.length > 3) {
          _activeAlerts.removeAt(0);
        }
        
        notifyListeners();

        // Auto-remove THIS specific alert after 5 seconds (faster cleanup)
        Future.delayed(const Duration(seconds: 5), () {
          if (_activeAlerts.contains(alert)) {
            _activeAlerts.remove(alert);
            notifyListeners();
          }
        });

        // Auto-reroute if current user deviates
        if (type == 'deviation' && userId == _currentUserId) {
          _calculatePersonalRoute();
        }
      }),
    );

    // SOS events
    _subscriptions.add(
      _wsService.sosEvents.listen((data) {
        final type = data['type'] as String;
        if (type == 'triggered') {
          _isSosActive = true;
          _sosUserId = data['userId'];
          _activeAlerts.add(AlertData(
            type: 'sos',
            userId: data['userId'] ?? '',
            name: data['name'] ?? '',
            message: data['message'] ?? 'Emergency!',
            timestamp: DateTime.now(),
            lat: (data['lat'] as num?)?.toDouble(),
            lng: (data['lng'] as num?)?.toDouble(),
          ));
        } else if (type == 'cancelled') {
          _isSosActive = false;
          _sosUserId = null;
        }
        notifyListeners();
      }),
    );

    // GPS location stream
    _subscriptions.add(
      _locationService.positionStream.listen((position) {
        if (_currentGroupId != null && _isNavigating && _currentUserId != null) {
          
          // Track distance traveled
          final prevPos = _memberPositions[_currentUserId!];
          if (prevPos != null) {
            final delta = LocationService.distanceBetween(
              prevPos.lat, prevPos.lng, position.latitude, position.longitude,
            );
            if (delta < 500) { // Ignore teleportation glitches
              _totalDistanceTraveled += delta;
            }
          }

          // 1. Update local user position immediately for instant UI feedback
          _memberPositions[_currentUserId!] = MemberPosition(
            userId: _currentUserId!,
            name: _currentUserName ?? 'Me',
            lat: position.latitude,
            lng: position.longitude,
            speed: position.speed * 3.6,
            heading: position.heading,
            status: _memberPositions[_currentUserId!]?.status ?? 'on-route',
            timestamp: DateTime.now(),
          );
          notifyListeners();

          // 2. Broadcast to others
          _wsService.sendLocation(
            groupId: _currentGroupId!,
            lat: position.latitude,
            lng: position.longitude,
            speed: position.speed * 3.6, // m/s → km/h
            heading: position.heading,
          );

          // 3. Check deviation and separation
          _wsService.checkDeviation(
            groupId: _currentGroupId!,
            lat: position.latitude,
            lng: position.longitude,
          );
          _wsService.checkSeparation(
            groupId: _currentGroupId!,
            lat: position.latitude,
            lng: position.longitude,
          );

          // 4. Check deviation from route (Off-route auto-rerouting)
          if (_routePolyline.isNotEmpty && !_isRerouting) {
            // Calculate perpendicular distance to nearest polyline SEGMENT (not just vertices)
            final minDistance = _distanceToPolyline(position.latitude, position.longitude);
            
            // If user is more than threshold off the nearest route segment, trigger reroute
            if (minDistance > _deviationThreshold) {
              _consecutiveOffRoute++;
              
              // Only reroute after 3 consecutive off-route readings (prevents GPS noise)
              if (_consecutiveOffRoute >= 3) {
                final now = DateTime.now();
                if (_lastRerouteTime == null || now.difference(_lastRerouteTime!) > _rerouteCooldown) {
                  _lastRerouteTime = now;
                  _isRerouting = true;
                  _consecutiveOffRoute = 0;
                  notifyListeners();
                  debugPrint('[Navigation] User is ${minDistance.toStringAsFixed(1)}m off route for 3+ readings. Rerouting...');
                  _speak('Rerouting');
                  _calculatePersonalRoute().whenComplete(() {
                    _isRerouting = false;
                    notifyListeners();
                  });
                }
              }
            } else {
              _consecutiveOffRoute = 0; // Reset counter when back on route
              
              if (_routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length) {
                // 4b. Responsive Step Progression
                final currentStepData = _routeSteps[_currentStepIndex];
                final distToTurn = LocationService.distanceBetween(
                  position.latitude, position.longitude, 
                  currentStepData.endLocation.latitude, currentStepData.endLocation.longitude,
                );
                
                _distanceToNextStep = distToTurn;

                // Approach warning TTS at 200m
                if (distToTurn < 200.0 && !_hasSpokenApproachWarning && _currentStepIndex < _routeSteps.length - 1) {
                  _hasSpokenApproachWarning = true;
                  final nextStep = _routeSteps[_currentStepIndex + 1];
                  _speak('In ${distToTurn.round()} meters, ${nextStep.instruction}');
                }

                // If we are within 25 meters of the turn, advance to next instruction
                if (distToTurn < 25.0 && _currentStepIndex < _routeSteps.length - 1) {
                  _currentStepIndex++;
                  _hasSpokenApproachWarning = false; // Reset for next step
                  final newStep = _routeSteps[_currentStepIndex];
                  _distanceToNextStep = newStep.distance; // reset to full distance initially
                  _speak(newStep.instruction);

                  // Update remaining distance/duration dynamically
                  _updateRemainingStats();
                }

                // 4c. Arrival Detection
                if (_currentStepIndex >= _routeSteps.length - 1 && distToTurn < 50.0) {
                  if (!_hasArrived) {
                    _hasArrived = true;
                    _speak('You have arrived at your destination');
                    notifyListeners();
                  }
                }

                notifyListeners();
              }
            }
          }

          // 5. Calculate route if not done yet (e.g. initial start)
          if (_routePolyline.isEmpty && _navigatingGroup != null && !_isRerouting) {
            _calculatePersonalRoute();
          }
        }
      }),
    );
  }

  /// Calculate the shortest perpendicular distance from a point to the route polyline.
  /// This checks every LINE SEGMENT (not just vertices), so it catches
  /// when you're on a parallel road that runs between two polyline vertices.
  double _distanceToPolyline(double lat, double lng) {
    if (_routePolyline.length < 2) {
      // Fallback: distance to single point
      if (_routePolyline.isNotEmpty) {
        return LocationService.distanceBetween(lat, lng, _routePolyline[0].latitude, _routePolyline[0].longitude);
      }
      return double.infinity;
    }

    double minDist = double.infinity;
    for (int i = 0; i < _routePolyline.length - 1; i++) {
      final a = _routePolyline[i];
      final b = _routePolyline[i + 1];
      final dist = _pointToSegmentDistance(lat, lng, a.latitude, a.longitude, b.latitude, b.longitude);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  /// Perpendicular distance from point P to line segment AB, in meters.
  /// Projects P onto AB; if projection falls outside the segment, returns
  /// distance to the nearest endpoint.
  double _pointToSegmentDistance(
    double pLat, double pLng,
    double aLat, double aLng,
    double bLat, double bLng,
  ) {
    final dx = bLng - aLng;
    final dy = bLat - aLat;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      // A and B are the same point
      return LocationService.distanceBetween(pLat, pLng, aLat, aLng);
    }

    // Project point P onto line AB, clamped to [0, 1]
    double t = ((pLng - aLng) * dx + (pLat - aLat) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;

    final projLat = aLat + t * dy;
    final projLng = aLng + t * dx;

    return LocationService.distanceBetween(pLat, pLng, projLat, projLng);
  }

  /// Recalculate remaining distance/duration from current step onward
  void _updateRemainingStats() {
    double dist = 0;
    double dur = 0;
    for (int i = _currentStepIndex; i < _routeSteps.length; i++) {
      dist += _routeSteps[i].distance;
      dur += _routeSteps[i].duration;
    }
    _remainingDistance = dist;
    _remainingDuration = dur;
  }

  /// Start navigation for a group
  Future<void> startNavigation(GroupModel group) async {
    _currentGroupId = group.id;
    _navigatingGroup = group;
    _isNavigating = true;
    _hasArrived = false;
    _tripStartTime = DateTime.now();
    _totalDistanceTraveled = 0;
    _currentStepIndex = 0;
    _isRerouting = false;
    _lastRerouteTime = null;
    _consecutiveOffRoute = 0;

    // Subscribe to group WebSocket room
    _wsService.subscribeToGroup(group.id);

    // Start GPS tracking
    final hasPermission = await _locationService.requestPermissions();
    if (hasPermission) {
      _locationService.startTracking();
    }

    notifyListeners();

    if (_locationService.lastPosition != null) {
      await _calculatePersonalRoute();
    }
  }

  /// Stop navigation
  void stopNavigation() {
    if (_currentGroupId != null) {
      _wsService.unsubscribeFromGroup(_currentGroupId!);
    }
    _locationService.stopTracking();
    _tts.stop();
    _isNavigating = false;
    _currentGroupId = null;
    _navigatingGroup = null;
    _routePolyline.clear();
    _routeSteps.clear();
    _routeDistance = 0;
    _routeDuration = 0;
    _remainingDistance = 0;
    _remainingDuration = 0;
    _memberPositions.clear();
    _activeAlerts.clear();
    _nearbyPlaces.clear();
    _isSosActive = false;
    _sosUserId = null;
    _initialRouteBearing = null;
    _hasArrived = false;
    _isRerouting = false;
    _currentStepIndex = 0;
    _distanceToNextStep = 0;
    _consecutiveOffRoute = 0;
    notifyListeners();
  }

  /// Reset arrival state (for dismissing the arrival screen)
  void dismissArrival() {
    _hasArrived = false;
    notifyListeners();
  }

  /// Set route polyline (decoded from directions API)
  void setRoutePolyline(List<LatLng> points) {
    _routePolyline = points;
    notifyListeners();
  }

  /// Calculates personal route from current position to destination
  Future<void> _calculatePersonalRoute() async {
    if (_navigatingGroup == null || _currentUserId == null) return;
    
    final me = _locationService.lastPosition;
    if (me == null) return;

    double destLat;
    double destLng;

    if (_navigatingGroup!.isLeader(_currentUserId!)) {
      final dest = _navigatingGroup!.route.destination;
      if (!dest.hasLocation) return;
      destLat = dest.lat!;
      destLng = dest.lng!;
    } else {
      final leaderId = _navigatingGroup!.leaderId;
      final leaderPos = _memberPositions[leaderId];
      if (leaderPos == null) {
        debugPrint('[Navigation] Waiting for leader position to route.');
        return;
      }
      destLat = leaderPos.lat;
      destLng = leaderPos.lng;
    }

    try {
      final result = await _olaMapsService.getDirections(
        originLat: me.latitude,
        originLng: me.longitude,
        destLat: destLat,
        destLng: destLng,
        mode: _navigatingGroup?.route.transportMode,
      );

      final routes = result['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final route = routes[0];
        
        // Parse Polyline
        final polylineStr = route['overview_polyline'];
        if (polylineStr != null) {
          final points = decodePolyline(polylineStr);
          if (points.isNotEmpty) {
            points.insert(0, LatLng(me.latitude, me.longitude));
          }
          setRoutePolyline(points);
          
          if (points.length >= 2) {
            _initialRouteBearing = LocationService.bearingBetween(
              points[0].latitude, points[0].longitude,
              points[1].latitude, points[1].longitude,
            );
          }
        }

        // Parse distance and duration (from the first leg)
        final legs = route['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final leg = legs[0];
          _routeDistance = (leg['distance'] as num?)?.toDouble() ?? 0;
          _routeDuration = (leg['duration'] as num?)?.toDouble() ?? 0;
          _remainingDistance = _routeDistance;
          _remainingDuration = _routeDuration;

          // Parse steps
          final stepsJson = leg['steps'] as List?;
          if (stepsJson != null) {
            _routeSteps = stepsJson.map((s) => RouteStep.fromJson(s)).toList();
            _currentStepIndex = 0;
            _hasSpokenApproachWarning = false;
            _distanceToNextStep = _routeSteps.isNotEmpty ? _routeSteps[0].distance : 0;
            
            // Speak first instruction
            if (_routeSteps.isNotEmpty) {
              _speak(_routeSteps[0].instruction);
            }
          } else {
            _routeSteps = [];
            _currentStepIndex = 0;
            _distanceToNextStep = 0;
          }
        }
        
        notifyListeners();
        debugPrint('[Navigation] Personal route calculated: ${_routeDistance}m, ${_routeSteps.length} steps');
      }
    } catch (e) {
      debugPrint('[Navigation] Failed to calculate personal route: $e');
    }
  }

  /// Fetch nearby places of a given type
  Future<void> fetchNearbyPlaces(double lat, double lng, String type) async {
    try {
      final result = await _olaMapsService.nearbySearch(
        lat: lat,
        lng: lng,
        type: type,
      );

      final predictions = result['predictions'] as List? ?? [];
      _nearbyPlaces = predictions
          .map((p) => NearbyPlace.fromJson(p))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Nearby search error: $e');
    }
  }

  /// Clear alerts
  void clearAlerts() {
    _activeAlerts.clear();
    notifyListeners();
  }

  /// Dismiss a specific alert
  void dismissAlert(int index) {
    if (index < _activeAlerts.length) {
      _activeAlerts.removeAt(index);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _wsService.dispose();
    _locationService.dispose();
    _tts.stop();
    super.dispose();
  }
}

// ==================== Data Models ====================

class MemberPosition {
  final String userId;
  final String name;
  final double lat;
  final double lng;
  final double speed;
  final double heading;
  final String status;
  final DateTime timestamp;

  MemberPosition({
    required this.userId,
    required this.name,
    required this.lat,
    required this.lng,
    this.speed = 0,
    this.heading = 0,
    this.status = 'on-route',
    required this.timestamp,
  });

  LatLng get latLng => LatLng(lat, lng);
}

class AlertData {
  final String type;
  final String userId;
  final String name;
  final String message;
  final DateTime timestamp;
  final double? lat;
  final double? lng;

  AlertData({
    required this.type,
    required this.userId,
    required this.name,
    required this.message,
    required this.timestamp,
    this.lat,
    this.lng,
  });
}

class NearbyPlace {
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final double? rating;
  final String? type;

  NearbyPlace({
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.rating,
    this.type,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    return NearbyPlace(
      name: json['structured_formatting']?['main_text'] ??
          json['description'] ??
          json['name'] ??
          '',
      address: json['structured_formatting']?['secondary_text'] ??
          json['formatted_address'],
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      type: json['type'],
    );
  }
}

class RouteStep {
  final double distance;
  final double duration;
  final String instruction;
  final String maneuverType;
  final LatLng location;
  final LatLng endLocation;

  RouteStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.maneuverType,
    required this.location,
    required this.endLocation,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'] as Map<String, dynamic>?;
    LatLng latLng = const LatLng(0, 0);
    if (startLoc != null) {
      latLng = LatLng(
        (startLoc['lat'] as num?)?.toDouble() ?? 0,
        (startLoc['lng'] as num?)?.toDouble() ?? 0,
      );
    }
    
    final endLoc = json['end_location'] as Map<String, dynamic>?;
    LatLng endLatLng = latLng; // fallback
    if (endLoc != null) {
      endLatLng = LatLng(
        (endLoc['lat'] as num?)?.toDouble() ?? 0,
        (endLoc['lng'] as num?)?.toDouble() ?? 0,
      );
    }

    String rawInstruction = json['instructions']?.toString() ?? '';
    String cleanedInstruction = rawInstruction.replaceAll(
      RegExp(r'^Head\s+(north|south|east|west)(?:-(east|west))?', caseSensitive: false),
      'Continue straight',
    );

    return RouteStep(
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      instruction: cleanedInstruction,
      maneuverType: json['maneuver']?.toString() ?? '',
      location: latLng,
      endLocation: endLatLng,
    );
  }
}
