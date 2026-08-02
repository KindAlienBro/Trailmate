import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Data class for a waypoint suggestion from the smart engine.
class WaypointSuggestion {
  final String name;
  final String type;
  final double lat;
  final double lng;
  final int distance;
  final String reason;
  final String icon;

  WaypointSuggestion({
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.distance,
    required this.reason,
    required this.icon,
  });

  factory WaypointSuggestion.fromJson(Map<String, dynamic> json) {
    return WaypointSuggestion(
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'fuel',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distance: (json['distance'] as num?)?.toInt() ?? 0,
      reason: json['reason'] ?? '',
      icon: json['icon'] ?? 'scenic',
    );
  }

  String get distanceText {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
    return '$distance m';
  }

  IconData get iconData {
    switch (icon) {
      case 'gas_station': return Icons.local_gas_station_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'hospital': return Icons.local_hospital_rounded;
      case 'scenic': return Icons.landscape_rounded;
      case 'viewpoint': return Icons.visibility_rounded;
      case 'curvy_road': return Icons.trending_up_rounded;
      case 'mountain_pass': return Icons.terrain_rounded;
      case 'waterfall': return Icons.water_drop_rounded;
      case 'jungle': return Icons.park_rounded;
      case 'water_crossing': return Icons.waves_rounded;
      case 'heritage': return Icons.castle_rounded;
      default: return Icons.place_rounded;
    }
  }

  Color get accentColor {
    switch (type) {
      case 'fuel': return Color(0xFFFFAB40);
      case 'fatigue_break': return Color(0xFF4FC3F7);
      case 'ai_waypoint': return Color(0xFFB388FF);
      case 'stopped_suggestion': return Color(0xFF00E676);
      default: return Color(0xFF1976D2);
    }
  }
}

/// Premium animated suggestion card that slides up from the bottom.
class SuggestionCard extends StatefulWidget {
  final WaypointSuggestion suggestion;
  final VoidCallback? onNavigate;
  final VoidCallback? onDismiss;
  final Duration autoDismissDuration;

  SuggestionCard({
    super.key,
    required this.suggestion,
    this.onNavigate,
    this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 30),
  });

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss timer
    Future.delayed(widget.autoDismissDuration, () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    final suggestion = widget.suggestion;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: ValueKey(suggestion.name),
          direction: DismissDirection.down,
          onDismissed: (_) => widget.onDismiss?.call(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: suggestion.accentColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: suggestion.accentColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: suggestion.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: suggestion.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        suggestion.iconData,
                        color: suggestion.accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            suggestion.reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: suggestion.accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        suggestion.distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _dismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Dismiss',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              suggestion.accentColor,
                              suggestion.accentColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  suggestion.accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: widget.onNavigate,
                          icon: Icon(Icons.navigation_rounded,
                              size: 18, color: Colors.white),
                          label: Text('Navigate Here',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
