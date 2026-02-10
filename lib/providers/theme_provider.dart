import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_model.dart';

class ThemeProvider with ChangeNotifier {
  AppThemeModel _currentTheme = AppThemeModel(
    id: 'default',
    name: 'Default',
    nameEn: 'Dark Green',
    nameFa: 'سبز تیره',
    emoji: '💎',
    colors: ThemeColors.defaultTheme(),
  );

  AppThemeModel get currentTheme => _currentTheme;
  ThemeColors get colors => _currentTheme.colors;

  // Available themes
  final List<AppThemeModel> availableThemes = [
    AppThemeModel(
      id: 'default',
      name: 'Default',
      nameEn: 'Dark Green',
      nameFa: 'سبز تیره',
      emoji: '💎',
      colors: ThemeColors.defaultTheme(),
    ),
    AppThemeModel(
      id: 'ocean',
      name: 'Ocean',
      nameEn: 'Dark Blue',
      nameFa: 'آبی تیره',
      emoji: '🌊',
      colors: ThemeColors.oceanTheme(),
    ),
    AppThemeModel(
      id: 'sunset',
      name: 'Sunset',
      nameEn: 'Dark Purple',
      nameFa: 'بنفش تیره',
      emoji: '🌅',
      colors: ThemeColors.sunsetTheme(),
    ),
    AppThemeModel(
      id: 'forest',
      name: 'Forest',
      nameEn: 'Dark Red',
      nameFa: 'قرمز تیره',
      emoji: '🔥',
      colors: ThemeColors.forestTheme(),
    ),
  ];

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString('selected_theme') ?? 'default';
      
      final theme = availableThemes.firstWhere(
        (t) => t.id == themeId,
        orElse: () => availableThemes.first,
      );
      
      _currentTheme = theme;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> changeTheme(AppThemeModel theme) async {
    try {
      _currentTheme = theme;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_theme', theme.id);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  String getThemeName(String languageCode) {
    return languageCode == 'fa' ? _currentTheme.nameFa : _currentTheme.nameEn;
  }
}
