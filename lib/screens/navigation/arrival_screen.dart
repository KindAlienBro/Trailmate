import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/theme.dart';

/// Beautiful "You've Arrived!" overlay screen with trip stats.
class ArrivalScreen extends StatefulWidget {
  final double totalDistance; // meters
  final Duration tripDuration;
  final String? destinationName;
  final VoidCallback onDone;

  ArrivalScreen({
    super.key,
    required this.totalDistance,
    required this.tripDuration,
    this.destinationName,
    required this.onDone,
  });

  @override
  State<ArrivalScreen> createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends State<ArrivalScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _checkController;
  late Animation<double> _fadeAnim;
  late Animation<double> _checkAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _checkController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _checkAnim = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_checkAnim);

    _fadeController.forward().then((_) {
      _checkController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) {
      return '${d.inMinutes} min';
    }
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _calculateAvgSpeed(double meters, Duration duration) {
    if (duration.inSeconds == 0) return '0 km/h';
    final kmPerHour = (meters / 1000) / (duration.inSeconds / 3600);
    return '${kmPerHour.toStringAsFixed(0)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentPrimary.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final size = MediaQuery.sizeOf(context);
                  final isLandscape = size.width > size.height && size.width > 480;

                  Widget leftContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated checkmark
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: isLandscape ? 70 : 90,
                          height: isLandscape ? 70 : 90,
                          decoration: BoxDecoration(
                            gradient: colors.accentGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentSecondary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: isLandscape ? 36 : 48,
                          ),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 16 : 28),

                      // Title
                      Text(
                        "You've Arrived!",
                        style: TextStyle(
                          fontSize: isLandscape ? 24 : 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.destinationName != null && widget.destinationName!.isNotEmpty
                            ? 'You have reached your set ${widget.destinationName} destination.'
                            : 'Trip completed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );

                  Widget rightContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stats row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStat(
                              Icons.straighten_rounded,
                              'Distance',
                              _formatDistance(widget.totalDistance),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _buildStat(
                              Icons.timer_rounded,
                              'Duration',
                              _formatDuration(widget.tripDuration),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _buildStat(
                              Icons.speed_rounded,
                              'Avg Speed',
                              _calculateAvgSpeed(widget.totalDistance, widget.tripDuration),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLandscape ? 24 : 36),

                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: themedAccentButton(colors),
                          child: ElevatedButton(
                            onPressed: widget.onDone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );

                  return SingleChildScrollView(
                    child: isLandscape
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: leftContent),
                              const SizedBox(width: 32),
                              Expanded(child: rightContent),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              leftContent,
                              const SizedBox(height: 36),
                              rightContent,
                            ],
                          ),
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: colors.accentPrimary),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
