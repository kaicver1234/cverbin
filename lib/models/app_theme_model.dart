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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameEn': nameEn,
    'nameFa': nameFa,
    'emoji': emoji,
  };

  factory AppThemeModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return AppThemeModel(
      id: id,
      name: json['name'] as String,
      nameEn: json['nameEn'] as String,
      nameFa: json['nameFa'] as String,
      emoji: json['emoji'] as String,
      colors: _getThemeColors(id),
    );
  }

  static ThemeColors _getThemeColors(String id) {
    switch (id) {
      case 'default':
        return ThemeColors.defaultTheme();
      case 'light':
        return ThemeColors.lightTheme();
      case 'ocean':
        return ThemeColors.oceanTheme();
      case 'sunset':
        return ThemeColors.sunsetTheme();
      case 'forest':
        return ThemeColors.forestTheme();
      default:
        return ThemeColors.defaultTheme();
    }
  }
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

  // Default Dark Theme (Current - Green/Purple)
  factory ThemeColors.defaultTheme() => ThemeColors(
    backgroundColor: 0xFF0a0a0f,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFFFFFFFF,
    primaryColor: 0xFF10b981,
    secondaryColor: 0xFFa78bfa,
    accentColor: 0xFF06b6d4,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFFFFFFF,
    successColor: 0xFF10b981,
    errorColor: 0xFFef4444,
    warningColor: 0xFFfbbf24,
    timerColor: 0xFF10b981,
    downloadColor: 0xFF10b981,
    uploadColor: 0xFF06b6d4,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFFFFFFFF,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 0.08,
  );

  // Light Theme - Soft and comfortable for eyes
  factory ThemeColors.lightTheme() => ThemeColors(
    backgroundColor: 0xFFf8f9fb,
    surfaceColor: 0xFF1e293b,
    cardColor: 0xFFFFFFFF,
    primaryColor: 0xFF10b981,
    secondaryColor: 0xFFa78bfa,
    accentColor: 0xFF06b6d4,
    textPrimaryColor: 0xFF0f172a,
    textSecondaryColor: 0xFF475569,
    successColor: 0xFF10b981,
    errorColor: 0xFFef4444,
    warningColor: 0xFFf59e0b,
    timerColor: 0xFF10b981,
    downloadColor: 0xFF10b981,
    uploadColor: 0xFF06b6d4,
    borderColor: 0xFFcbd5e1,
    dividerColor: 0xFFe2e8f0,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.03,
    cardOpacity: 1.0,
  );

  // Blue Theme - Same structure, blue colors
  factory ThemeColors.oceanTheme() => ThemeColors(
    backgroundColor: 0xFF0a0a0f,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFFFFFFFF,
    primaryColor: 0xFF3b82f6,
    secondaryColor: 0xFF8b5cf6,
    accentColor: 0xFF06b6d4,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFFFFFFF,
    successColor: 0xFF3b82f6,
    errorColor: 0xFFef4444,
    warningColor: 0xFFfbbf24,
    timerColor: 0xFF3b82f6,
    downloadColor: 0xFF3b82f6,
    uploadColor: 0xFF06b6d4,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFFFFFFFF,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 0.08,
  );

  // Purple Theme - Same structure, purple colors
  factory ThemeColors.sunsetTheme() => ThemeColors(
    backgroundColor: 0xFF0a0a0f,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFFFFFFFF,
    primaryColor: 0xFFa855f7,
    secondaryColor: 0xFFec4899,
    accentColor: 0xFF8b5cf6,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFFFFFFF,
    successColor: 0xFFa855f7,
    errorColor: 0xFFef4444,
    warningColor: 0xFFfbbf24,
    timerColor: 0xFFa855f7,
    downloadColor: 0xFFa855f7,
    uploadColor: 0xFFec4899,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFFFFFFFF,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 0.08,
  );

  // Red Theme - Same structure, red colors
  factory ThemeColors.forestTheme() => ThemeColors(
    backgroundColor: 0xFF0a0a0f,
    surfaceColor: 0xFFFFFFFF,
    cardColor: 0xFFFFFFFF,
    primaryColor: 0xFFef4444,
    secondaryColor: 0xFFf97316,
    accentColor: 0xFFfbbf24,
    textPrimaryColor: 0xFFFFFFFF,
    textSecondaryColor: 0xFFFFFFFF,
    successColor: 0xFFef4444,
    errorColor: 0xFFef4444,
    warningColor: 0xFFfbbf24,
    timerColor: 0xFFef4444,
    downloadColor: 0xFFef4444,
    uploadColor: 0xFFf97316,
    borderColor: 0xFFFFFFFF,
    dividerColor: 0xFFFFFFFF,
    backgroundOpacity: 1.0,
    surfaceOpacity: 0.05,
    cardOpacity: 0.08,
  );
}
