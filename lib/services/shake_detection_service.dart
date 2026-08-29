import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetectionService {
  // Threshold in m/s^2 for user acceleration (gravity excluded)
  static const double shakeThreshold = 15.0; 
  static const int shakeCountResetTimeMs = 3000;
  static const int minimumShakeCount = 3;
  static const int shakeCooldownMs = 5000;

  StreamSubscription? _accelSubscription;
  final _shakeDetectedController = StreamController<bool>.broadcast();
  Stream<bool> get onShakeDetected => _shakeDetectedController.stream;

  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  DateTime? _lastTriggerTime;

  void start() {
    if (_accelSubscription != null) return;
    
    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20)
    ).listen(_handleAccelEvent);
    
    debugPrint('[ShakeDetection] Started monitoring.');
  }

  void stop() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _shakeCount = 0;
    debugPrint('[ShakeDetection] Stopped monitoring.');
  }

  void _handleAccelEvent(UserAccelerometerEvent event) {
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    if (magnitude > shakeThreshold) {
      final now = DateTime.now();
      
      // Prevent multiple triggers in a short time
      if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inMilliseconds < shakeCooldownMs) {
        return;
      }
      
      if (_lastShakeTime != null && now.difference(_lastShakeTime!).inMilliseconds > shakeCountResetTimeMs) {
        _shakeCount = 0;
      }
      
      _lastShakeTime = now;
      _shakeCount++;
      
      if (_shakeCount >= minimumShakeCount) {
        debugPrint('[ShakeDetection] Shake Confirmed!');
        _shakeDetectedController.add(true);
        _lastTriggerTime = now;
        _shakeCount = 0;
      }
    }
  }
}
