import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Group model
class GroupModel {
  final String id;
  final String name;
  final String inviteCode;
  final String leaderId;
  final List<MemberModel> members;
  final RouteModel route;
  final String status;
  final DateTime? createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.members,
    required this.route,
    required this.status,
    this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
      leaderId: json['leaderId'] ?? '',
      members: (json['members'] as List?)
              ?.map((m) => MemberModel.fromJson(m))
              .toList() ??
          [],
      route: RouteModel.fromJson(json['route'] ?? {}),
      status: json['status'] ?? 'planning',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  bool isLeader(String userId) => leaderId == userId;
  bool isMember(String userId) => members.any((m) => m.userId == userId);
}

/// Member model
class MemberModel {
  final String odId;
  final String userId;
  final String name;
  final String? avatar;
  final String role;
  final String status;
  final LocationData? lastLocation;

  MemberModel({
    required this.odId,
    required this.userId,
    required this.name,
    this.avatar,
    required this.role,
    required this.status,
    this.lastLocation,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      odId: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      role: json['role'] ?? 'member',
      status: json['status'] ?? 'waiting',
      lastLocation: json['lastLocation'] != null
          ? LocationData.fromJson(json['lastLocation'])
          : null,
    );
  }

  bool get isLeader => role == 'leader';
}

/// Location data
class LocationData {
  final double? lat;
  final double? lng;
  final double speed;
  final double heading;
  final DateTime? updatedAt;

  LocationData({this.lat, this.lng, this.speed = 0, this.heading = 0, this.updatedAt});

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  bool get hasLocation => lat != null && lng != null;
}

/// Route model
class RouteModel {
  final PlaceModel origin;
  final PlaceModel destination;
  final List<WaypointModel> waypoints;
  final List<AIWaypoint> aiWaypoints;
  final String? polyline;
  final int distanceMeters;
  final int durationSeconds;
  final String transportMode;
  final String routeMode;
  final String routeCharacter;

  RouteModel({
    required this.origin,
    required this.destination,
    this.waypoints = const [],
    this.aiWaypoints = const [],
    this.polyline,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.transportMode = 'driving',
    this.routeMode = 'highway',
    this.routeCharacter = '',
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      origin: PlaceModel.fromJson(json['origin'] ?? {}),
      destination: PlaceModel.fromJson(json['destination'] ?? {}),
      waypoints: (json['waypoints'] as List?)
              ?.map((w) => WaypointModel.fromJson(w))
              .toList() ??
          [],
      aiWaypoints: (json['aiWaypoints'] as List?)
              ?.map((w) => AIWaypoint.fromJson(w))
              .toList() ??
          [],
      polyline: json['polyline'],
      distanceMeters: json['distanceMeters'] ?? 0,
      durationSeconds: json['durationSeconds'] ?? 0,
      transportMode: json['transportMode'] ?? 'driving',
      routeMode: json['routeMode'] ?? 'highway',
      routeCharacter: json['routeCharacter'] ?? '',
    );
  }

  bool get hasRoute => origin.hasLocation && destination.hasLocation;
  bool get isAdventure => routeMode == 'adventure' || routeMode == 'full_adventure';

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceMeters m';
  }

  String get durationText {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String get routeModeEmoji {
    switch (routeMode) {
      case 'adventure': return '\u{1F3D4}\u{FE0F}';
      case 'full_adventure': return '\u{1F30A}';
      default: return '\u{1F6E3}\u{FE0F}';
    }
  }

  String get routeModeTitle {
    switch (routeMode) {
      case 'adventure': return 'Adventure';
      case 'full_adventure': return 'Full Adventure';
      default: return 'Highway';
    }
  }
}

/// Place model
class PlaceModel {
  final double? lat;
  final double? lng;
  final String name;
  final String address;

  PlaceModel({this.lat, this.lng, this.name = '', this.address = ''});

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'name': name,
        'address': address,
      };

  bool get hasLocation => lat != null && lng != null;
}

/// Waypoint model
class WaypointModel {
  final double lat;
  final double lng;
  final String name;
  final String address;
  final int order;

  WaypointModel({
    required this.lat,
    required this.lng,
    this.name = '',
    this.address = '',
    this.order = 0,
  });

  factory WaypointModel.fromJson(Map<String, dynamic> json) {
    return WaypointModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}

/// AI-generated waypoint (from Gemini)
class AIWaypoint {
  final double lat;
  final double lng;
  final String name;
  final String reason;
  final String type; // scenic, curvy_road, mountain_pass, waterfall, jungle, water_crossing, viewpoint, heritage
  final String? photoUrl;

  AIWaypoint({
    required this.lat,
    required this.lng,
    required this.name,
    this.reason = '',
    this.type = 'scenic',
    this.photoUrl,
  });

  factory AIWaypoint.fromJson(Map<String, dynamic> json) {
    return AIWaypoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] ?? '',
      reason: json['reason'] ?? '',
      type: json['type'] ?? 'scenic',
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'name': name,
    'reason': reason,
    'type': type,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  String get emoji {
    switch (type) {
      case 'curvy_road': return '\u{1F6E3}\u{FE0F}';
      case 'mountain_pass': return '\u{26F0}\u{FE0F}';
      case 'waterfall': return '\u{1F4A7}';
      case 'dam': return '\u{1F3ED}'; // 🏭 (or 🧱)
      case 'lake': return '\u{1F3DE}\u{FE0F}'; // 🏞️
      case 'cave': return '\u{1F987}'; // 🦇
      case 'attraction': return '\u{1F3A2}'; // 🎢
      case 'jungle': return '\u{1F333}';
      case 'water_crossing': return '\u{1F30A}';
      case 'viewpoint': return '\u{1F304}';
      case 'heritage': return '\u{1F3DF}\u{FE0F}';
      case 'museum': return '\u{1F3DB}\u{FE0F}'; // 🏛️
      case 'monument': return '\u{1F5FD}'; // 🗽
      case 'restaurant': return '\u{1F35D}'; // 🍝
      case 'cafe': return '\u{2615}'; // ☕
      case 'bakery': return '\u{1F950}'; // 🥐
      case 'beach': return '\u{1F3D6}\u{FE0F}'; // 🏖️
      case 'marina': return '\u{26F5}'; // ⛵
      case 'worship': return '\u{1F6D0}'; // 🛐
      case 'national_park': return '\u{1F3DE}\u{FE0F}'; // 🏞️
      case 'zoo': return '\u{1F418}'; // 🐘
      case 'scenic':
      default:
        return '\u{1F4CD}';
    }
  }
}

/// Group Provider — manages group CRUD and state
class GroupProvider extends ChangeNotifier {
  String? _token;
  List<GroupModel> _myGroups = [];
  GroupModel? _currentGroup;
  bool _isLoading = false;
  String? _errorMessage;

  List<GroupModel> get myGroups => _myGroups;
  GroupModel? get currentGroup => _currentGroup;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Fetch all groups the current user is part of
  Future<void> fetchMyGroups() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.myGroupsEndpoint}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _myGroups = (data['groups'] as List)
            .map((g) => GroupModel.fromJson(g))
            .toList();
      }
    } catch (e) {
      debugPrint('Fetch groups error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new group
  Future<GroupModel?> createGroup({
    required String name,
    PlaceModel? origin,
    PlaceModel? destination,
    String? polyline,
    int? distanceMeters,
    int? durationSeconds,
    String transportMode = 'driving',
    String routeMode = 'highway',
    List<AIWaypoint>? aiWaypoints,
    String? routeCharacter,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'name': name,
        'transportMode': transportMode,
        'routeMode': routeMode,
      };
      if (origin != null) body['origin'] = origin.toJson();
      if (destination != null) body['destination'] = destination.toJson();
      if (polyline != null) body['polyline'] = polyline;
      if (distanceMeters != null) body['distanceMeters'] = distanceMeters;
      if (durationSeconds != null) body['durationSeconds'] = durationSeconds;
      if (aiWaypoints != null && aiWaypoints.isNotEmpty) {
        body['aiWaypoints'] = aiWaypoints.map((w) => w.toJson()).toList();
      }
      if (routeCharacter != null) body['routeCharacter'] = routeCharacter;

      final response = await http.post(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.groupsEndpoint}'),
        headers: _headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final group = GroupModel.fromJson(data['group']);
        _currentGroup = group;
        _myGroups.insert(0, group);
        _isLoading = false;
        notifyListeners();
        return group;
      } else {
        _errorMessage = data['error'] ?? 'Failed to create group';
      }
    } catch (e) {
      _errorMessage = 'Network error';
      debugPrint('Create group error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Join a group with invite code
  Future<GroupModel?> joinGroup(String inviteCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.joinGroupEndpoint}'),
        headers: _headers,
        body: jsonEncode({'inviteCode': inviteCode}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final group = GroupModel.fromJson(data['group']);
        _currentGroup = group;
        _myGroups.insert(0, group);
        _isLoading = false;
        notifyListeners();
        return group;
      } else {
        _errorMessage = data['error'] ?? 'Failed to join group';
      }
    } catch (e) {
      _errorMessage = 'Network error';
      debugPrint('Join group error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Fetch a specific group's details
  Future<void> fetchGroup(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.groupsEndpoint}/$groupId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentGroup = GroupModel.fromJson(data['group']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch group error: $e');
    }
  }

  /// Update group route
  Future<bool> updateRoute({
    required String groupId,
    PlaceModel? origin,
    PlaceModel? destination,
    List<WaypointModel>? waypoints,
    String? polyline,
    int? distanceMeters,
    int? durationSeconds,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (origin != null) body['origin'] = origin.toJson();
      if (destination != null) body['destination'] = destination.toJson();
      if (polyline != null) body['polyline'] = polyline;
      if (distanceMeters != null) body['distanceMeters'] = distanceMeters;
      if (durationSeconds != null) body['durationSeconds'] = durationSeconds;

      final response = await http.put(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.groupsEndpoint}/$groupId/route'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        await fetchGroup(groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Update route error: $e');
    }
    return false;
  }

  /// Update group status
  Future<bool> updateStatus(String groupId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.serverBaseUrl}${AppConstants.groupsEndpoint}/$groupId/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        await fetchGroup(groupId);
        return true;
      }
    } catch (e) {
      debugPrint('Update status error: $e');
    }
    return false;
  }

  /// Set current group
  void setCurrentGroup(GroupModel? group) {
    _currentGroup = group;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
