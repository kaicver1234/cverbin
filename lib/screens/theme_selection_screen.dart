import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../models/app_theme_model.dart';
import '../utils/app_localizations.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final colors = themeProvider.colors;
          
          return Scaffold(
            backgroundColor: Color(colors.backgroundColor),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, colors),
                  Expanded(
                    child: _buildThemeList(context, themeProvider, colors),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 12 : 16,
        8,
        isSmallScreen ? 12 : 16,
        isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(colors.borderColor).withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Color(colors.textPrimaryColor),
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('theme.title'),
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor),
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).translate('theme.subtitle'),
                  style: TextStyle(
                    color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                    fontSize: isSmallScreen ? 11 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeList(BuildContext context, ThemeProvider themeProvider, ThemeColors colors) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      physics: const BouncingScrollPhysics(),
      itemCount: themeProvider.availableThemes.length,
      itemBuilder: (context, index) {
        final theme = themeProvider.availableThemes[index];
        final isSelected = themeProvider.currentTheme.id == theme.id;
        final themeName = languageProvider.currentLanguage.code == 'fa' 
            ? theme.nameFa 
            : theme.nameEn;
        
        return _buildThemeCard(
          context,
          theme,
          themeName,
          isSelected,
          colors,
          isSmallScreen,
          () => themeProvider.changeTheme(theme),
        );
      },
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppThemeModel theme,
    String themeName,
    bool isSelected,
    ThemeColors currentColors,
    bool isSmallScreen,
    VoidCallback onTap,
  ) {
    final themeColors = theme.colors;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: Color(currentColors.surfaceColor).withValues(alpha: currentColors.surfaceOpacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Color(currentColors.primaryColor).withValues(alpha: 0.5)
                : Color(currentColors.borderColor).withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
          child: Row(
            children: [
              // Theme preview
              _buildThemePreview(themeColors, isSmallScreen),
              SizedBox(width: isSmallScreen ? 14 : 16),
              // Theme info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          theme.emoji,
                          style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 10),
                        Expanded(
                          child: Text(
                            themeName,
                            style: TextStyle(
                              color: Color(currentColors.textPrimaryColor),
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    _buildColorPalette(themeColors, isSmallScreen),
                  ],
                ),
              ),
              // Selection indicator
              Container(
                width: isSmallScreen ? 22 : 24,
                height: isSmallScreen ? 22 : 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected 
                      ? Color(currentColors.primaryColor) 
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? Color(currentColors.primaryColor)
                        : Color(currentColors.borderColor).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: isSmallScreen ? 14 : 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePreview(ThemeColors colors, bool isSmallScreen) {
    final size = isSmallScreen ? 60.0 : 70.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(colors.backgroundColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(colors.borderColor).withValues(alpha: 0.2),
        ),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(colors.primaryColor).withValues(alpha: 0.2),
                    Color(colors.secondaryColor).withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
          // Mini UI elements
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Color(colors.primaryColor),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(colors.primaryColor).withValues(alpha: 0.3),
                border: Border.all(
                  color: Color(colors.primaryColor),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette(ThemeColors colors, bool isSmallScreen) {
    final colorSize = isSmallScreen ? 16.0 : 18.0;
    final spacing = isSmallScreen ? 6.0 : 8.0;
    
    return Row(
      children: [
        _buildColorDot(Color(colors.primaryColor), colorSize),
        SizedBox(width: spacing),
        _buildColorDot(Color(colors.secondaryColor), colorSize),
        SizedBox(width: spacing),
        _buildColorDot(Color(colors.accentColor), colorSize),
        SizedBox(width: spacing),
        _buildColorDot(Color(colors.successColor), colorSize),
      ],
    );
  }

  Widget _buildColorDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
