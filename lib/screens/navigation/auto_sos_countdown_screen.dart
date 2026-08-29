import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/navigation_provider.dart';

class AutoSosCountdownScreen extends StatefulWidget {
  final String groupId;
  const AutoSosCountdownScreen({super.key, required this.groupId});

  @override
  State<AutoSosCountdownScreen> createState() => _AutoSosCountdownScreenState();
}

class _AutoSosCountdownScreenState extends State<AutoSosCountdownScreen> {
  int _secondsLeft = 15;
  Timer? _timer;
  final FlutterTts _tts = FlutterTts();
  bool _vibrating = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startAlerts();
  }

  void _startAlerts() async {
    _vibrating = true;
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    
    // Loop voice alert and vibration
    _triggerAlertCycle();
  }

  void _triggerAlertCycle() async {
    if (!mounted || !_vibrating) return;
    
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
    }
    
    await _tts.speak('Warning! Fall detected! SOS will be sent in $_secondsLeft seconds!');
    
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _vibrating) {
        _triggerAlertCycle();
      }
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _vibrating = false;
        Vibration.cancel();
        _tts.stop();
        _sendSos();
      }
    });
  }

  void _sendSos() {
    final navProvider = context.read<NavigationProvider>();
    navProvider.wsService.triggerSOS(
      groupId: widget.groupId,
      lat: navProvider.locationService.lastPosition?.latitude,
      lng: navProvider.locationService.lastPosition?.longitude,
      message: 'Automatic fall/crash detected for rider. Location attached.',
      triggerSource: 'auto_fall',
    );
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Automatic SOS Sent!')),
      );
    }
  }

  void _cancelSos() {
    _timer?.cancel();
    _vibrating = false;
    Vibration.cancel();
    _tts.stop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibrating = false;
    Vibration.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Red emergency screen
    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'POSSIBLE FALL DETECTED',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sending automatic SOS in:',
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Text(
                  '$_secondsLeft',
                  style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _cancelSos,
                    child: const Text(
                      "I'M OK - CANCEL",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
