import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location Service — GPS tracking with permission handling.
///
/// Provides a stream of position updates for real-time navigation.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  final _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Position? get lastPosition => _lastPosition;

  /// Request location permissions
  Future<bool> requestPermissions() async {
    // Check if location services are enabled first
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] Location services are disabled');
      await Geolocator.openLocationSettings();
      return false; // Return false so the UI can prompt them to retry
    }

    // Check and request location permission
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isPermanentlyDenied) {
      debugPrint('[Location] Permission permanently denied');
      await openAppSettings();
      return false;
    }

    if (!status.isGranted) {
      debugPrint('[Location] Permission denied');
      return false;
    }

    return true;
  }

  /// Get current position (one-shot)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      debugPrint('[Location] Error getting position: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  void startTracking({int intervalSeconds = 5}) {
    _positionSubscription?.cancel();

    // Fetch initial location immediately without blocking stream setup
    getCurrentPosition().then((initialPosition) {
      if (initialPosition != null) {
        _positionController.add(initialPosition);
      }
    }).catchError((e) {
      debugPrint('[Location] Initial position fetch failed: $e');
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Only emit update if moved at least 5 meters
      ),
    ).listen(
      (position) {
        // Reject inaccurate cell-tower/IP triangulation jumps (anything worse than 50 meters)
        if (position.accuracy > 50.0) {
          debugPrint('[Location] Ignoring inaccurate reading: ${position.accuracy}m');
          return;
        }

        // Kalman-lite: Reject physically impossible "teleportation" jumps
        if (_lastPosition != null) {
          final distance = distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude,
          );
          
          final timeDiffSeconds = position.timestamp.difference(_lastPosition!.timestamp).inSeconds;
          if (timeDiffSeconds > 0) {
            final speedMetersPerSecond = distance / timeDiffSeconds;
            // 45 m/s is ~162 km/h. If the GPS claims we moved faster than a speeding supercar, it's a hardware glitch!
            // However, if the location is mocked (e.g. Android Emulator routing), we allow the jump.
            if (speedMetersPerSecond > 45.0 && !position.isMocked) {
              debugPrint('[Location] Ignoring impossible jump: ${distance.toStringAsFixed(1)}m in ${timeDiffSeconds}s');
              return;
            }
          }
        }

        // Calculate an accurate bearing using the physical delta between the last two points
        // (This completely fixes the issue where the device compass/GPS heading is zero or frozen)
        double calculatedHeading = position.heading;
        if (_lastPosition != null) {
          final computedBearing = Geolocator.bearingBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude,
          );
          // Only trust computed bearing if we actually moved more than 1 meter
          final dist = distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude,
          );
          if (dist > 1.0) {
            calculatedHeading = computedBearing;
          }
        }

        // We clone the position to override the heading with our calculated one
        final enhancedPosition = Position(
          longitude: position.longitude,
          latitude: position.latitude,
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          altitude: position.altitude,
          altitudeAccuracy: position.altitudeAccuracy,
          heading: calculatedHeading,
          headingAccuracy: position.headingAccuracy,
          speed: position.speed,
          speedAccuracy: position.speedAccuracy,
          floor: position.floor,
          isMocked: position.isMocked,
        );

        _lastPosition = enhancedPosition;
        _positionController.add(enhancedPosition);
      },
      onError: (error) {
        debugPrint('[Location] Stream error: $error');
      },
    );

    debugPrint('[Location] Tracking started');
  }

  /// Stop location tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('[Location] Tracking stopped');
  }

  /// Calculate distance between two points in meters
  static double distanceBetween(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate bearing between two points
  static double bearingBetween(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return Geolocator.bearingBetween(lat1, lng1, lat2, lng2);
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
