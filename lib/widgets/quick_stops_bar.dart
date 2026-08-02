import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A stop category for the quick stops bar.
class StopCategory {
  final String label;
  final IconData icon;
  final String apiType;
  final Color color;

  const StopCategory({
    required this.label,
    required this.icon,
    required this.apiType,
    required this.color,
  });
}

/// Predefined stop categories with Material Icons.
const List<StopCategory> defaultStopCategories = [
  StopCategory(
    label: 'Fuel',
    icon: Icons.local_gas_station_rounded,
    apiType: 'gas_station',
    color: Color(0xFFFFAB40),
  ),
  StopCategory(
    label: 'Food',
    icon: Icons.restaurant_rounded,
    apiType: 'restaurant',
    color: Color(0xFFFF7043),
  ),
  StopCategory(
    label: 'Hospital',
    icon: Icons.local_hospital_rounded,
    apiType: 'hospital',
    color: Color(0xFFEF5350),
  ),
  StopCategory(
    label: 'Hotel',
    icon: Icons.hotel_rounded,
    apiType: 'lodging',
    color: Color(0xFF42A5F5),
  ),
  StopCategory(
    label: 'Parking',
    icon: Icons.local_parking_rounded,
    apiType: 'parking',
    color: Color(0xFF5C6BC0),
  ),
];

/// Quick stops bar — horizontal scrollable row of category pills.
/// Floats above the bottom sheet during active navigation.
class QuickStopsBar extends StatefulWidget {
  final Function(StopCategory category) onCategoryTap;
  final String? activeCategory; // currently selected category label

  const QuickStopsBar({
    super.key,
    required this.onCategoryTap,
    this.activeCategory,
  });

  @override
  State<QuickStopsBar> createState() => _QuickStopsBarState();
}

class _QuickStopsBarState extends State<QuickStopsBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: defaultStopCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = defaultStopCategories[index];
            final isActive = widget.activeCategory == cat.label;
            return _StopPill(
              category: cat,
              isActive: isActive,
              onTap: () => widget.onCategoryTap(cat),
              delay: index * 60,
            );
          },
        ),
      ),
    );
  }
}

class _StopPill extends StatefulWidget {
  final StopCategory category;
  final bool isActive;
  final VoidCallback onTap;
  final int delay; // stagger delay ms

  const _StopPill({
    required this.category,
    required this.isActive,
    required this.onTap,
    required this.delay,
  });

  @override
  State<_StopPill> createState() => _StopPillState();
}

class _StopPillState extends State<_StopPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    // Stagger appearance
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _animController.forward();
        setState(() => _appeared = true);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? cat.color.withValues(alpha: 0.25)
                : const Color(0xFF1A2030).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isActive
                  ? cat.color.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              if (widget.isActive)
                BoxShadow(
                  color: cat.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cat.icon,
                size: 18,
                color: widget.isActive ? cat.color : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                cat.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive ? cat.color : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Popup card shown when a stop is selected on the map.
/// Shows stop name, distance, and Add/Ignore buttons.
class StopPopupCard extends StatelessWidget {
  final String name;
  final String? address;
  final String distanceText;
  final IconData icon;
  final Color color;
  final VoidCallback onAdd;
  final VoidCallback onIgnore;

  const StopPopupCard({
    super.key,
    required this.name,
    this.address,
    required this.distanceText,
    required this.icon,
    required this.color,
    required this.onAdd,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$distanceText ahead',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Add stop?',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onIgnore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Ignore',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
