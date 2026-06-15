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
  Orientation get orientation => _mq.orientation;
  bool get isLandscape => orientation == Orientation.landscape;

  // ─── Breakpoints (based on shortestSide for orientation-independence) ────
  bool get isTablet => shortestSide >= 600; // any tablet

  // Legacy aliases (kept so existing call sites keep working)
  bool get isSmallDevice  => width < 360;
  bool get isMediumDevice => width >= 360 && width < 400;

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

  // ─── Layout primitives ───────────────────────────────────────────────────
  double get horizontalPadding => scale(20).clamp(14.0, 40.0);
  double get verticalSpacing   => scale(20).clamp(12.0, 36.0);

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
  double get headerFontSize => scale(22).clamp(17.0, 30.0);
  double get timerFontSize  => scale(34).clamp(26.0, 46.0);

  // ─── Server cards ────────────────────────────────────────────────────────
  double get flagWidth         => scale(48).clamp(38.0, 60.0);
  double get flagHeight        => scale(36).clamp(28.0, 46.0);

  // Flag shown on the home screen server card (kept at a true 4:3 ratio so the
  // flag is never cropped/stretched the way a square BoxFit.cover would do).
  double get homeFlagWidth  => scale(40).clamp(34.0, 52.0);
  double get homeFlagHeight => scale(30).clamp(25.5, 39.0); // 4:3 of homeFlagWidth

  // ─── Tools (speedtest, host check, etc.) ─────────────────────────────────
  double get toolIconSize    => scale(22).clamp(18.0, 32.0);
  double get toolCardPadding => scale(14).clamp(10.0, 20.0);

  // ─── Bottom nav ──────────────────────────────────────────────────────────
  double get bottomNavHeight => (isLandscape ? scale(64) : scale(78)).clamp(58.0, 96.0);
  double get bottomNavButtonSize => scale(50).clamp(40.0, 64.0);

  // ─── Generic typography ──────────────────────────────────────────────────
  double get pageTitleFontSize => scale(26).clamp(19.0, 34.0);

  // ─── About / splash ──────────────────────────────────────────────────────
  double get aboutLogoSize       => scale(75).clamp(60.0, 110.0);
  double get aboutTitleFontSize  => scale(26).clamp(20.0, 36.0);
}

/// Convenience extension so call-sites can do `context.r.scale(20)`.
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get r => ResponsiveHelper(this);
}
