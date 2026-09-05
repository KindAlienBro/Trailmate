import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Loader — zero-dependency shimmer skeleton system
//
// Usage:
//   SkeletonBox(width: 140, height: 180, borderRadius: 20)
//   SkeletonLine(width: 120, height: 14)
//   SkeletonCircle(size: 56)
//
// Pre-composed layouts:
//   SkeletonTrendingCard()          — horizontal image card (140×180)
//   SkeletonNearbyCard()            — small horizontal card (120×140)
//   SkeletonTripCard()              — list row with image + text
//   SkeletonSearchResultTile()      — search result list tile
//   SkeletonTextParagraph()         — multi-line text block
//   SkeletonLobby()                 — full group lobby placeholder
//   SkeletonRouteOptions()          — route style option cards
// ─────────────────────────────────────────────────────────────────────────────

/// Animated shimmer wrapper. Wrap any child to give it a sweeping shine effect.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x33FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.3),
              end: Alignment(0.0 + 2.0 * _controller.value, 0.3),
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────── Primitives ───────────────────────

/// A rounded rectangle shimmer placeholder.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShimmerEffect(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A single text-line shimmer placeholder.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShimmerEffect(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// A circular shimmer placeholder (avatars, category icons).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShimmerEffect(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.borderColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────── Composed Skeletons ───────────────────────

/// Skeleton for a horizontal trending destination card (140×180).
class SkeletonTrendingCard extends StatelessWidget {
  const SkeletonTrendingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          const Positioned.fill(
            child: SkeletonBox(borderRadius: 20),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SkeletonLine(width: 80, height: 16),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a small horizontal nearby-place card (120×140).
class SkeletonNearbyCard extends StatelessWidget {
  const SkeletonNearbyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          const Positioned.fill(
            child: SkeletonBox(borderRadius: 20),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonLine(width: 64, height: 12),
                const SizedBox(height: 6),
                SkeletonLine(width: 48, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a trip card row (image + text lines).
class SkeletonTripCard extends StatelessWidget {
  const SkeletonTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 72, height: 72, borderRadius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(height: 16),
                const SizedBox(height: 8),
                SkeletonLine(width: 120, height: 12),
                const SizedBox(height: 8),
                SkeletonLine(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a search result list tile.
class SkeletonSearchResultTile extends StatelessWidget {
  const SkeletonSearchResultTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const SkeletonBox(width: 56, height: 56, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(height: 16),
                const SizedBox(height: 8),
                SkeletonLine(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a multi-line text paragraph (descriptions).
class SkeletonTextParagraph extends StatelessWidget {
  final int lineCount;

  const SkeletonTextParagraph({super.key, this.lineCount = 5});

  @override
  Widget build(BuildContext context) {
    // Vary widths to look like realistic text
    final widths = [1.0, 0.95, 1.0, 0.85, 0.6];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lineCount, (i) {
        final fraction = i < widths.length ? widths[i] : 0.9;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: const SkeletonLine(height: 14),
          ),
        );
      }),
    );
  }
}

/// Skeleton for the full group lobby screen (map placeholder + info sheet).
class SkeletonLobby extends StatelessWidget {
  const SkeletonLobby({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        // Map area placeholder
        Expanded(
          flex: 5,
          child: Container(
            color: colors.borderColor.withValues(alpha: 0.15),
            child: Center(
              child: ShimmerEffect(
                child: Icon(
                  Icons.map_rounded,
                  size: 64,
                  color: colors.borderColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        // Info sheet placeholder
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: colors.primaryBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pull tab
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Group name
                const SkeletonLine(width: 180, height: 20),
                const SizedBox(height: 12),
                // Route info line
                const SkeletonLine(width: 240, height: 14),
                const SizedBox(height: 24),
                // Member avatars row
                Row(
                  children: List.generate(
                    4,
                    (i) => const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SkeletonCircle(size: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons area
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 48, borderRadius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 48, borderRadius: 14)),
                  ],
                ),
                const Spacer(),
                // Start button
                const SkeletonBox(height: 56, borderRadius: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton for route style option cards in the bottom sheet.
class SkeletonRouteOptions extends StatelessWidget {
  const SkeletonRouteOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        // Map area placeholder
        Expanded(
          flex: 5,
          child: Container(
            color: colors.borderColor.withValues(alpha: 0.15),
            child: Center(
              child: ShimmerEffect(
                child: Icon(
                  Icons.route_rounded,
                  size: 64,
                  color: colors.borderColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        // Bottom sheet placeholder
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: colors.primaryBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Route style chips row
                  Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SkeletonBox(width: 90, height: 36, borderRadius: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Route option cards
                  ...List.generate(2, (i) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonBox(height: 72, borderRadius: 16),
                  )),
                  const SizedBox(height: 12),
                  const SkeletonBox(height: 56, borderRadius: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
