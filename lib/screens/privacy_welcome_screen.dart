import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import 'main_navigation_screen.dart';

// Match the rest of the app's minimal black/white theme.
const _kBg            = Color(0xFF000000);
const _kSurface       = Color(0xFF0F0F0F);
const _kSurfaceHigh   = Color(0xFF161616);
const _kBorder        = Color(0xFF1F1F1F);
const _kBorderStrong  = Color(0xFF2A2A2A);
const _kAccent        = Color(0xFFA78BFA); // brand "VPN" purple, kept subtle

class PrivacyWelcomeScreen extends StatefulWidget {
  const PrivacyWelcomeScreen({super.key});

  @override
  State<PrivacyWelcomeScreen> createState() => _PrivacyWelcomeScreenState();
}

class _PrivacyWelcomeScreenState extends State<PrivacyWelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 3;
  bool _completing = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _kBg,
    ));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _isRtl {
    final code = context.read<LanguageProvider>().currentLanguage.code;
    return code == 'fa' || code == 'ar';
  }

  TextStyle _heading(double size) => _headingStyle(context, size);

  void _onNext() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pageCount - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onPrev() {
    if (_currentPage == 0) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      _currentPage - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_completing) return;
    _completing = true;
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        return Directionality(
          textDirection: lang.textDirection,
          child: Scaffold(
            backgroundColor: _kBg,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const ClampingScrollPhysics(),
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            children: const [
                              _WelcomePage(),
                              _FeaturesPage(),
                              _GetStartedPage(),
                            ],
                          ),
                        ),
                        _buildBottomNav(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final tr = AppLocalizations.of(context);
    final r = ResponsiveHelper(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.scale(20).clamp(14.0, 28.0),
        r.scale(16).clamp(10.0, 22.0),
        r.scale(20).clamp(14.0, 28.0),
        r.scale(8).clamp(6.0, 14.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: _heading(r.scale(19).clamp(15.0, 24.0)),
              children: const [
                TextSpan(text: 'Tiksar'),
                TextSpan(
                  text: 'VPN',
                  style: TextStyle(
                    color: _kAccent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (_currentPage < _pageCount - 1)
            _SkipButton(
              label: tr.translate('privacy_welcome.skip'),
              onTap: _completeOnboarding,
              isRtl: _isRtl,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final r = ResponsiveHelper(context);
    final isLast = _currentPage == _pageCount - 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.horizontalPadding,
        r.scale(12).clamp(8.0, 18.0),
        r.horizontalPadding,
        r.scale(20).clamp(14.0, 28.0),
      ),
      child: Column(
        children: [
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageCount, (i) {
              final active = _currentPage == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(
                  horizontal: r.scale(4).clamp(3.0, 6.0),
                ),
                width: active
                    ? r.scale(22).clamp(16.0, 28.0)
                    : r.scale(7).clamp(5.0, 9.0),
                height: r.scale(7).clamp(5.0, 9.0),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          SizedBox(height: r.scale(18).clamp(12.0, 24.0)),
          Row(
            children: [
              if (_currentPage > 0)
                _NavSquareButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: _onPrev,
                  isRtl: _isRtl,
                )
              else
                SizedBox(width: r.scale(48).clamp(40.0, 60.0)),
              SizedBox(width: r.scale(12).clamp(8.0, 16.0)),
              Expanded(
                child: _PrimaryButton(
                  label: isLast
                      ? AppLocalizations.of(context)
                          .translate('privacy_welcome.get_started')
                      : _isRtl ? 'ادامه' : 'Continue',
                  onTap: _onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Page 1: Welcome ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final r = ResponsiveHelper(context);
    final hPad = r.scale(28).clamp(18.0, 40.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          SizedBox(height: r.scale(36).clamp(20.0, 56.0)),
          _HeroIcon(
            icon: Icons.shield_rounded,
            size: r.scale(120).clamp(92.0, 156.0),
            iconSize: r.scale(54).clamp(40.0, 70.0),
          ),
          SizedBox(height: r.scale(40).clamp(24.0, 56.0)),
          Text(
            tr.translate('privacy_welcome.welcome_title'),
            textAlign: TextAlign.center,
            style: _headingStyle(
              context,
              r.scale(28).clamp(20.0, 36.0),
            ),
          ),
          SizedBox(height: r.scale(12).clamp(8.0, 18.0)),
          Text(
            tr.translate('privacy_welcome.welcome_subtitle'),
            textAlign: TextAlign.center,
            style: _bodyStyle(
              context,
              r.scale(14.5).clamp(12.0, 17.0),
            ),
          ),
          SizedBox(height: r.scale(32).clamp(20.0, 44.0)),
          Wrap(
            spacing: r.scale(8).clamp(6.0, 12.0),
            runSpacing: r.scale(8).clamp(6.0, 10.0),
            alignment: WrapAlignment.center,
            children: [
              _Pill(icon: Icons.lock_rounded,   label: tr.translate('privacy_welcome.secure')),
              _Pill(icon: Icons.bolt_rounded,   label: tr.translate('privacy_welcome.fast')),
              _Pill(icon: Icons.public_rounded, label: tr.translate('privacy_welcome.global')),
            ],
          ),
          SizedBox(height: r.scale(32).clamp(20.0, 44.0)),
        ],
      ),
    );
  }
}

// ─── Page 2: Features ────────────────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final r = ResponsiveHelper(context);
    final hPad = r.scale(24).clamp(16.0, 32.0);

    final items = <_Feature>[
      _Feature(Icons.verified_user_rounded,
          tr.translate('privacy_welcome.military_grade_encryption'),
          tr.translate('privacy_welcome.military_grade_desc')),
      _Feature(Icons.bolt_rounded,
          tr.translate('privacy_welcome.lightning_fast'),
          tr.translate('privacy_welcome.lightning_fast_desc')),
      _Feature(Icons.public_rounded,
          tr.translate('privacy_welcome.global_network'),
          tr.translate('privacy_welcome.global_network_desc')),
      _Feature(Icons.visibility_off_rounded,
          tr.translate('privacy_welcome.no_logs'),
          tr.translate('privacy_welcome.no_logs_desc')),
    ];

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, r.scale(20).clamp(12.0, 32.0), hPad, r.scale(16).clamp(10.0, 22.0)),
      children: [
        Text(
          tr.translate('privacy_welcome.why_choose_us'),
          textAlign: TextAlign.center,
          style: _headingStyle(
            context,
            r.scale(24).clamp(18.0, 30.0),
          ),
        ),
        SizedBox(height: r.scale(8).clamp(6.0, 12.0)),
        Text(
          tr.translate('privacy_welcome.features_subtitle'),
          textAlign: TextAlign.center,
          style: _bodyStyle(
            context,
            r.scale(13.5).clamp(11.0, 16.0),
          ),
        ),
        SizedBox(height: r.scale(24).clamp(14.0, 32.0)),
        for (final f in items) ...[
          _FeatureCard(feature: f),
          SizedBox(height: r.scale(10).clamp(8.0, 14.0)),
        ],
      ],
    );
  }
}

// ─── Page 3: Get Started ─────────────────────────────────────────────────────

class _GetStartedPage extends StatelessWidget {
  const _GetStartedPage();

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final r = ResponsiveHelper(context);
    final hPad = r.scale(28).clamp(18.0, 40.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          SizedBox(height: r.scale(48).clamp(28.0, 72.0)),
          _HeroIcon(
            icon: Icons.check_rounded,
            size: r.scale(116).clamp(88.0, 148.0),
            iconSize: r.scale(54).clamp(40.0, 68.0),
          ),
          SizedBox(height: r.scale(40).clamp(24.0, 56.0)),
          Text(
            tr.translate('privacy_welcome.ready_to_start'),
            textAlign: TextAlign.center,
            style: _headingStyle(
              context,
              r.scale(26).clamp(20.0, 32.0),
            ),
          ),
          SizedBox(height: r.scale(12).clamp(8.0, 18.0)),
          Text(
            tr.translate('privacy_welcome.one_tap_away'),
            textAlign: TextAlign.center,
            style: _bodyStyle(
              context,
              r.scale(14.5).clamp(12.0, 17.0),
            ),
          ),
          SizedBox(height: r.scale(32).clamp(20.0, 44.0)),
          _NoRegistrationChip(
            label: tr.translate('privacy_welcome.no_registration'),
          ),
          SizedBox(height: r.scale(28).clamp(18.0, 40.0)),
        ],
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const _HeroIcon({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kSurfaceHigh,
        border: Border.all(color: _kBorderStrong, width: 1.2),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(12).clamp(9.0, 16.0),
        vertical: r.scale(7).clamp(5.0, 10.0),
      ),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: r.scale(14).clamp(11.0, 17.0),
          ),
          SizedBox(width: r.scale(6).clamp(4.0, 9.0)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: r.scale(12).clamp(10.0, 14.0),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String desc;
  const _Feature(this.icon, this.title, this.desc);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final iconBox = r.scale(44).clamp(36.0, 56.0);
    return Container(
      padding: EdgeInsets.all(r.scale(14).clamp(11.0, 18.0)),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(r.scale(16).clamp(12.0, 22.0)),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(r.scale(12).clamp(9.0, 16.0)),
            ),
            child: Icon(
              feature.icon,
              color: Colors.white.withValues(alpha: 0.9),
              size: r.scale(22).clamp(17.0, 28.0),
            ),
          ),
          SizedBox(width: r.scale(13).clamp(10.0, 16.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.scale(14).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: r.scale(3).clamp(2.0, 5.0)),
                Text(
                  feature.desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: r.scale(12).clamp(10.0, 14.0),
                    height: 1.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRegistrationChip extends StatelessWidget {
  final String label;
  const _NoRegistrationChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14).clamp(10.0, 18.0),
        vertical: r.scale(9).clamp(6.0, 12.0),
      ),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: r.scale(11).clamp(9.0, 13.0),
              color: Colors.white,
            ),
          ),
          SizedBox(width: r.scale(8).clamp(6.0, 10.0)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: r.scale(12).clamp(10.0, 14.0),
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isRtl;
  const _SkipButton({required this.label, required this.onTap, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14).clamp(10.0, 18.0),
            vertical: r.scale(7).clamp(5.0, 10.0),
          ),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: r.scale(12.5).clamp(10.0, 15.0),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isRtl;
  const _NavSquareButton({
    required this.icon,
    required this.onTap,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final size = r.scale(48).clamp(40.0, 60.0);
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(r.scale(14).clamp(11.0, 18.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(14).clamp(11.0, 18.0)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.scale(14).clamp(11.0, 18.0)),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(
            // Mirror back arrow in RTL so it visually points to the previous page.
            isRtl ? Icons.arrow_forward_rounded : icon,
            color: Colors.white.withValues(alpha: 0.85),
            size: r.scale(20).clamp(16.0, 26.0),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final h = r.scale(48).clamp(42.0, 58.0);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r.scale(14).clamp(11.0, 18.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(14).clamp(11.0, 18.0)),
        child: SizedBox(
          height: h,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: r.scale(14.5).clamp(12.0, 17.0),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Static helpers exposed so subpage widgets can share the parent's text styles
// without having to thread them through every constructor.
TextStyle _headingStyle(BuildContext context, double size) {
  final code = context.read<LanguageProvider>().currentLanguage.code;
  final isRtl = code == 'fa' || code == 'ar';
  final base = TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.25,
    letterSpacing: -0.3,
    decoration: TextDecoration.none,
  );
  return isRtl ? base : GoogleFonts.poppins(textStyle: base);
}

TextStyle _bodyStyle(BuildContext context, double size, {Color? color}) {
  final code = context.read<LanguageProvider>().currentLanguage.code;
  final isRtl = code == 'fa' || code == 'ar';
  final base = TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color ?? Colors.white.withValues(alpha: 0.55),
    height: 1.6,
    decoration: TextDecoration.none,
  );
  return isRtl ? base : GoogleFonts.poppins(textStyle: base);
}
