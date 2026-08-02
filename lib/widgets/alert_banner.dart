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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${alert.name}: ${alert.message}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (alert.onNavigate != null)
                TextButton(
                  onPressed: () {
                    alert.onNavigate!();
                    onDismiss();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('NAVIGATE', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }
}
