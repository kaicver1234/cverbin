import 'package:flutter/material.dart';
import '../models/app_theme_model.dart';

class ThemeProvider with ChangeNotifier {
  // Single default theme - no theme switching
  final AppThemeModel _currentTheme = AppThemeModel(
    id: 'default',
    name: 'Default',
    nameEn: 'Dark Theme',
    nameFa: 'تم تیره',
    emoji: '💎',
    colors: ThemeColors.defaultTheme(),
  );

  AppThemeModel get currentTheme => _currentTheme;
  ThemeColors get colors => _currentTheme.colors;

  String getThemeName(String languageCode) {
    return languageCode == 'fa' ? _currentTheme.nameFa : _currentTheme.nameEn;
  }
}
