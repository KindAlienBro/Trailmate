import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';

enum FallState { idle, freeFall, impact, stillness, triggered }

class SensorData {
  final UserAccelerometerEvent event;
  final DateTime timestamp;
  SensorData(this.event, this.timestamp);
}

class FallDetectionService {
  // Configurable Thresholds
  static const double freeFallThreshold = 3.9; // ~0.4g (m/s^2)
  static const double impactThreshold = 24.5; // ~2.5g
  static const double stillnessVarianceThreshold = 1.0; 
  static const int freeFallMinDurationMs = 200;
  static const int impactMaxDelayMs = 2000;
  static const int stillnessDurationMs = 3000;
  
  FallState _currentState = FallState.idle;
  DateTime? _freeFallStartTime;
  DateTime? _impactTime;
  
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  
  final List<SensorData> _recentEvents = [];

  final _fallDetectedController = StreamController<bool>.broadcast();
  Stream<bool> get onFallDetected => _fallDetectedController.stream;

  void start() {
    if (_accelSubscription != null) return;
    
    _accelSubscription = userAccelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20)).listen(_handleAccelEvent);
    _gyroSubscription = gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 20)).listen(_handleGyroEvent);
    
    debugPrint('[FallDetection] Started monitoring.');
  }

  void stop() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _currentState = FallState.idle;
    debugPrint('[FallDetection] Stopped monitoring.');
  }

  void reset() {
    _currentState = FallState.idle;
    _freeFallStartTime = null;
    _impactTime = null;
    _recentEvents.clear();
  }

  void _handleAccelEvent(UserAccelerometerEvent event) {
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();
    _recentEvents.add(SensorData(event, now));
    
    // Keep ~5 seconds of rolling buffer (5000ms / 20ms = 250 items)
    if (_recentEvents.length > 250) {
      _recentEvents.removeAt(0);
    }
    
    switch (_currentState) {
      case FallState.idle:
        if (magnitude < freeFallThreshold) {
          if (_freeFallStartTime == null) {
            _freeFallStartTime = now;
          } else if (now.difference(_freeFallStartTime!).inMilliseconds > freeFallMinDurationMs) {
            _currentState = FallState.freeFall;
            debugPrint('[FallDetection] Detected Free-fall -> Waiting for impact');
          }
        } else {
          _freeFallStartTime = null;
        }
        break;

      case FallState.freeFall:
        if (magnitude > impactThreshold) {
          _currentState = FallState.impact;
          _impactTime = now;
          debugPrint('[FallDetection] Detected Impact -> Waiting for stillness');
        } else if (now.difference(_freeFallStartTime!).inMilliseconds > impactMaxDelayMs) {
          // Timeout, false alarm
          reset();
        }
        break;

      case FallState.impact:
        if (now.difference(_impactTime!).inMilliseconds > stillnessDurationMs) {
          // Check for stillness
          final stillnessPeriod = _recentEvents.where((e) => 
            e.timestamp.isAfter(_impactTime!)
          ).toList();
          
          if (stillnessPeriod.isNotEmpty) {
             final magnitudes = stillnessPeriod.map((e) => 
               sqrt(e.event.x*e.event.x + e.event.y*e.event.y + e.event.z*e.event.z)
             ).toList();
             
             double mean = magnitudes.reduce((a,b) => a+b) / magnitudes.length;
             double variance = magnitudes.map((m) => pow(m - mean, 2)).reduce((a,b) => a+b) / magnitudes.length;
             
             if (variance < stillnessVarianceThreshold) {
               _currentState = FallState.triggered;
               debugPrint('[FallDetection] Fall Confirmed (Stillness detected)');
               _logEvent('fall_detected', maxMagnitude: magnitudes.reduce(max), variance: variance);
               _fallDetectedController.add(true);
             } else {
               debugPrint('[FallDetection] False Alarm (Movement continued)');
               _logEvent('false_alarm_movement', maxMagnitude: magnitudes.reduce(max), variance: variance);
               reset();
             }
          }
        } else {
           // still waiting for stillness duration to pass
        }
        break;
        
      case FallState.triggered:
      case FallState.stillness:
        break;
    }
  }

  void _handleGyroEvent(GyroscopeEvent event) {
    // Gyroscope can be used to augment orientation check if needed
  }
  
  Future<void> logEvent(String type) async {
     await _logEvent(type);
  }

  Future<void> _logEvent(String type, {double? maxMagnitude, double? variance}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fall_events_log.json');
      List<dynamic> logs = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        logs = jsonDecode(content);
      }
      logs.add({
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'maxMagnitude': maxMagnitude,
        'variance': variance,
      });
      await file.writeAsString(jsonEncode(logs));
    } catch (e) {
      debugPrint('Log error: $e');
    }
  }
}
