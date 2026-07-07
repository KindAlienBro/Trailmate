import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A custom map marker for group members.
class MemberMarker extends StatelessWidget {
  final String name;
  final bool isLeader;
  final bool isMe;
  final String status;

  const MemberMarker({
    super.key,
    required this.name,
    this.isLeader = false,
    this.isMe = false,
    this.status = 'on-route',
  });

  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue, Colors.teal, Colors.indigo, Colors.amber,
      Colors.deepOrange, Colors.pink, Colors.cyan, Colors.lime,
      Colors.purple, Colors.lightBlue,
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Determine border color based on status and identity
    Color borderColor = _getColorFromName(name);
    
    if (status == 'deviated' || status == 'separated') {
      borderColor = AppTheme.accentOrange;
    } else if (status == 'sos') {
      borderColor = AppTheme.accentRed;
    } else if (isMe) {
      borderColor = AppTheme.accentGreen;
    } else if (isLeader) {
      // Keep leader distinct or let them have a unique color too?
      // Let's use the hash color for everyone, but if they want leader to be purple:
      // borderColor = AppTheme.accentPurple;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            isMe ? 'You' : name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Avatar circle
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        // Pointer triangle could be added here
      ],
    );
  }
}
