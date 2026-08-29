import 'dart:ui';
import 'package:flutter/material.dart';
import '../../providers/navigation_provider.dart';
import '../core/app_colors.dart';

/// Floating alert banner to display deviation/separation warnings.
class AlertBanner extends StatelessWidget {
  final AlertData alert;
  final VoidCallback onDismiss;

  AlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isSos = alert.type == 'sos';
    final isDeviated = alert.type == 'deviation';
    final isRegroup = alert.type == 'regroup';
    final isStopRequest = alert.type == 'stopRequest';
    
    final color = isSos
        ? colors.accentDanger
        : (isStopRequest ? colors.accentWarning : (isRegroup ? colors.accentPrimary : (isDeviated ? colors.accentWarning : colors.accentExtra)));
        
    final icon = isSos
        ? Icons.warning_rounded
        : (isStopRequest ? Icons.local_cafe_rounded : (isRegroup ? Icons.group_add_rounded : (isDeviated ? Icons.route_outlined : Icons.group_remove_outlined)));
        
    final title = isSos ? 'EMERGENCY' : (isRegroup ? 'REGROUP' : (isStopRequest ? 'STOP REQUEST' : 'Warning'));

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 72, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E33), // Darker solid background resembling the image
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.borderColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase() + (isRegroup ? ' REQUESTED' : ''),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (isRegroup || isStopRequest)
                          ? '${alert.name} wants to ${isRegroup ? 'regroup' : 'stop'} here.'
                          : '${alert.name}: ${alert.message}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (alert.onNavigate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton(
                    onPressed: () {
                      alert.onNavigate!();
                      onDismiss();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('NAVIGATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(left: 12, right: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
