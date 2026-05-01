import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_keys.dart';
import '../services/home_widget_service.dart';

class ThemeProvider extends ChangeNotifier {
  final _homeWidgetService = HomeWidgetService();

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(PrefsKeys.themeMode) ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
      await _homeWidgetService.updateWidgetTheme(isDark);
    } catch (e, stackTrace) {
      debugPrint('⚠️ ThemeProvider: Failed to load theme: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> toggleTheme() async {
    final previous = _themeMode;
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.themeMode, _themeMode == ThemeMode.dark);
      await _homeWidgetService.updateWidgetTheme(_themeMode == ThemeMode.dark);
    } catch (e, stackTrace) {
      debugPrint('⚠️ ThemeProvider: Failed to persist theme: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _themeMode = previous;
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.themeMode, mode == ThemeMode.dark);
      await _homeWidgetService.updateWidgetTheme(mode == ThemeMode.dark);
    } catch (e, stackTrace) {
      debugPrint('⚠️ ThemeProvider: Failed to persist theme: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _themeMode = previous;
      notifyListeners();
    }
  }
}
