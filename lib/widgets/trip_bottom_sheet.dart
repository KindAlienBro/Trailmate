import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../providers/navigation_provider.dart';

/// Redesigned trip bottom sheet with 3-stat columns, expandable member list,
/// Continue Navigation button, and Steps button.
class TripBottomSheet extends StatefulWidget {
  final double distanceRemaining; // meters
  final double durationRemaining; // seconds
  final double currentSpeed; // km/h
  final VoidCallback onExit;
  final Map<String, MemberPosition> memberPositions;
  final String? currentUserId;
  final Function(String userId)? onMemberTap;
  final VoidCallback? onStepsTap;
  final bool isLandscape;

  TripBottomSheet({
    super.key,
    required this.distanceRemaining,
    required this.durationRemaining,
    required this.currentSpeed,
    required this.onExit,
    this.memberPositions = const {},
    this.currentUserId,
    this.onMemberTap,
    this.onStepsTap,
    this.isLandscape = false,
  });

  @override
  State<TripBottomSheet> createState() => _TripBottomSheetState();
}

class _TripBottomSheetState extends State<TripBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _membersExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleMembers() {
    setState(() {
      _membersExpanded = !_membersExpanded;
      if (_membersExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

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

  /// Calculate how many members are ahead/behind current user
  Map<String, int> _getMemberDistribution() {
    int ahead = 0;
    int behind = 0;
    if (widget.currentUserId == null) return {'ahead': 0, 'behind': 0};
    
    final myPos = widget.memberPositions[widget.currentUserId];
    if (myPos == null) return {'ahead': 0, 'behind': 0};

    for (final entry in widget.memberPositions.entries) {
      if (entry.key == widget.currentUserId) continue;
      // Simple heuristic: if their remaining distance is less, they're ahead
      // For now, just count based on status
      if (entry.value.status == 'on-route') {
        ahead++;
      } else {
        behind++;
      }
    }
    return {'ahead': ahead, 'behind': behind};
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final memberCount = widget.memberPositions.length;
    final distribution = _getMemberDistribution();

    if (widget.isLandscape) {
      return _buildLandscapeCard(context, colors);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141820).withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                if (!widget.isLandscape)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                if (!widget.isLandscape)
                  const SizedBox(height: 16)
                else
                  const SizedBox(height: 24),

                // ── 3-Column Stats Row ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // ETA Column
                      Expanded(
                        child: _StatColumn(
                          icon: Icons.schedule_rounded,
                          iconColor: const Color(0xFF5E6AD2),
                          label: 'ETA',
                          value: _formatTime(widget.durationRemaining),
                          subtitle: _calculateETA(widget.durationRemaining),
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        height: 48,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      // Distance Column
                      Expanded(
                        child: _StatColumn(
                          icon: Icons.route_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Distance',
                          value: _formatDistance(widget.distanceRemaining),
                          subtitle: null,
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        height: 48,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      // Group Column (tappable)
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleMembers,
                          child: _StatColumn(
                            icon: Icons.groups_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Group',
                            value: '$memberCount members',
                            subtitle: memberCount > 1
                                ? '${distribution['ahead']} ahead · ${distribution['behind']} behind'
                                : null,
                            showChevron: true,
                            isExpanded: _membersExpanded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Expandable Members Panel ──
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1.0,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: widget.memberPositions.length,
                      itemBuilder: (context, index) {
                        final entry = widget.memberPositions.entries.elementAt(index);
                        final pos = entry.value;
                        final isMe = entry.key == widget.currentUserId;

                        // Status color
                        Color statusColor;
                        if (pos.status == 'sos') {
                          statusColor = colors.accentDanger;
                        } else if (pos.status == 'deviated' || pos.status == 'separated') {
                          statusColor = colors.accentWarning;
                        } else {
                          statusColor = colors.accentSecondary;
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onMemberTap?.call(entry.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: statusColor, width: 2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        pos.name.isNotEmpty ? pos.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Name + status
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              pos.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: colors.accentPrimary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'You',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.accentPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          '${pos.speed.toStringAsFixed(0)} km/h · ${pos.status}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status dot
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                if (_membersExpanded) const SizedBox(height: 10),

                // ── Action Buttons Row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      // End Navigation Button
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.accentDanger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onExit,
                              borderRadius: BorderRadius.circular(14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stop_rounded, color: colors.accentDanger, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'End Navigation',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accentDanger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Steps Button
                      Container(
                        height: 48,
                        width: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onStepsTap,
                            borderRadius: BorderRadius.circular(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.list_alt_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Steps',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildLandscapeCard(BuildContext context, AppColorScheme colors) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 24, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Close / End Navigation Button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.black87),
                onPressed: widget.onExit,
                tooltip: 'End Navigation',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            const SizedBox(width: 16),

            // ETA, Distance, Arrival Time
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatTime(widget.durationRemaining),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC62828), 
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.eco_rounded, color: Color(0xFF2E7D32), size: 16), 
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDistance(widget.distanceRemaining)} • ${_calculateETA(widget.durationRemaining)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 24),
            
            // Steps / Alternate Route Button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: IconButton(
                icon: const Icon(Icons.alt_route_rounded, color: Colors.black87),
                onPressed: widget.onStepsTap,
                tooltip: 'Route Steps',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat column widget for the bottom sheet.
class _StatColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final bool showChevron;
  final bool isExpanded;

  const _StatColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.showChevron = false,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + Label row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          // Subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
