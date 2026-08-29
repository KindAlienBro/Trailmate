import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Offline Cache Service — persists route data and location queue to disk.
///
/// Uses JSON files in the app documents directory (not SharedPreferences)
/// because route payloads (steps + polyline + waypoints) can be large.
///
/// Two files:
/// - `offline_route_cache.json` — the active route data
/// - `offline_location_queue.json` — GPS positions queued while offline
class OfflineCacheService {
  // Singleton
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const _routeFileName = 'offline_route_cache.json';
  static const _queueFileName = 'offline_location_queue.json';

  /// Max queued locations before oldest are evicted (FIFO).
  static const maxQueueSize = 200;

  // Cached directory path to avoid repeated async lookups
  String? _dirPath;

  Future<String> get _cacheDirPath async {
    _dirPath ??= (await getApplicationDocumentsDirectory()).path;
    return _dirPath!;
  }

  // ==================== Route Cache ====================

  /// Cache the active navigation route to a JSON file.
  Future<void> cacheActiveRoute({
    required String groupId,
    required String polyline,
    required List<Map<String, dynamic>> steps,
    required String destinationName,
    required double destinationLat,
    required double destinationLng,
    String originName = '',
    double originLat = 0,
    double originLng = 0,
    double distance = 0,
    double duration = 0,
    String transportMode = 'driving',
  }) async {
    try {
      final data = {
        'groupId': groupId,
        'polyline': polyline,
        'steps': steps,
        'destinationName': destinationName,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'originName': originName,
        'originLat': originLat,
        'originLng': originLng,
        'distance': distance,
        'duration': duration,
        'transportMode': transportMode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final dir = await _cacheDirPath;
      final file = File('$dir/$_routeFileName');
      await file.writeAsString(jsonEncode(data));
      debugPrint('[OfflineCache] Route cached: $destinationName (${steps.length} steps)');
    } catch (e) {
      debugPrint('[OfflineCache] Failed to cache route: $e');
    }
  }

  /// Load cached route data. Returns null if no cache exists or cache is stale (>24h).
  Future<CachedRoute?> loadCachedRoute() async {
    try {
      final dir = await _cacheDirPath;
      final file = File('$dir/$_routeFileName');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final timestamp = data['timestamp'] as int?;
      if (timestamp == null) return null;

      // Expire cache after 24 hours
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > 24 * 60 * 60 * 1000) {
        debugPrint('[OfflineCache] Cache expired (${cacheAge ~/ 3600000}h old). Clearing.');
        await clearRouteCache();
        return null;
      }

      final steps = (data['steps'] as List)
          .map((s) => Map<String, dynamic>.from(s))
          .toList();

      return CachedRoute(
        groupId: data['groupId'] ?? '',
        polyline: data['polyline'] ?? '',
        steps: steps,
        destinationName: data['destinationName'] ?? '',
        destinationLat: (data['destinationLat'] as num?)?.toDouble() ?? 0,
        destinationLng: (data['destinationLng'] as num?)?.toDouble() ?? 0,
        originName: data['originName'] ?? '',
        originLat: (data['originLat'] as num?)?.toDouble() ?? 0,
        originLng: (data['originLng'] as num?)?.toDouble() ?? 0,
        distance: (data['distance'] as num?)?.toDouble() ?? 0,
        duration: (data['duration'] as num?)?.toDouble() ?? 0,
        transportMode: data['transportMode'] ?? 'driving',
        cachedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
    } catch (e) {
      debugPrint('[OfflineCache] Failed to load cached route: $e');
      return null;
    }
  }

  /// Clear the cached route file.
  Future<void> clearRouteCache() async {
    try {
      final dir = await _cacheDirPath;
      final file = File('$dir/$_routeFileName');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[OfflineCache] Route cache cleared');
      }
    } catch (e) {
      debugPrint('[OfflineCache] Failed to clear route cache: $e');
    }
  }

  // ==================== Location Queue ====================

  /// Append a location entry to the persisted offline queue.
  /// Evicts oldest entries if queue exceeds [maxQueueSize].
  Future<void> enqueueLocation(Map<String, dynamic> locationData) async {
    try {
      final queue = await loadLocationQueue();
      queue.add(locationData);

      // Cap the queue — drop oldest entries
      while (queue.length > maxQueueSize) {
        queue.removeAt(0);
      }

      final dir = await _cacheDirPath;
      final file = File('$dir/$_queueFileName');
      await file.writeAsString(jsonEncode(queue));
    } catch (e) {
      debugPrint('[OfflineCache] Failed to enqueue location: $e');
    }
  }

  /// Load the persisted location queue.
  Future<List<Map<String, dynamic>>> loadLocationQueue() async {
    try {
      final dir = await _cacheDirPath;
      final file = File('$dir/$_queueFileName');
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final list = jsonDecode(content) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('[OfflineCache] Failed to load location queue: $e');
      return [];
    }
  }

  /// Clear the location queue (after successful flush to server).
  Future<void> clearLocationQueue() async {
    try {
      final dir = await _cacheDirPath;
      final file = File('$dir/$_queueFileName');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[OfflineCache] Location queue cleared');
      }
    } catch (e) {
      debugPrint('[OfflineCache] Failed to clear location queue: $e');
    }
  }

  /// Clear everything (route + queue).
  Future<void> clearAll() async {
    await clearRouteCache();
    await clearLocationQueue();
  }
}

/// Data class for a cached route.
class CachedRoute {
  final String groupId;
  final String polyline;
  final List<Map<String, dynamic>> steps;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final String originName;
  final double originLat;
  final double originLng;
  final double distance;
  final double duration;
  final String transportMode;
  final DateTime cachedAt;

  CachedRoute({
    required this.groupId,
    required this.polyline,
    required this.steps,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.distance,
    required this.duration,
    required this.transportMode,
    required this.cachedAt,
  });
}
