import 'package:flutter/material.dart';

/// Responsive helper supporting phones, tablets, and landscape.
///
/// Sizing strategy:
///  - Scaling is based on the device's `shortestSide` (so a tablet held in
///    landscape still scales like a tablet, not like a huge phone).
///  - All sized getters are clamped to a sane min/max so layouts never blow
///    up on 7"–13" tablets or collapse on 320dp phones.
class ResponsiveHelper {
  final BuildContext context;
  final MediaQueryData _mq;

  ResponsiveHelper(this.context) : _mq = MediaQuery.of(context);

  // ─── Raw metrics ─────────────────────────────────────────────────────────
  double get width => _mq.size.width;
  double get height => _mq.size.height;
  double get shortestSide => _mq.size.shortestSide;
  double get longestSide => _mq.size.longestSide;
  Orientation get orientation => _mq.orientation;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
  double get textScale => _mq.textScaler.scale(1.0).clamp(0.85, 1.30);

  // ─── Breakpoints (based on shortestSide for orientation-independence) ────
  bool get isSmallPhone  => shortestSide < 340;            // very small / old phones
  bool get isPhone       => shortestSide < 600;            // all phones
  bool get isSmallTablet => shortestSide >= 600 && shortestSide < 720; // 7–8" tablets
  bool get isTablet      => shortestSide >= 600;           // any tablet
  bool get isLargeTablet => shortestSide >= 840;           // 10"+ tablets

  // Legacy aliases (kept so existing call sites keep working)
  bool get isSmallDevice  => width < 360;
  bool get isMediumDevice => width >= 360 && width < 400;
  bool get isLargeDevice  => width >= 400;

  /// Pick a value based on device class.
  T deviceValue<T>({required T phone, T? smallPhone, T? tablet, T? largeTablet}) {
    if (isLargeTablet && largeTablet != null) return largeTablet;
    if (isTablet && tablet != null) return tablet;
    if (isSmallPhone && smallPhone != null) return smallPhone;
    return phone;
  }

  T responsive<T>({required T small, required T medium, required T large}) {
    if (isSmallDevice) return small;
    if (isMediumDevice) return medium;
    return large;
  }

  double responsiveValue({required double small, required double medium, required double large}) {
    if (isSmallDevice) return small;
    if (isMediumDevice) return medium;
    return large;
  }

  /// Proportional scaling against a 375dp design baseline using shortestSide,
  /// so tablets don't get phone-sized UI just because they're held landscape.
  double scale(double value) {
    final base = shortestSide / 375.0;
    // Dampen growth on tablets: full scale up to phones, then 70% growth after.
    final factor = base <= 1.0 ? base : 1.0 + (base - 1.0) * 0.55;
    return value * factor;
  }

  /// Scale + clamp in one call.
  double sp(double value, {double? min, double? max}) {
    final v = scale(value);
    return v.clamp(min ?? value * 0.75, max ?? value * 1.6);
  }

  // ─── Layout primitives ───────────────────────────────────────────────────
  double get horizontalPadding => scale(20).clamp(14.0, 40.0);
  double get verticalSpacing   => scale(20).clamp(12.0, 36.0);
  double get sectionGap        => scale(16).clamp(10.0, 28.0);
  double get cardRadius        => scale(20).clamp(14.0, 28.0);
  double get safeBottomGap     => scale(12).clamp(8.0, 24.0);

  /// Max content width — caps reading width on tablets/landscape.
  double get maxContentWidth => isTablet ? 720.0 : double.infinity;

  /// Max width for centered dialogs and modal sheets.
  double get dialogMaxWidth => isTablet ? 480.0 : (width * 0.92).clamp(280.0, 420.0);

  // ─── Home screen ─────────────────────────────────────────────────────────
  double get connectionButtonSize {
    final base = scale(155);
    return isLandscape
        ? base.clamp(110.0, 160.0)
        : base.clamp(125.0, 220.0);
  }
  double get connectionButtonIconSize => scale(44).clamp(34.0, 60.0);
  double get headerFontSize => scale(22).clamp(17.0, 30.0);
  double get timerFontSize  => scale(34).clamp(26.0, 46.0);

  // ─── Stats ───────────────────────────────────────────────────────────────
  double get statsValueFontSize => scale(15).clamp(12.0, 20.0);
  double get statsLabelFontSize => scale(11.5).clamp(9.5, 14.0);
  double get statsIconSize      => scale(14).clamp(11.0, 18.0);

  // ─── Server cards ────────────────────────────────────────────────────────
  double get serverIconSize    => scale(34).clamp(26.0, 44.0);
  double get serverCardPadding => scale(15).clamp(12.0, 22.0);
  double get flagWidth         => scale(48).clamp(38.0, 60.0);
  double get flagHeight        => scale(36).clamp(28.0, 46.0);

  // ─── Tools (speedtest, host check, etc.) ─────────────────────────────────
  double get toolIconSize    => scale(30).clamp(24.0, 44.0);
  double get toolCardPadding => scale(20).clamp(14.0, 28.0);

  // ─── Bottom nav ──────────────────────────────────────────────────────────
  double get bottomNavHeight => (isLandscape ? scale(64) : scale(78)).clamp(58.0, 96.0);
  double get bottomNavButtonSize => scale(50).clamp(40.0, 64.0);

  // ─── Generic typography ──────────────────────────────────────────────────
  double get pageTitleFontSize => scale(26).clamp(19.0, 34.0);
  double get bodyFontSize      => scale(14).clamp(12.0, 18.0);
  double get smallFontSize     => scale(12).clamp(10.0, 15.0);
  double get buttonHeight      => scale(48).clamp(42.0, 60.0);
  double get iconSize          => scale(24).clamp(20.0, 30.0);

  // ─── About / splash ──────────────────────────────────────────────────────
  double get aboutLogoSize       => scale(75).clamp(60.0, 110.0);
  double get aboutTitleFontSize  => scale(26).clamp(20.0, 36.0);

  // ─── Standard EdgeInsets shortcuts ───────────────────────────────────────
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalSpacing * 0.6,
      );
  EdgeInsets get cardPadding => EdgeInsets.all(scale(16).clamp(12.0, 22.0));
}

/// Convenience extension so call-sites can do `context.r.scale(20)`.
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get r => ResponsiveHelper(this);
}
