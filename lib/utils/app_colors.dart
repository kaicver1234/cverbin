import 'package:flutter/material.dart';

/// App color scheme inspired by defyxVPN
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1a1a2e);
  static const Color primaryDark = Color(0xFF0f1419);
  static const Color secondary = Color(0xFF16213e);
  static const Color background = Color(0xFF0f3460);

  static const Color topGradient = Color(0xFF18181E);

  // Gradient Colors (Ready To Connect / Disconnected)
  static const Color topGradientReadyToConnect = Color(0xFF1C1C1C);
  static const Color middleGradient = Color(0xFF1C1C1C);
  static const Color bottomGradient = Color(0xFF585858);

  // Gradient Colors (Connected)
  static const Color middleGradientConnected = Color(0xFF1C443B);
  static const Color bottomGradientConnected = Color(0xFF21AD86);

  // Gradient Colors (No Internet)
  static const Color middleGradientNoInternet = Color(0xFF9A2635);
  static const Color bottomGradientNoInternet = Color(0xFFE72E44);

  // Gradient Colors (Failed To Connect / Error)
  static const Color middleGradientFailedToConnect = Color(0xFF867229);
  static const Color bottomGradientFailedToConnect = Color(0xFFD9B639);

  // Connecting Colors
  static const Color topGradientConnecting = Color(0xFF18181E);
  static const Color middleGradientConnecting = Color(0xFF4161A6);
  static const Color bottomGradientConnecting = Color(0xFF23499C);

  // Download, Upload and Warning Colors
  static const Color warningColor = Color(0xFFFFAA66);
  static const Color downloadColor = Color(0xFF76F959);
  static const Color uploadColor = Color(0xFF72D9FF);
  
  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF606060);
}
