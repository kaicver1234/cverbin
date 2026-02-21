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
    required this.downloadColor,
    required this.uploadColor,
    required this.borderColor,
    required this.dividerColor,
    this.backgroundOpacity = 1.0,
    this.surfaceOpacity = 0.05,
    this.cardOpacity = 0.08,
  });

  // Default Theme - Pure Black with Cyan
  factory ThemeColors.defaultTheme() => ThemeColors(
    backgroundColor: 0xFF000000,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFF121212,
    primaryColor: 0xFF00D9FF,
    secondaryColor: 0xFF00FFA3,
    accentColor: 0xFF00D9FF,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFE0E0E0,
    successColor: 0xFF00FFA3,
    errorColor: 0xFFEF4444,
    warningColor: 0xFFFBBF24,
    downloadColor: 0xFF00FFA3,
    uploadColor: 0xFF00D9FF,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFF2A2A2A,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 1.0,
  );
}
