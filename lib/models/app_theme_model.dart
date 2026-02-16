class AppThemeModel {
  final String id;
  final String name;
  final String nameEn;
  final String nameFa;
  final String emoji;
  final ThemeColors colors;

  AppThemeModel({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.nameFa,
    required this.emoji,
    required this.colors,
  });
}

class ThemeColors {
  // Background colors
  final int backgroundColor;
  final int surfaceColor;
  final int cardColor;
  
  // Primary colors
  final int primaryColor;
  final int secondaryColor;
  final int accentColor;
  
  // Text colors
  final int textPrimaryColor;
  final int textSecondaryColor;
  
  // Status colors
  final int successColor;
  final int errorColor;
  final int warningColor;
  
  // Special colors
  final int timerColor;
  final int downloadColor;
  final int uploadColor;
  
  // UI elements
  final int borderColor;
  final int dividerColor;
  final double backgroundOpacity;
  final double surfaceOpacity;
  final double cardOpacity;

  ThemeColors({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.successColor,
    required this.errorColor,
    required this.warningColor,
    required this.timerColor,
    required this.downloadColor,
    required this.uploadColor,
    required this.borderColor,
    required this.dividerColor,
    this.backgroundOpacity = 1.0,
    this.surfaceOpacity = 0.05,
    this.cardOpacity = 0.08,
  });

  // Single Default Theme
  factory ThemeColors.defaultTheme() => ThemeColors(
    backgroundColor: 0xFF050505,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFF1a1a1a,
    primaryColor: 0xFF10b981,
    secondaryColor: 0xFF34d399,
    accentColor: 0xFF6ee7b7,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFFFFFFF,
    successColor: 0xFF10b981,
    errorColor: 0xFFef4444,
    warningColor: 0xFFfbbf24,
    timerColor: 0xFF10b981,
    downloadColor: 0xFF10b981,
    uploadColor: 0xFF34d399,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFFFFFFFF,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 1.0,
  );
}
