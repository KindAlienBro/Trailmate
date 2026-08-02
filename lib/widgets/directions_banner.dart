import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
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

  final RouteStep? detourCurrentStep;
  final double distanceToDetourManeuver;

  DirectionsBanner({
    super.key,
    required this.currentStep,
    this.upcomingStep,
    this.distanceToNextManeuver = 0.0,
    this.detourCurrentStep,
    this.distanceToDetourManeuver = 0.0,
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

  /// Extract road name from instruction text (after "onto" keyword)
  String? _extractRoadName(String instruction) {
    final lower = instruction.toLowerCase();
    final ontoIndex = lower.indexOf(' onto ');
    if (ontoIndex != -1) {
      return instruction.substring(ontoIndex + 6).trim();
    }
    // Try "on " pattern
    final onIndex = lower.indexOf(' on ');
    if (onIndex != -1 && onIndex > 5) {
      return instruction.substring(onIndex + 4).trim();
    }
    return null;
  }

  /// Get short instruction (without road name)
  String _getShortInstruction(String instruction) {
    final lower = instruction.toLowerCase();
    final ontoIndex = lower.indexOf(' onto ');
    if (ontoIndex != -1) {
      return instruction.substring(0, ontoIndex).trim();
    }
    return instruction;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (currentStep == null) return const SizedBox.shrink();

    final displayDistance = distanceToNextManeuver > 0
        ? distanceToNextManeuver
        : currentStep!.distance;

    // Show the UPCOMING maneuver (what happens at the end of current segment)
    final RouteStep displayStep = upcomingStep ?? currentStep!;
    
    final direction = _resolveDirection(
      displayStep.maneuverType,
      displayStep.instruction,
    );
    final info = _getManeuverInfo(direction);
    final roadName = _extractRoadName(displayStep.instruction);
    final shortInstruction = _getShortInstruction(displayStep.instruction);

    // Upcoming step info (for the "Then" column)
    _ManeuverInfo? nextInfo;
    double? nextDistance;
    if (upcomingStep != null) {
      // The "next" after upcoming is 2 steps ahead — but we only have upcomingStep
      // Show the upcoming step's own info in the "Then" panel
      final nextStep = upcomingStep!;
      final nextDir = _resolveDirection(nextStep.maneuverType, nextStep.instruction);
      nextInfo = _getManeuverInfo(nextDir);
      nextDistance = nextStep.distance;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2030).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (detourCurrentStep != null)
                  _buildBannerRow(
                    currentStep: detourCurrentStep!,
                    upcomingStep: null,
                    distance: distanceToDetourManeuver,
                    isDetour: true,
                  )
                else
                  _buildBannerRow(
                    currentStep: currentStep!,
                    upcomingStep: upcomingStep,
                    distance: distanceToNextManeuver,
                    isDetour: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerRow({
    required RouteStep currentStep,
    RouteStep? upcomingStep,
    required double distance,
    required bool isDetour,
  }) {
    final maneuverDir = _resolveDirection(currentStep.maneuverType, currentStep.instruction);
    final info = _getManeuverInfo(maneuverDir);

    final instructionParts = currentStep.instruction.split(' onto ');
    String shortInstruction = instructionParts[0];
    String? roadName;
    if (instructionParts.length > 1) {
      roadName = instructionParts.sublist(1).join(' onto ');
    } else {
      final towardsParts = currentStep.instruction.split(' towards ');
      if (towardsParts.length > 1) {
        shortInstruction = towardsParts[0];
        roadName = towardsParts.sublist(1).join(' towards ');
      }
    }

    _ManeuverInfo? nextInfo;
    double? nextDistance;

    if (upcomingStep != null) {
      final nextDir = _resolveDirection(upcomingStep.maneuverType, upcomingStep.instruction);
      nextInfo = _getManeuverInfo(nextDir);
      nextDistance = upcomingStep.distance;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          // ── LEFT: Direction Icon Circle ──
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDetour
                    ? [const Color(0xFFFFD600), const Color(0xFFFFA000)]
                    : info.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDetour
                      ? const Color(0xFFFFA000).withValues(alpha: 0.5)
                      : info.glowColor.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              info.icon,
              color: isDetour ? Colors.black87 : Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),

          // ── CENTER: Distance + Instruction + Road Name ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDetour)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Detour',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD600),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                // Distance
                Text(
                  _formatDistance(distance),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                // Short instruction
                Text(
                  shortInstruction,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Road name with pin icon
                if (roadName != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          roadName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── RIGHT: "Then" Preview ──
          if (nextInfo != null && nextDistance != null) ...[
            Container(
              width: 1,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Then',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    nextInfo.icon,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDistance(nextDistance),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
