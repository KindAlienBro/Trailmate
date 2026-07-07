import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/navigation_provider.dart';

/// Card to display nearby Point of Interest (POI)
class PoiCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onTap;

  const PoiCard({
    super.key,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Try to map Google/Ola type to our icons, fallback to location
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

    final emoji = AppConstants.poiIcons[iconKey] ?? '📍';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: glassCardDecoration(opacity: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                if (place.rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppTheme.accentOrange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          place.rating!.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (place.address != null) ...[
              const SizedBox(height: 4),
              Text(
                place.address!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
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
