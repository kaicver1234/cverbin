import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AppTheme {
  // Primary colors
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryDark = Color(0xFF121212);
  static const Color primaryDarker = Color(0xFF0A0A0A);
  static const Color secondaryDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF252525);

  // Accent colors
  static const Color accentGreen = Color(0xFF69F0AE);
  static const Color disconnectedRed = Color(0xFFFF5252);
  static const Color connectingYellow = Color(0xFFFFD740);

  // Text colors
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, Color(0xFF00E676)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, secondaryDark],
  );

  // Theme data with conditional font support
  static ThemeData darkTheme([String languageCode = 'en']) {
    final isRtlLanguage = languageCode == 'fa' || languageCode == 'ar';

    // Use Vazirmatn font for Persian and Arabic, Poppins for others
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
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: primaryGreen,
        secondary: accentGreen,
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
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: textLight,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: baseButtonTextStyle,
        ),
      ),
      textTheme: baseTextTheme,
      dividerTheme: const DividerThemeData(
        color: Color(0xFF323232),
        thickness: 1,
      ),
    );
  }
}
