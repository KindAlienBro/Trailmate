import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// SOS Emergency Button
class SosButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final bool isActive;
  final VoidCallback onCancel;

  const SosButton({
    super.key,
    required this.onTrigger,
    this.isActive = false,
    required this.onCancel,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isActive) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _animController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _confirmSos(BuildContext context) {
    if (widget.isActive) {
      // Cancel SOS dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Cancel SOS', style: TextStyle(color: AppTheme.textPrimary)),
          content: const Text('Are you safe now? This will notify the group that the emergency is over.', style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, keep active', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onCancel();
              },
              child: const Text('Yes, I am safe', style: TextStyle(color: AppTheme.accentGreen)),
            ),
          ],
        ),
      );
    } else {
      // Trigger SOS dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed),
              SizedBox(width: 8),
              Text('Trigger SOS', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: const Text(
            'This will immediately alert the trip leader and all group members. Only use in an emergency.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onTrigger();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('TRIGGER SOS'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => _confirmSos(context),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: widget.isActive ? AppTheme.dangerGradient : null,
              color: widget.isActive ? null : AppTheme.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isActive ? Colors.transparent : AppTheme.accentRed,
                width: 2,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.accentRed.withValues(alpha: 0.4 + (_animController.value * 0.4)),
                        blurRadius: 16 + (_animController.value * 16),
                        spreadRadius: _animController.value * 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: widget.isActive ? Colors.white : AppTheme.accentRed,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
