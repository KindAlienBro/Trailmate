import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Compact compass widget that rotates based on device heading.
/// Shows cardinal direction text and a rotating needle.
class CompassWidget extends StatelessWidget {
  final double heading; // device heading in degrees (0 = North)
  
  const CompassWidget({super.key, required this.heading});

  String _cardinalDirection(double deg) {
    if (deg >= 337.5 || deg < 22.5) return 'N';
    if (deg >= 22.5 && deg < 67.5) return 'NE';
    if (deg >= 67.5 && deg < 112.5) return 'E';
    if (deg >= 112.5 && deg < 157.5) return 'SE';
    if (deg >= 157.5 && deg < 202.5) return 'S';
    if (deg >= 202.5 && deg < 247.5) return 'SW';
    if (deg >= 247.5 && deg < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedHeading = heading % 360;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030).withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating compass needle
          Transform.rotate(
            angle: -normalizedHeading * pi / 180,
            child: CustomPaint(
              size: const Size(36, 36),
              painter: _CompassNeedlePainter(),
            ),
          ),
          // Cardinal direction text
          Text(
            _cardinalDirection(normalizedHeading),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // North (red) needle
    final northPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 4, center.dy)
      ..lineTo(center.dx + 4, center.dy)
      ..close();

    canvas.drawPath(northPath, northPaint);

    // South (white/grey) needle
    final southPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius - 2)
      ..lineTo(center.dx - 4, center.dy)
      ..lineTo(center.dx + 4, center.dy)
      ..close();

    canvas.drawPath(southPath, southPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Speedometer widget showing current speed in km/h
/// with a subtle arc indicator.
class SpeedometerWidget extends StatelessWidget {
  final double speedKmh;

  const SpeedometerWidget({super.key, required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final displaySpeed = speedKmh.clamp(0.0, 200.0);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030).withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arc indicator
          CustomPaint(
            size: const Size(56, 56),
            painter: _SpeedArcPainter(
              progress: (displaySpeed / 180).clamp(0.0, 1.0),
            ),
          ),
          // Speed text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displaySpeed.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                'km/h',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedArcPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _SpeedArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (135 * pi / 180), // Start from bottom-left
      (270 * pi / 180), // Sweep 270 degrees
      false,
      bgPaint,
    );

    // Progress arc
    if (progress > 0) {
      // Color based on speed
      Color arcColor;
      if (progress < 0.4) {
        arcColor = const Color(0xFF10B981); // Green (slow)
      } else if (progress < 0.7) {
        arcColor = const Color(0xFFF59E0B); // Yellow (moderate)
      } else {
        arcColor = const Color(0xFFEF4444); // Red (fast)
      }

      final progressPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (135 * pi / 180),
        (270 * pi / 180 * progress),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
