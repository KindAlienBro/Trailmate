import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../core/theme.dart';

/// RoUniity Premium Theme
///
/// Multi-theme design system. Generates a full Material ThemeData
/// from any AppColorScheme, so all 3 themes (Dark, Light, Adventure)
/// share the same structural shapes/spacing but swap colors dynamically.

class AppTheme {
  // ==================== Legacy Static Colors ====================
  // Kept for backward compat during migration. New code should use
  // AppColors.of(context).xyz instead.
  static const Color primaryDark = Color(0xFF0A0E21);
  static const Color surfaceDark = Color(0xFF1A1F38);
  static const Color cardDark = Color(0xFF222842);
  static const Color borderDark = Color(0xFF2D3354);

  static const Color accentBlue = Color(0xFF4FC3F7);
  static const Color accentBlueDark = Color(0xFF2196F3);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentGreenDark = Color(0xFF00C853);
  static const Color accentOrange = Color(0xFFFFAB40);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentRedDark = Color(0xFFD32F2F);
  static const Color accentPurple = Color(0xFFB388FF);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8D1);
  static const Color textTertiary = Color(0xFF6B7394);
  static const Color textOnAccent = Color(0xFF0A0E21);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A237E), Color(0xFF0A0E21)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, accentGreen],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentRed, accentOrange],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2444), Color(0xFF161B33)],
  );

  // ==================== Legacy Getter ====================
  static ThemeData get darkTheme => buildTheme(AppColorScheme.dark);

  // ==================== Dynamic Theme Builder ====================
  static ThemeData buildTheme(AppColorScheme c) {
    final isDark = c.brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.primaryBackground,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accentPrimary,
        secondary: c.accentSecondary,
        surface: c.surfaceColor,
        error: c.accentDanger,
        onPrimary: c.textOnAccent,
        onSecondary: c.textOnAccent,
        onSurface: c.textPrimary,
        onError: c.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: c.textPrimary),
        displayMedium: GoogleFonts.outfit(color: c.textPrimary),
        displaySmall: GoogleFonts.outfit(color: c.textPrimary),
        headlineLarge: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.outfit(color: c.textPrimary, fontWeight: FontWeight.w500),
      ).apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.primaryBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.cardColor,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.borderColor, width: isDark ? 1 : 0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accentPrimary,
          foregroundColor: c.textOnAccent,
          elevation: isDark ? 0 : 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accentPrimary,
          side: BorderSide(color: c.accentPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: c.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: c.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: c.accentPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: c.accentDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: c.accentDanger, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          color: c.textTertiary,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: c.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.cardColor,
        contentTextStyle: GoogleFonts.inter(color: c.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: c.borderColor,
      iconTheme: IconThemeData(color: c.textSecondary),
    );
  }
}

// ==================== Theme-Aware Custom Decorations ====================

/// Glassmorphic card decoration — adapts to current theme
BoxDecoration themedGlassCard(AppColorScheme c, {double opacity = 0.1}) {
  final isDark = c.brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: opacity)
        : c.cardColor.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(32),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : c.borderColor.withValues(alpha: 0.5),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.06),
        blurRadius: isDark ? 20 : 12,
        offset: Offset(0, 8),
      ),
    ],
  );
}

/// Accent gradient button decoration — uses theme accents
BoxDecoration themedAccentButton(AppColorScheme c) {
  return BoxDecoration(
    gradient: c.accentGradient,
    borderRadius: BorderRadius.circular(32),
    boxShadow: [
      BoxShadow(
        color: c.accentPrimary.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );
}

/// SOS / Danger button decoration — uses theme danger colors
BoxDecoration themedDangerButton(AppColorScheme c) {
  return BoxDecoration(
    gradient: c.dangerGradient,
    borderRadius: BorderRadius.circular(32),
    boxShadow: [
      BoxShadow(
        color: c.accentDanger.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );
}

// ==================== Legacy Decorations (backward compat) ====================

BoxDecoration glassCardDecoration({double opacity = 0.1}) {
  return themedGlassCard(AppColorScheme.dark, opacity: opacity);
}

BoxDecoration accentButtonDecoration() {
  return themedAccentButton(AppColorScheme.dark);
}

BoxDecoration dangerButtonDecoration() {
  return themedDangerButton(AppColorScheme.dark);
}
