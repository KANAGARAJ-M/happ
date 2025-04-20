import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemeProvider() {
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'Light':
          _themeMode = ThemeMode.light;
          break;
        case 'Dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'System':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      notifyListeners();
    }
  }
  
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    
    // Save preference
    _saveThemePreference();
  }
  
  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'Light';
        break;
      case ThemeMode.dark:
        themeString = 'Dark';
        break;
      case ThemeMode.system:
      default:
        themeString = 'System';
        break;
    }
    
    await prefs.setString('theme_mode', themeString);
  }
}