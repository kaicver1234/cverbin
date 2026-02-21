import 'package:flutter/material.dart';
import '../models/app_theme_model.dart';

class ThemeProvider with ChangeNotifier {
  // Only default theme - no theme switching
  final AppThemeModel _currentTheme = AppThemeModel(
    id: 'default',
    name: 'Default',
    nameEn: 'Pure Black',
    nameFa: 'مشکی خالص',
    emoji: '🖤',
    colors: ThemeColors.defaultTheme(),
  );

  AppThemeModel get currentTheme => _currentTheme;
  ThemeColors get colors => _currentTheme.colors;

  String getThemeName(String languageCode) {
    return languageCode == 'fa' ? _currentTheme.nameFa : _currentTheme.nameEn;
  }
}
