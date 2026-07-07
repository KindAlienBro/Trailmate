import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class TripBottomSheet extends StatelessWidget {
  final double distanceRemaining; // meters
  final double durationRemaining; // seconds
  final double currentSpeed; // km/h
  final VoidCallback onExit;

  const TripBottomSheet({
    super.key,
    required this.distanceRemaining,
    required this.durationRemaining,
    required this.currentSpeed,
    required this.onExit,
  });

  String _formatTime(double seconds) {
    if (seconds < 60) return '< 1 min';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final hours = (mins / 60).floor();
    final remainingMins = mins % 60;
    return '${hours}h ${remainingMins}m';
  }

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
  
  String _calculateETA(double seconds) {
    final eta = DateTime.now().add(Duration(seconds: seconds.round()));
    final hour = eta.hour > 12 ? eta.hour - 12 : (eta.hour == 0 ? 12 : eta.hour);
    final ampm = eta.hour >= 12 ? 'PM' : 'AM';
    final min = eta.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ETA & Distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formatTime(durationRemaining),
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.accentGreen,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDistance(distanceRemaining),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _calculateETA(durationRemaining),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(width: 5, height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Text(
                                  '${currentSpeed.toStringAsFixed(0)} km/h',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Exit Button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 32),
                          onPressed: onExit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
