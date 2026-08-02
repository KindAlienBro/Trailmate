import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

/// Theme state manager — persists user's theme choice.
class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'selected_theme';

  AppThemeMode _currentMode = AppThemeMode.dark;
  bool _isInitialized = false;

  AppThemeMode get currentMode => _currentMode;
  AppColorScheme get colors => AppColorScheme.fromMode(_currentMode);
  bool get isInitialized => _isInitialized;

  /// Load saved theme from disk.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved != null) {
      _currentMode = AppThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => AppThemeMode.dark,
      );
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Switch theme with persistence.
  Future<void> setTheme(AppThemeMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Cycle to next theme (for quick-switch gesture).
  Future<void> cycleTheme() async {
    final modes = AppThemeMode.values;
    final nextIndex = (modes.indexOf(_currentMode) + 1) % modes.length;
    await setTheme(modes[nextIndex]);
  }
}
