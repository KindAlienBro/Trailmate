import 'package:flutter/material.dart';

/// RoUniity Design Token System
///
/// Provides theme-aware colors & gradients that change dynamically
/// based on the active theme. Access via `AppColors.of(context)`.
///
/// Three presets: Dark (default), Light (clean & modern), Adventure (nature).

enum AppThemeMode { dark, light, adventure }

class AppColorScheme {
  // ==================== Core Surfaces ====================
  final Color primaryBackground;
  final Color surfaceColor;
  final Color cardColor;
  final Color borderColor;

  // ==================== Accents ====================
  final Color accentPrimary;       // Main accent (buttons, links)
  final Color accentPrimaryDark;   // Deeper variant
  final Color accentSecondary;     // Secondary accent (success, go)
  final Color accentSecondaryDark;
  final Color accentWarning;       // Warning/caution
  final Color accentDanger;        // Alert/error
  final Color accentDangerDark;
  final Color accentExtra;         // Purple/extra accent

  // ==================== Text ====================
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;        // Text on bright accent backgrounds

  // ==================== Gradients ====================
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final LinearGradient dangerGradient;
  final LinearGradient cardGradient;

  // ==================== Meta ====================
  final Brightness brightness;
  final String name;
  final String description;
  final String emoji;

  const AppColorScheme({
    required this.primaryBackground,
    required this.surfaceColor,
    required this.cardColor,
    required this.borderColor,
    required this.accentPrimary,
    required this.accentPrimaryDark,
    required this.accentSecondary,
    required this.accentSecondaryDark,
    required this.accentWarning,
    required this.accentDanger,
    required this.accentDangerDark,
    required this.accentExtra,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.primaryGradient,
    required this.accentGradient,
    required this.dangerGradient,
    required this.cardGradient,
    required this.brightness,
    required this.name,
    required this.description,
    required this.emoji,
  });

  // ==================== Theme Presets ====================

  /// 🌙 Midnight Elegance (Default) — Soft graphite with deep blue and purple accents
  static const dark = AppColorScheme(
    primaryBackground: Color(0xFF121212),
    surfaceColor: Color(0xFF1E1E24),
    cardColor: Color(0xFF232329),
    borderColor: Color(0xFF33333B),
    accentPrimary: Color(0xFF5E6AD2),
    accentPrimaryDark: Color(0xFF4A55B2),
    accentSecondary: Color(0xFF10B981),
    accentSecondaryDark: Color(0xFF047857),
    accentWarning: Color(0xFFF59E0B),
    accentDanger: Color(0xFFEF4444),
    accentDangerDark: Color(0xFFB91C1C),
    accentExtra: Color(0xFF8B5CF6),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    textOnAccent: Color(0xFFFFFFFF),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E1E24), Color(0xFF121212)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFF5E6AD2)],
    ),
    dangerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF87171), Color(0xFFEF4444)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF232329), Color(0xFF1E1E24)],
    ),
    brightness: Brightness.dark,
    name: 'Midnight',
    description: 'Deep graphite with elegant soft accents',
    emoji: '🌙',
  );

  /// ☀️ Clean Light — Crisp white, soft shadows, sharp contrast
  static const light = AppColorScheme(
    primaryBackground: Color(0xFFF4F5F7),
    surfaceColor: Color(0xFFFFFFFF),
    cardColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFFE2E4E9),
    accentPrimary: Color(0xFF1D4ED8),
    accentPrimaryDark: Color(0xFF1E3A8A),
    accentSecondary: Color(0xFF10B981),
    accentSecondaryDark: Color(0xFF047857),
    accentWarning: Color(0xFFF59E0B),
    accentDanger: Color(0xFFEF4444),
    accentDangerDark: Color(0xB91C1C),
    accentExtra: Color(0xFF8B5CF6),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textOnAccent: Color(0xFFFFFFFF),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEFF6FF), Color(0xFFF4F5F7)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    dangerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEF4444), Color(0xFFFCA5A5)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
    ),
    brightness: Brightness.light,
    name: 'Clean Light',
    description: 'Crisp, high-contrast, minimalist',
    emoji: '☀️',
  );

  /// 🏔️ Expedition — Deep greens, high contrast orange for outdoors
  static const adventure = AppColorScheme(
    primaryBackground: Color(0xFF121A15),
    surfaceColor: Color(0xFF1C2720),
    cardColor: Color(0xFF24322A),
    borderColor: Color(0xFF33463B),
    accentPrimary: Color(0xFFF97316),
    accentPrimaryDark: Color(0xFFC2410C),
    accentSecondary: Color(0xFF22C55E),
    accentSecondaryDark: Color(0xFF15803D),
    accentWarning: Color(0xFFEAB308),
    accentDanger: Color(0xFFEF4444),
    accentDangerDark: Color(0xFFB91C1C),
    accentExtra: Color(0xFF0EA5E9),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFFA7F3D0),
    textTertiary: Color(0xFF6EE7B7),
    textOnAccent: Color(0xFFFFFFFF),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF064E3B), Color(0xFF121A15)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFB923C), Color(0xFFF97316)],
    ),
    dangerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF87171), Color(0xFFEF4444)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF24322A), Color(0xFF1C2720)],
    ),
    brightness: Brightness.dark,
    name: 'Expedition',
    description: 'High visibility outdoor rugged theme',
    emoji: '🏔️',
  );

  /// Get preset by mode
  static AppColorScheme fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return dark;
      case AppThemeMode.light:
        return light;
      case AppThemeMode.adventure:
        return adventure;
    }
  }

  /// Get all theme swatches for preview
  List<Color> get swatchColors => [
    primaryBackground,
    surfaceColor,
    accentPrimary,
    accentSecondary,
    accentWarning,
    accentDanger,
  ];
}

/// InheritedWidget to provide AppColorScheme down the tree.
/// Access with `AppColors.of(context)`.
class AppColors extends InheritedWidget {
  final AppColorScheme colors;

  const AppColors({
    super.key,
    required this.colors,
    required super.child,
  });

  static AppColorScheme of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AppColors>();
    return widget?.colors ?? AppColorScheme.dark;
  }

  @override
  bool updateShouldNotify(AppColors oldWidget) {
    return colors != oldWidget.colors;
  }
}
