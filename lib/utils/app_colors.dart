import 'package:flutter/material.dart';

/// App color scheme - Pure Black with Cyan
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF000000);
  static const Color primaryDark = Color(0xFF000000);
  static const Color secondary = Color(0xFF121212);
  static const Color background = Color(0xFF000000);

  static const Color topGradient = Color(0xFF000000);

  // Gradient Colors (Ready To Connect / Disconnected)
  static const Color topGradientReadyToConnect = Color(0xFF000000);
  static const Color middleGradient = Color(0xFF0a0a0a);
  static const Color bottomGradient = Color(0xFF1a1a1a);

  // Gradient Colors (Connected)
  static const Color middleGradientConnected = Color(0xFF001a1a);
  static const Color bottomGradientConnected = Color(0xFF00D9FF);

  // Gradient Colors (No Internet)
  static const Color middleGradientNoInternet = Color(0xFF2a0a0a);
  static const Color bottomGradientNoInternet = Color(0xFFEF4444);

  // Gradient Colors (Failed To Connect / Error)
  static const Color middleGradientFailedToConnect = Color(0xFF2a1a0a);
  static const Color bottomGradientFailedToConnect = Color(0xFFFBBF24);

  // Connecting Colors
  static const Color topGradientConnecting = Color(0xFF000000);
  static const Color middleGradientConnecting = Color(0xFF001a2a);
  static const Color bottomGradientConnecting = Color(0xFF00D9FF);

  // Download, Upload and Warning Colors
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color downloadColor = Color(0xFF00FFA3);
  static const Color uploadColor = Color(0xFF00D9FF);
  
  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textDisabled = Color(0xFF808080);
}
