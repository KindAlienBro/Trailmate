import 'dart:ui';
import 'package:flutter/material.dart';
import '../providers/navigation_provider.dart';

/// Determines the resolved maneuver direction from both the API maneuverType
/// and the instruction text. The API `maneuver` field is often empty, so we
/// fall back to parsing the instruction string.
enum ManeuverDirection {
  straight,
  slightLeft,
  slightRight,
  turnLeft,
  turnRight,
  sharpLeft,
  sharpRight,
  uTurnLeft,
  uTurnRight,
  forkLeft,
  forkRight,
  rampLeft,
  rampRight,
  roundaboutLeft,
  roundaboutRight,
  merge,
  arrive,
  depart,
}

class _ManeuverInfo {
  final ManeuverDirection direction;
  final IconData icon;
  final Color color;
  final Color glowColor;
  final List<Color> gradientColors;

  const _ManeuverInfo({
    required this.direction,
    required this.icon,
    required this.color,
    required this.glowColor,
    required this.gradientColors,
  });
}

class DirectionsBanner extends StatelessWidget {
  final RouteStep? currentStep;
  final RouteStep? upcomingStep;
  final double distanceToNextManeuver;

  const DirectionsBanner({
    super.key,
    required this.currentStep,
    this.upcomingStep,
    this.distanceToNextManeuver = 0.0,
  });

  /// Resolve the maneuver direction from both the maneuverType string and
  /// the instruction text. maneuverType is checked first; if it's empty or
  /// 'straight', we attempt to infer direction from the instruction text.
  ManeuverDirection _resolveDirection(String maneuverType, String instruction) {
    final m = maneuverType.toLowerCase().trim();
    final inst = instruction.toLowerCase();

    // 1. Try resolving from the API maneuver type (most reliable when present)
    if (m.isNotEmpty) {
      // Arrival
      if (m.contains('arrive') || m.contains('destination')) {
        return ManeuverDirection.arrive;
      }
      // Depart
      if (m.contains('depart')) return ManeuverDirection.depart;
      // U-turns
      if (m.contains('uturn') || m.contains('u-turn') || m.contains('u_turn')) {
        return m.contains('right')
            ? ManeuverDirection.uTurnRight
            : ManeuverDirection.uTurnLeft;
      }
      // Roundabout
      if (m.contains('roundabout')) {
        return m.contains('left')
            ? ManeuverDirection.roundaboutLeft
            : ManeuverDirection.roundaboutRight;
      }
      // Fork
      if (m.contains('fork')) {
        return m.contains('left')
            ? ManeuverDirection.forkLeft
            : ManeuverDirection.forkRight;
      }
      // Ramp (highway on/off)
      if (m.contains('ramp') || m.contains('on-ramp') || m.contains('off-ramp')) {
        return m.contains('left')
            ? ManeuverDirection.rampLeft
            : ManeuverDirection.rampRight;
      }
      // Merge
      if (m.contains('merge')) return ManeuverDirection.merge;
      // Sharp turns
      if (m.contains('sharp') && m.contains('left')) return ManeuverDirection.sharpLeft;
      if (m.contains('sharp') && m.contains('right')) return ManeuverDirection.sharpRight;
      // Slight turns
      if (m.contains('slight') && m.contains('left')) return ManeuverDirection.slightLeft;
      if (m.contains('slight') && m.contains('right')) return ManeuverDirection.slightRight;
      // Normal turns
      if (m.contains('left')) return ManeuverDirection.turnLeft;
      if (m.contains('right')) return ManeuverDirection.turnRight;
      // Explicit straight
      if (m.contains('straight') || m.contains('continue')) {
        return ManeuverDirection.straight;
      }
    }

    // 2. Fallback: parse the instruction text itself
    // U-turn detection (must come before left/right checks)
    if (inst.contains('u-turn') || inst.contains('uturn') || inst.contains('u turn')) {
      return inst.contains('right')
          ? ManeuverDirection.uTurnRight
          : ManeuverDirection.uTurnLeft;
    }
    // Arrival
    if (inst.contains('arrive') || inst.contains('destination') || inst.contains('reached')) {
      return ManeuverDirection.arrive;
    }
    // Roundabout
    if (inst.contains('roundabout') || inst.contains('rotary') || inst.contains('traffic circle')) {
      if (inst.contains('left')) return ManeuverDirection.roundaboutLeft;
      return ManeuverDirection.roundaboutRight;
    }
    // Fork
    if (inst.contains('fork')) {
      return inst.contains('left')
          ? ManeuverDirection.forkLeft
          : ManeuverDirection.forkRight;
    }
    // Ramp
    if (inst.contains('ramp') || inst.contains('exit')) {
      return inst.contains('left')
          ? ManeuverDirection.rampLeft
          : ManeuverDirection.rampRight;
    }
    // Merge
    if (inst.contains('merge')) return ManeuverDirection.merge;
    // Sharp turns
    if (inst.contains('sharp') && inst.contains('left')) return ManeuverDirection.sharpLeft;
    if (inst.contains('sharp') && inst.contains('right')) return ManeuverDirection.sharpRight;
    // Slight / keep / bear
    if ((inst.contains('slight') || inst.contains('keep') || inst.contains('bear')) && inst.contains('left')) {
      return ManeuverDirection.slightLeft;
    }
    if ((inst.contains('slight') || inst.contains('keep') || inst.contains('bear')) && inst.contains('right')) {
      return ManeuverDirection.slightRight;
    }
    // Normal left/right
    if (inst.contains('turn left') || inst.contains(' left')) {
      return ManeuverDirection.turnLeft;
    }
    if (inst.contains('turn right') || inst.contains(' right')) {
      return ManeuverDirection.turnRight;
    }

    return ManeuverDirection.straight;
  }

  _ManeuverInfo _getManeuverInfo(ManeuverDirection direction) {
    switch (direction) {
      // ── Straight / Continue ──
      case ManeuverDirection.straight:
      case ManeuverDirection.depart:
        return const _ManeuverInfo(
          direction: ManeuverDirection.straight,
          icon: Icons.straight_rounded,
          color: Color(0xFF00C853),
          glowColor: Color(0xFF00E676),
          gradientColors: [Color(0xFF00E676), Color(0xFF00C853)],
        );

      // ── Left turns ──
      case ManeuverDirection.turnLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.turnLeft,
          icon: Icons.turn_left_rounded,
          color: Color(0xFF2196F3),
          glowColor: Color(0xFF42A5F5),
          gradientColors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
        );
      case ManeuverDirection.slightLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.slightLeft,
          icon: Icons.turn_slight_left_rounded,
          color: Color(0xFF29B6F6),
          glowColor: Color(0xFF4FC3F7),
          gradientColors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
        );
      case ManeuverDirection.sharpLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.sharpLeft,
          icon: Icons.turn_sharp_left_rounded,
          color: Color(0xFF1565C0),
          glowColor: Color(0xFF1E88E5),
          gradientColors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
        );

      // ── Right turns ──
      case ManeuverDirection.turnRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.turnRight,
          icon: Icons.turn_right_rounded,
          color: Color(0xFFFF9800),
          glowColor: Color(0xFFFFB74D),
          gradientColors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
        );
      case ManeuverDirection.slightRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.slightRight,
          icon: Icons.turn_slight_right_rounded,
          color: Color(0xFFFFA726),
          glowColor: Color(0xFFFFCC80),
          gradientColors: [Color(0xFFFFCC80), Color(0xFFEF6C00)],
        );
      case ManeuverDirection.sharpRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.sharpRight,
          icon: Icons.turn_sharp_right_rounded,
          color: Color(0xFFE65100),
          glowColor: Color(0xFFFF8F00),
          gradientColors: [Color(0xFFFF8F00), Color(0xFFE65100)],
        );

      // ── U-turns ──
      case ManeuverDirection.uTurnLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.uTurnLeft,
          icon: Icons.u_turn_left_rounded,
          color: Color(0xFFFF5252),
          glowColor: Color(0xFFFF8A80),
          gradientColors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
        );
      case ManeuverDirection.uTurnRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.uTurnRight,
          icon: Icons.u_turn_right_rounded,
          color: Color(0xFFFF5252),
          glowColor: Color(0xFFFF8A80),
          gradientColors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
        );

      // ── Forks ──
      case ManeuverDirection.forkLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.forkLeft,
          icon: Icons.fork_left_rounded,
          color: Color(0xFF26A69A),
          glowColor: Color(0xFF4DB6AC),
          gradientColors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
        );
      case ManeuverDirection.forkRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.forkRight,
          icon: Icons.fork_right_rounded,
          color: Color(0xFF26A69A),
          glowColor: Color(0xFF4DB6AC),
          gradientColors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
        );

      // ── Ramps ──
      case ManeuverDirection.rampLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.rampLeft,
          icon: Icons.ramp_left_rounded,
          color: Color(0xFF7E57C2),
          glowColor: Color(0xFF9575CD),
          gradientColors: [Color(0xFF9575CD), Color(0xFF512DA8)],
        );
      case ManeuverDirection.rampRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.rampRight,
          icon: Icons.ramp_right_rounded,
          color: Color(0xFF7E57C2),
          glowColor: Color(0xFF9575CD),
          gradientColors: [Color(0xFF9575CD), Color(0xFF512DA8)],
        );

      // ── Roundabouts ──
      case ManeuverDirection.roundaboutLeft:
        return const _ManeuverInfo(
          direction: ManeuverDirection.roundaboutLeft,
          icon: Icons.roundabout_left_rounded,
          color: Color(0xFF5C6BC0),
          glowColor: Color(0xFF7986CB),
          gradientColors: [Color(0xFF7986CB), Color(0xFF3949AB)],
        );
      case ManeuverDirection.roundaboutRight:
        return const _ManeuverInfo(
          direction: ManeuverDirection.roundaboutRight,
          icon: Icons.roundabout_right_rounded,
          color: Color(0xFF5C6BC0),
          glowColor: Color(0xFF7986CB),
          gradientColors: [Color(0xFF7986CB), Color(0xFF3949AB)],
        );

      // ── Merge ──
      case ManeuverDirection.merge:
        return const _ManeuverInfo(
          direction: ManeuverDirection.merge,
          icon: Icons.merge_rounded,
          color: Color(0xFF26A69A),
          glowColor: Color(0xFF4DB6AC),
          gradientColors: [Color(0xFF4DB6AC), Color(0xFF00897B)],
        );

      // ── Arrive ──
      case ManeuverDirection.arrive:
        return const _ManeuverInfo(
          direction: ManeuverDirection.arrive,
          icon: Icons.flag_circle_rounded,
          color: Color(0xFFAB47BC),
          glowColor: Color(0xFFCE93D8),
          gradientColors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
        );
    }
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

    final displayDistance = distanceToNextManeuver > 0
        ? distanceToNextManeuver
        : currentStep!.distance;

    // Google Maps-like behavior: show the UPCOMING maneuver (what happens at
    // the end of the current segment), not what you're currently doing.
    // If there's an upcoming step, show its icon/instruction with the distance
    // to it. If we're on the last step (arriving), show the current step.
    final RouteStep displayStep = upcomingStep ?? currentStep!;
    
    final direction = _resolveDirection(
      displayStep.maneuverType,
      displayStep.instruction,
    );
    final info = _getManeuverInfo(direction);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: info.color.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: info.glowColor.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              children: [
                // Direction Icon with colored gradient circle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: info.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: info.glowColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    info.icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),

                // Distance & Instruction
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
                        displayStep.instruction,
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
