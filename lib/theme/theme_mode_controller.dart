import 'package:flutter/material.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeMode _mode;

  ThemeModeController({ThemeMode initialMode = ThemeMode.system})
      : _mode = initialMode;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleDarkLight() {
    // If currently system, toggle to dark (common UX) otherwise flip
    if (_mode == ThemeMode.system) {
      _mode = ThemeMode.dark;
    } else if (_mode == ThemeMode.dark) {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  void cycle() {
    // optional: system -> light -> dark -> system
    if (_mode == ThemeMode.system) {
      _mode = ThemeMode.light;
    } else if (_mode == ThemeMode.light) {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }
}