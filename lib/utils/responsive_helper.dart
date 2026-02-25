import 'package:flutter/material.dart';

/// Responsive helper for different screen sizes
class ResponsiveHelper {
  final BuildContext context;
  
  ResponsiveHelper(this.context);
  
  /// Get screen width
  double get width => MediaQuery.of(context).size.width;
  
  /// Get screen height
  double get height => MediaQuery.of(context).size.height;
  
  /// Check if device is small (width < 360)
  bool get isSmallDevice => width < 360;
  
  /// Check if device is medium (360 <= width < 400)
  bool get isMediumDevice => width >= 360 && width < 400;
  
  /// Check if device is large (width >= 400)
  bool get isLargeDevice => width >= 400;
  
  /// Get responsive value based on screen size
  T responsive<T>({
    required T small,
    required T medium,
    required T large,
  }) {
    if (isSmallDevice) return small;
    if (isMediumDevice) return medium;
    return large;
  }
  
  /// Get responsive double value
  double responsiveValue({
    required double small,
    required double medium,
    required double large,
  }) {
    if (isSmallDevice) return small;
    if (isMediumDevice) return medium;
    return large;
  }
  
  /// Scale value proportionally based on screen width (base: 375)
  double scale(double value) {
    return value * (width / 375);
  }
  
  /// Get horizontal padding
  double get horizontalPadding => scale(20).clamp(14.0, 28.0);
  
  /// Get vertical spacing
  double get verticalSpacing => scale(20).clamp(14.0, 28.0);
  
  /// Connection button size
  double get connectionButtonSize => scale(155).clamp(125.0, 185.0);
  
  /// Connection button icon size
  double get connectionButtonIconSize => scale(44).clamp(36.0, 54.0);
  
  /// Header font size
  double get headerFontSize => scale(22).clamp(18.0, 28.0);
  
  /// Timer font size
  double get timerFontSize => scale(20).clamp(16.0, 26.0);
  
  /// Stats value font size
  double get statsValueFontSize => scale(15).clamp(12.0, 20.0);
  
  /// Stats label font size
  double get statsLabelFontSize => scale(11.5).clamp(9.5, 14.0);
  
  /// Stats icon size
  double get statsIconSize => scale(14).clamp(11.0, 18.0);
  
  /// Server card icon size
  double get serverIconSize => scale(54).clamp(44.0, 68.0);
  
  /// Server card padding
  double get serverCardPadding => scale(15).clamp(12.0, 20.0);
  
  /// Tool card icon size
  double get toolIconSize => scale(30).clamp(24.0, 40.0);
  
  /// Tool card padding
  double get toolCardPadding => scale(20).clamp(15.0, 28.0);
  
  /// Bottom nav height
  double get bottomNavHeight => scale(78).clamp(68.0, 95.0);
  
  /// Bottom nav button size
  double get bottomNavButtonSize => scale(50).clamp(42.0, 62.0);
  
  /// Page title font size
  double get pageTitleFontSize => scale(26).clamp(20.0, 34.0);
  
  /// About logo size
  double get aboutLogoSize => scale(75).clamp(60.0, 95.0);
  
  /// About title font size
  double get aboutTitleFontSize => scale(26).clamp(20.0, 34.0);
}
