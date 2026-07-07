import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/navigation_provider.dart';

class DirectionsBanner extends StatelessWidget {
  final RouteStep? currentStep;
  final double distanceToNextManeuver; // Optional real-time calculated distance

  const DirectionsBanner({
    super.key,
    required this.currentStep,
    this.distanceToNextManeuver = 0.0,
  });

  IconData _getManeuverIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('arrive')) return Icons.flag_circle_rounded;
    if (t.contains('uturn') || t.contains('u-turn')) return Icons.u_turn_left_rounded;
    if (t.contains('left')) return Icons.turn_left_rounded;
    if (t.contains('right')) return Icons.turn_right_rounded;
    if (t.contains('fork')) return Icons.fork_right_rounded;
    return Icons.straight_rounded;
  }

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    if (currentStep == null) return const SizedBox.shrink();

    // Use passed real-time distance if > 0, else use the static step distance
    final displayDistance = distanceToNextManeuver > 0 
        ? distanceToNextManeuver 
        : currentStep!.distance;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              children: [
                // Direction Icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentBlue, Color(0xFF00C6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentBlue.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getManeuverIcon(currentStep!.maneuverType),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                
                // Instruction & Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDistance(displayDistance),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStep!.instruction,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
