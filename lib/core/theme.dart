import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TrailMate Premium Theme
///
/// Dark-mode-first design with a navigation-inspired color palette.
/// Deep navy backgrounds, electric blue accents, emerald green for success,
/// and alert red for emergencies.

class AppTheme {
  // ==================== Color Palette ====================
  static const Color primaryDark = Color(0xFF0A0E21);       // Deep navy
  static const Color surfaceDark = Color(0xFF1A1F38);       // Lighter navy
  static const Color cardDark = Color(0xFF222842);          // Card background
  static const Color borderDark = Color(0xFF2D3354);        // Subtle borders

  static const Color accentBlue = Color(0xFF4FC3F7);        // Electric blue
  static const Color accentBlueDark = Color(0xFF2196F3);    // Deeper blue
  static const Color accentGreen = Color(0xFF00E676);       // Emerald green
  static const Color accentGreenDark = Color(0xFF00C853);   // Deeper green
  static const Color accentOrange = Color(0xFFFFAB40);      // Warning orange
  static const Color accentRed = Color(0xFFFF5252);         // Alert red
  static const Color accentRedDark = Color(0xFFD32F2F);     // Deeper red
  static const Color accentPurple = Color(0xFFB388FF);      // Soft purple

  static const Color textPrimary = Color(0xFFFFFFFF);       // White
  static const Color textSecondary = Color(0xFFB0B8D1);     // Muted blue-gray
  static const Color textTertiary = Color(0xFF6B7394);      // Even more muted
  static const Color textOnAccent = Color(0xFF0A0E21);      // Dark text on bright

  // ==================== Gradients ====================
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

  // ==================== Theme Data ====================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentGreen,
        surface: surfaceDark,
        error: accentRed,
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: textOnAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: const BorderSide(color: accentBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentRed),
        ),
        hintStyle: GoogleFonts.inter(
          color: textTertiary,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: borderDark,
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }
}

// ==================== Custom Decorations ====================

/// Glassmorphic card decoration
BoxDecoration glassCardDecoration({double opacity = 0.1}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.15),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Accent gradient button decoration
BoxDecoration accentButtonDecoration() {
  return BoxDecoration(
    gradient: AppTheme.accentGradient,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppTheme.accentBlue.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// SOS / Danger button decoration
BoxDecoration dangerButtonDecoration() {
  return BoxDecoration(
    gradient: AppTheme.dangerGradient,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppTheme.accentRed.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
