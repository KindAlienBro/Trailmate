import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants.dart';

/// WebSocket Service — Socket.IO client for real-time communication.
///
/// Handles:
/// - Connection lifecycle with auto-reconnect
/// - Location broadcasting and receiving
/// - Alert and SOS event handling
/// - Route update synchronization
class WebSocketService {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _token;
  String? _currentGroupId;

  // Stream controllers for real-time events
  final _locationUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberLocationsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _sosController = StreamController<Map<String, dynamic>>.broadcast();
  final _routeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _tripEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _suggestionController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get locationUpdates => _locationUpdateController.stream;
  Stream<List<Map<String, dynamic>>> get memberLocations => _memberLocationsController.stream;
  Stream<Map<String, dynamic>> get alerts => _alertController.stream;
  Stream<Map<String, dynamic>> get sosEvents => _sosController.stream;
  Stream<Map<String, dynamic>> get routeUpdates => _routeUpdateController.stream;
  Stream<Map<String, dynamic>> get tripEvents => _tripEventController.stream;
  Stream<Map<String, dynamic>> get memberEvents => _memberEventController.stream;
  Stream<Map<String, dynamic>> get suggestions => _suggestionController.stream;

  bool get isConnected => _isConnected;

  /// Connect to the WebSocket server with authentication
  void connect(String token) {
    _token = token;

    _socket = io.io(
      AppConstants.serverWsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _setupListeners();
  }

  /// Set up all event listeners
  void _setupListeners() {
    final socket = _socket;
    if (socket == null) return;

    socket.onConnect((_) {
      _isConnected = true;
      debugPrint('[WS] Connected to server');

      // Re-subscribe to group if we were in one
      if (_currentGroupId != null) {
        subscribeToGroup(_currentGroupId!);
      }
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      debugPrint('[WS] Disconnected from server');
    });

    socket.onConnectError((error) {
      debugPrint('[WS] Connection error: $error');
    });

    // ==================== Location Events ====================
    socket.on('location:update', (data) {
      if (data is Map<String, dynamic>) {
        _locationUpdateController.add(data);
      }
    });

    socket.on('location:members', (data) {
      if (data is Map<String, dynamic> && data['members'] is List) {
        final members = (data['members'] as List)
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _memberLocationsController.add(members);
      }
    });

    // ==================== Alert Events ====================
    socket.on('alert:deviation', (data) {
      if (data is Map<String, dynamic>) {
        _alertController.add({...data, 'type': 'deviation'});
      }
    });

    socket.on('alert:separation', (data) {
      if (data is Map<String, dynamic>) {
        _alertController.add({...data, 'type': 'separation'});
      }
    });

    socket.on('alert:backOnRoute', (data) {
      if (data is Map<String, dynamic>) {
        _alertController.add({...data, 'type': 'backOnRoute'});
      }
    });

    socket.on('alert:regroup', (data) {
      if (data is Map<String, dynamic>) {
        _alertController.add({...data, 'type': 'regroup'});
      }
    });

    socket.on('alert:stopRequest', (data) {
      if (data is Map<String, dynamic>) {
        _alertController.add({...data, 'type': 'stopRequest'});
      }
    });

    // ==================== SOS Events ====================
    socket.on('sos:triggered', (data) {
      if (data is Map<String, dynamic>) {
        _sosController.add({...data, 'type': 'triggered'});
      }
    });

    socket.on('sos:acknowledged', (data) {
      if (data is Map<String, dynamic>) {
        _sosController.add({...data, 'type': 'acknowledged'});
      }
    });

    socket.on('sos:cancelled', (data) {
      if (data is Map<String, dynamic>) {
        _sosController.add({...data, 'type': 'cancelled'});
      }
    });

    // ==================== Route Events ====================
    socket.on('route:updated', (data) {
      if (data is Map<String, dynamic>) {
        _routeUpdateController.add(data);
      }
    });

    // ==================== Trip Events ====================
    socket.on('trip:started', (data) {
      if (data is Map<String, dynamic>) {
        _tripEventController.add({...data, 'type': 'started'});
      }
    });

    socket.on('trip:ended', (data) {
      if (data is Map<String, dynamic>) {
        _tripEventController.add({...data, 'type': 'ended'});
      }
    });

    // ==================== Member Events ====================
    socket.on('member:joined', (data) {
      if (data is Map<String, dynamic>) {
        _memberEventController.add({...data, 'type': 'joined'});
      }
    });

    // ==================== Error ====================
    socket.on('error', (data) {
      debugPrint('[WS] Server error: $data');
    });

    // ==================== Smart Suggestion Events ====================
    socket.on('suggestion:show', (data) {
      if (data is Map<String, dynamic>) {
        _suggestionController.add(data);
      }
    });
  }

  // ==================== Emit Methods ====================

  /// Subscribe to a group's real-time events
  void subscribeToGroup(String groupId) {
    _currentGroupId = groupId;
    _socket?.emit('location:subscribe', {'groupId': groupId});
  }

  /// Unsubscribe from a group
  void unsubscribeFromGroup(String groupId) {
    _socket?.emit('location:unsubscribe', {'groupId': groupId});
    _currentGroupId = null;
  }

  /// Re-subscribe to the current group room after connectivity is restored.
  /// Socket.IO handles transport reconnection itself — this just ensures
  /// we're in the right room after the socket auto-reconnects.
  void reconnectToGroup() {
    if (_currentGroupId != null) {
      debugPrint('[WS] Re-subscribing to group room: $_currentGroupId');
      subscribeToGroup(_currentGroupId!);
    }
  }

  /// Send current location to the group
  void sendLocation({
    required String groupId,
    required double lat,
    required double lng,
    double? speed,
    double? heading,
  }) {
    if (!_isConnected) return;
    _socket?.emit('location:update', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
      'speed': speed ?? 0,
      'heading': heading ?? 0,
    });
  }

  /// Send a batch of queued offline locations in a single emit.
  /// The server should handle the 'location:batch' event to process the array.
  /// Falls back to sending individual updates if batch isn't supported.
  void sendLocationBatch({
    required String groupId,
    required List<Map<String, dynamic>> locations,
  }) {
    if (!_isConnected || locations.isEmpty) return;
    // Try batch first
    _socket?.emit('location:batch', {
      'groupId': groupId,
      'locations': locations,
    });
    debugPrint('[WS] Flushed ${locations.length} queued locations as batch');
  }

  /// Check for deviation from route
  void checkDeviation({
    required String groupId,
    required double lat,
    required double lng,
  }) {
    if (!_isConnected) return;
    _socket?.emit('alert:checkDeviation', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Check separation from leader
  void checkSeparation({
    required String groupId,
    required double lat,
    required double lng,
  }) {
    if (!_isConnected) return;
    _socket?.emit('alert:checkSeparation', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Trigger SOS emergency
  void triggerSOS({
    required String groupId,
    double? lat,
    double? lng,
    String? message,
    String triggerSource = 'manual',
  }) {
    _socket?.emit('sos:trigger', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
      'message': message,
      'triggerSource': triggerSource,
    });
  }

  /// Cancel SOS
  void cancelSOS(String groupId) {
    _socket?.emit('sos:cancel', {'groupId': groupId});
  }

  /// Trigger Regroup (leader only)
  void triggerRegroup({
    required String groupId,
    required double lat,
    required double lng,
  }) {
    _socket?.emit('alert:triggerRegroup', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Request Stop
  void requestStop({
    required String groupId,
    required double lat,
    required double lng,
    required String reason,
  }) {
    _socket?.emit('alert:requestStop', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
      'reason': reason,
    });
  }

  /// Acknowledge SOS (leader only)
  void acknowledgeSOS({
    required String groupId,
    required String targetUserId,
  }) {
    _socket?.emit('sos:acknowledge', {
      'groupId': groupId,
      'targetUserId': targetUserId,
    });
  }

  /// Update route (leader only)
  void updateRoute({
    required String groupId,
    Map<String, dynamic>? origin,
    Map<String, dynamic>? destination,
    List<Map<String, dynamic>>? waypoints,
    String? polyline,
    List<Map<String, double>>? polylinePoints,
    int? distanceMeters,
    int? durationSeconds,
  }) {
    _socket?.emit('route:update', {
      'groupId': groupId,
      if (origin != null) 'origin': origin,
      if (destination != null) 'destination': destination,
      if (waypoints != null) 'waypoints': waypoints,
      if (polyline != null) 'polyline': polyline,
      if (polylinePoints != null) 'polylinePoints': polylinePoints,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });
  }

  /// Start trip (leader only)
  void startTrip(String groupId) {
    _socket?.emit('trip:start', {'groupId': groupId});
  }

  /// End trip (leader only)
  void endTrip(String groupId) {
    _socket?.emit('trip:end', {'groupId': groupId});
  }

  /// Notify group that member joined
  void notifyMemberJoined(String groupId) {
    _socket?.emit('member:joined', {'groupId': groupId});
  }

  /// Request smart suggestions from the server
  void checkSuggestions({
    required String groupId,
    required double lat,
    required double lng,
    required double elapsedMinutes,
    required double distanceTraveled,
    bool isStopped = false,
  }) {
    if (!_isConnected) return;
    _socket?.emit('suggestion:check', {
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
      'elapsedMinutes': elapsedMinutes,
      'distanceTraveled': distanceTraveled,
      'isStopped': isStopped,
    });
  }

  /// Disconnect from server
  void disconnect() {
    _currentGroupId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  /// Dispose all stream controllers
  void dispose() {
    disconnect();
    _locationUpdateController.close();
    _memberLocationsController.close();
    _alertController.close();
    _sosController.close();
    _routeUpdateController.close();
    _tripEventController.close();
    _memberEventController.close();
    _suggestionController.close();
  }
}
