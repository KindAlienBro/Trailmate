import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../providers/navigation_provider.dart';
import '../core/app_colors.dart';
import '../core/theme.dart';

/// Card to display nearby Point of Interest (POI)
class PoiCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onTap;

  PoiCard({
    super.key,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Try to map Google/Ola type to our icons, fallback to place icon
    String iconKey = 'Food';
    if (place.type != null) {
      if (place.type!.contains('gas') || place.type!.contains('fuel')) {
        iconKey = 'Fuel';
      } else if (place.type!.contains('hospital') || place.type!.contains('doctor')) {
        iconKey = 'Hospital';
      } else if (place.type!.contains('lodging') || place.type!.contains('hotel')) {
        iconKey = 'Hotel';
      } else if (place.type!.contains('parking')) {
        iconKey = 'Parking';
      }
    }

    final iconData = AppConstants.poiIcons[iconKey] ?? Icons.place_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: themedGlassCard(colors, opacity: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: const Color(0xFF4CAF50), size: 22),
                ),
                SizedBox(width: 12),
                if (place.rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.accentWarning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, color: colors.accentWarning, size: 14),
                        SizedBox(width: 4),
                        Text(
                          place.rating!.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accentWarning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              place.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (place.address != null) ...[
              SizedBox(height: 4),
              Text(
                place.address!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
