import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// SOS Emergency Button — Compact version (40×40) with pulse animation.
class SosButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final bool isActive;
  final VoidCallback onCancel;

  SosButton({
    super.key,
    required this.onTrigger,
    this.isActive = false,
    required this.onCancel,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _confirmSos(BuildContext context) {
    final colors = AppColors.of(context);
    if (widget.isActive) {
      // Cancel SOS dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.surfaceColor,
          title: Text('Cancel SOS', style: TextStyle(color: colors.textPrimary)),
          content: Text('Are you safe now? This will notify the group that the emergency is over.', style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No, keep active', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onCancel();
              },
              child: Text('Yes, I am safe', style: TextStyle(color: colors.accentSecondary)),
            ),
          ],
        ),
      );
    } else {
      // Trigger SOS dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.surfaceColor,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.accentDanger),
              SizedBox(width: 8),
              Text('Trigger SOS', style: TextStyle(color: colors.textPrimary)),
            ],
          ),
          content: Text(
            'This will immediately alert the trip leader and all group members. Only use in an emergency.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onTrigger();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentDanger,
                foregroundColor: Colors.white,
              ),
              child: Text('TRIGGER SOS'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _tapController]),
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => _tapController.forward(),
          onTapUp: (_) {
            _tapController.reverse();
            _confirmSos(context);
          },
          onTapCancel: () => _tapController.reverse(),
          child: Transform.scale(
            scale: _tapScale.value,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: widget.isActive ? colors.dangerGradient : null,
                color: widget.isActive ? null : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isActive ? Colors.transparent : colors.accentDanger,
                  width: 2,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: colors.accentDanger.withValues(alpha: 0.4 + (_pulseController.value * 0.4)),
                          blurRadius: 12 + (_pulseController.value * 12),
                          spreadRadius: _pulseController.value * 6,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: widget.isActive ? Colors.white : colors.accentDanger,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
