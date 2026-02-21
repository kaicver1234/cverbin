import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary colors - Pure Black Theme
  static const Color primaryCyan = Color(0xFF00D9FF);
  static const Color primaryGreen = Color(0xFF00FFA3); // Alias for compatibility
  static const Color primaryDark = Color(0xFF000000);
  static const Color primaryDarker = Color(0xFF000000);
  static const Color secondaryDark = Color(0xFF000000);
  static const Color cardDark = Color(0xFF121212);

  // Accent colors
  static const Color accentCyan = Color(0xFF00FFA3);
  static const Color disconnectedRed = Color(0xFFEF4444);
  static const Color connectingYellow = Color(0xFFF59E0B);

  // Text colors - High Contrast
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFE0E0E0);

  // Border colors
  static const Color borderDark = Color(0xFF2A2A2A);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryCyan, accentCyan],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, secondaryDark],
  );

  // Dark Theme
  static ThemeData darkTheme([String languageCode = 'en']) {
    final isRtlLanguage = languageCode == 'fa' || languageCode == 'ar';

    final baseTextTheme = isRtlLanguage
        ? GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    final baseAppBarTextStyle = isRtlLanguage
        ? GoogleFonts.vazirmatn(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textLight,
          )
        : GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textLight,
          );

    final baseButtonTextStyle = isRtlLanguage
        ? GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.w600)
        : GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600);

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: primaryDark,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: primaryCyan,
        secondary: accentCyan,
        surface: primaryDark,
        error: disconnectedRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: secondaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseAppBarTextStyle,
        iconTheme: const IconThemeData(color: textLight),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: baseButtonTextStyle,
        ),
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
      ),
    );
  }
}
