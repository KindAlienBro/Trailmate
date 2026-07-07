import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/navigation_provider.dart';

/// Floating alert banner to display deviation/separation warnings.
class AlertBanner extends StatelessWidget {
  final AlertData alert;
  final VoidCallback onDismiss;

  const AlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isSos = alert.type == 'sos';
    final isDeviated = alert.type == 'deviation';
    
    final color = isSos
        ? AppTheme.accentRed
        : (isDeviated ? AppTheme.accentOrange : AppTheme.accentPurple);
        
    final icon = isSos
        ? Icons.warning_rounded
        : (isDeviated ? Icons.route_outlined : Icons.group_remove_outlined);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSos ? 'EMERGENCY' : 'Warning',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alert.name}: ${alert.message}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
