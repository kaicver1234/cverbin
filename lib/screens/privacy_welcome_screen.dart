import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/cyber_glow_background.dart';
import 'main_navigation_screen.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';

class PrivacyWelcomeScreen extends StatefulWidget {
  const PrivacyWelcomeScreen({super.key});

  @override
  State<PrivacyWelcomeScreen> createState() => _PrivacyWelcomeScreenState();
}

class _PrivacyWelcomeScreenState extends State<PrivacyWelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const _cyan   = Color(0xFF00D9FF);
  static const _green  = Color(0xFF00FFA3);
  static const _purple = Color(0xFFa78bfa);

  @override
  void initState() {
    super.initState();
    _fadeController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeController,  curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 2) {
      _pageController.animateToPage(_currentPage + 1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  void _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  bool get _isRtl {
    final lang = context.read<LanguageProvider>().currentLanguage.code;
    return lang == 'fa' || lang == 'ar';
  }

  TextStyle _heading(double size) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2, letterSpacing: -0.4, decoration: TextDecoration.none);
    return _isRtl ? base : GoogleFonts.poppins(textStyle: base);
  }

  TextStyle _body(double size, {Color? color}) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w400, color: color ?? Colors.white.withValues(alpha: 0.6), height: 1.65, decoration: TextDecoration.none);
    return _isRtl ? base : GoogleFonts.poppins(textStyle: base);
  }

  TextStyle _label(double size, Color color) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: color, decoration: TextDecoration.none);
    return _isRtl ? base : GoogleFonts.poppins(textStyle: base);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: CyberGlowBackground(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        children: [_buildWelcomePage(), _buildFeaturePage(), _buildGetStartedPage()],
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

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final r = ResponsiveHelper(context);
    final hPad = r.scale(24).clamp(16.0, 32.0);
    final vPad = r.scale(16).clamp(10.0, 22.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: _heading(r.scale(20).clamp(16.0, 26.0)),
              children: [
                const TextSpan(text: 'Tiksar'),
                TextSpan(text: 'VPN', style: TextStyle(color: _purple, decoration: TextDecoration.none)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _completeOnboarding,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.scale(16).clamp(10.0, 22.0),
                vertical:   r.scale(8).clamp(5.0, 12.0),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(r.scale(20).clamp(14.0, 26.0)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                AppLocalizations.of(context).translate('privacy_welcome.skip'),
                style: _label(r.scale(13).clamp(10.0, 16.0), Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page 1: Welcome ───────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    final tr = AppLocalizations.of(context);
    final r  = ResponsiveHelper(context);
    final hPad = r.scale(32).clamp(20.0, 44.0);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          children: [
            SizedBox(height: r.scale(40).clamp(24.0, 56.0)),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width:  r.scale(130).clamp(96.0, 164.0),
                height: r.scale(130).clamp(96.0, 164.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10b981), Color(0xFF06b6d4)],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFF10b981).withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 4)],
                ),
                child: Icon(Icons.shield_rounded, size: r.scale(60).clamp(44.0, 76.0), color: Colors.white),
              ),
            ),
            SizedBox(height: r.scale(48).clamp(28.0, 64.0)),
            Text(
              tr.translate('privacy_welcome.welcome_title'),
              textAlign: TextAlign.center,
              style: _heading(r.scale(30).clamp(22.0, 40.0)),
            ),
            SizedBox(height: r.scale(14).clamp(10.0, 20.0)),
            Text(
              tr.translate('privacy_welcome.welcome_subtitle'),
              textAlign: TextAlign.center,
              style: _body(r.scale(15).clamp(12.0, 18.0)),
            ),
            SizedBox(height: r.scale(44).clamp(28.0, 56.0)),
            _buildPillRow(r),
            SizedBox(height: r.scale(40).clamp(24.0, 52.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildPillRow(ResponsiveHelper r) {
    final tr = AppLocalizations.of(context);
    return Wrap(
      spacing: r.scale(10).clamp(6.0, 14.0),
      runSpacing: r.scale(8).clamp(6.0, 12.0),
      alignment: WrapAlignment.center,
      children: [
        _buildPill(r, Icons.lock_rounded,   tr.translate('privacy_welcome.secure'), const Color(0xFF10b981)),
        _buildPill(r, Icons.bolt_rounded,   tr.translate('privacy_welcome.fast'),   const Color(0xFF06b6d4)),
        _buildPill(r, Icons.public_rounded, tr.translate('privacy_welcome.global'), _purple),
      ],
    );
  }

  Widget _buildPill(ResponsiveHelper r, IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(12).clamp(8.0, 16.0),
        vertical:   r.scale(8).clamp(5.0, 11.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.scale(20).clamp(14.0, 26.0)),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: r.scale(15).clamp(12.0, 18.0)),
          SizedBox(width: r.scale(5).clamp(3.0, 8.0)),
          Text(label, style: _label(r.scale(11).clamp(9.0, 14.0), color)),
        ],
      ),
    );
  }

  // ─── Page 2: Features ──────────────────────────────────────────────────────

  Widget _buildFeaturePage() {
    final tr = AppLocalizations.of(context);
    final r  = ResponsiveHelper(context);
    final features = [
      {'icon': Icons.verified_user_rounded, 'title': tr.translate('privacy_welcome.military_grade_encryption'), 'desc': tr.translate('privacy_welcome.military_grade_desc'),  'color': const Color(0xFF10b981)},
      {'icon': Icons.speed_rounded,         'title': tr.translate('privacy_welcome.lightning_fast'),            'desc': tr.translate('privacy_welcome.lightning_fast_desc'), 'color': const Color(0xFF06b6d4)},
      {'icon': Icons.language_rounded,      'title': tr.translate('privacy_welcome.global_network'),            'desc': tr.translate('privacy_welcome.global_network_desc'), 'color': _purple},
      {'icon': Icons.visibility_off_rounded,'title': tr.translate('privacy_welcome.no_logs'),                   'desc': tr.translate('privacy_welcome.no_logs_desc'),         'color': const Color(0xFFf472b6)},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.scale(24).clamp(16.0, 32.0)),
        child: Column(
          children: [
            SizedBox(height: r.scale(32).clamp(20.0, 44.0)),
            Text(tr.translate('privacy_welcome.why_choose_us'), style: _heading(r.scale(26).clamp(20.0, 34.0)), textAlign: TextAlign.center),
            SizedBox(height: r.scale(8).clamp(5.0, 12.0)),
            Text(tr.translate('privacy_welcome.features_subtitle'), style: _body(r.scale(14).clamp(11.0, 17.0)), textAlign: TextAlign.center),
            SizedBox(height: r.scale(28).clamp(18.0, 36.0)),
            ...features.asMap().entries.map((entry) {
              final index   = entry.key;
              final feature = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildFeatureCard(
                      r:     r,
                      icon:  feature['icon']  as IconData,
                      title: feature['title'] as String,
                      desc:  feature['desc']  as String,
                      color: feature['color'] as Color,
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: r.scale(24).clamp(16.0, 32.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required ResponsiveHelper r, required IconData icon, required String title, required String desc, required Color color}) {
    final iconBoxSize = r.scale(48).clamp(38.0, 60.0);
    return Container(
      margin: EdgeInsets.only(bottom: r.scale(12).clamp(8.0, 16.0)),
      padding: EdgeInsets.all(r.scale(16).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(r.scale(18).clamp(12.0, 24.0)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.scale(13).clamp(9.0, 17.0)),
            ),
            child: Icon(icon, color: color, size: r.scale(24).clamp(18.0, 30.0)),
          ),
          SizedBox(width: r.scale(14).clamp(10.0, 18.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _label(r.scale(14).clamp(11.0, 17.0), Colors.white)),
                SizedBox(height: r.scale(3).clamp(2.0, 5.0)),
                Text(desc, style: _body(r.scale(12).clamp(10.0, 14.0))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page 3: Get Started ───────────────────────────────────────────────────

  Widget _buildGetStartedPage() {
    final tr = AppLocalizations.of(context);
    final r  = ResponsiveHelper(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.scale(32).clamp(20.0, 44.0)),
        child: Column(
          children: [
            SizedBox(height: r.scale(60).clamp(36.0, 80.0)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  width:  r.scale(120).clamp(88.0, 152.0),
                  height: r.scale(120).clamp(88.0, 152.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10b981), Color(0xFF059669)],
                    ),
                    boxShadow: [BoxShadow(color: const Color(0xFF10b981).withValues(alpha: 0.4), blurRadius: 36, spreadRadius: 4)],
                  ),
                  child: Icon(Icons.check_rounded, size: r.scale(52).clamp(38.0, 66.0), color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: r.scale(48).clamp(28.0, 64.0)),
            Text(
              tr.translate('privacy_welcome.ready_to_start'),
              textAlign: TextAlign.center,
              style: _heading(r.scale(26).clamp(20.0, 34.0)),
            ),
            SizedBox(height: r.scale(14).clamp(10.0, 20.0)),
            Text(
              tr.translate('privacy_welcome.one_tap_away'),
              textAlign: TextAlign.center,
              style: _body(r.scale(15).clamp(12.0, 18.0)),
            ),
            SizedBox(height: r.scale(48).clamp(28.0, 64.0)),
            GestureDetector(
              onTap: _completeOnboarding,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.scale(18).clamp(13.0, 24.0)),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F14),
                  borderRadius: BorderRadius.circular(r.scale(16).clamp(12.0, 20.0)),
                  border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr.translate('privacy_welcome.get_started'),
                      style: _label(r.scale(16).clamp(13.0, 20.0), _green),
                    ),
                    SizedBox(width: r.scale(8).clamp(5.0, 12.0)),
                    Icon(Icons.arrow_forward_rounded, color: _green, size: r.scale(20).clamp(16.0, 24.0)),
                  ],
                ),
              ),
            ),
            SizedBox(height: r.scale(16).clamp(10.0, 22.0)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.scale(14).clamp(10.0, 20.0),
                vertical:   r.scale(9).clamp(6.0, 13.0),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(r.scale(20).clamp(14.0, 26.0)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(r.scale(3).clamp(2.0, 5.0)),
                    decoration: BoxDecoration(color: const Color(0xFF10b981).withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: Icon(Icons.check, color: const Color(0xFF10b981), size: r.scale(12).clamp(9.0, 15.0)),
                  ),
                  SizedBox(width: r.scale(7).clamp(5.0, 10.0)),
                  Text(tr.translate('privacy_welcome.no_registration'), style: _body(r.scale(12).clamp(10.0, 14.0), color: Colors.white.withValues(alpha: 0.55))),
                ],
              ),
            ),
            SizedBox(height: r.scale(40).clamp(24.0, 52.0)),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final r       = ResponsiveHelper(context);
    final btnSize = r.scale(48).clamp(40.0, 60.0);
    final dotH    = r.scale(8).clamp(6.0, 10.0);
    final dotActiveW = r.scale(28).clamp(20.0, 36.0);
    final dotInactiveW = r.scale(8).clamp(6.0, 10.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.horizontalPadding,
        r.scale(16).clamp(10.0, 22.0),
        r.horizontalPadding,
        r.scale(24).clamp(16.0, 32.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _currentPage > 0 ? _previousPage : null,
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1520),
                  borderRadius: BorderRadius.circular(r.scale(14).clamp(10.0, 18.0)),
                  border: Border.all(color: _cyan.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.arrow_back_rounded, color: _cyan.withValues(alpha: 0.8), size: r.scale(22).clamp(16.0, 28.0)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(horizontal: r.scale(4).clamp(3.0, 6.0)),
                width:  isActive ? dotActiveW : dotInactiveW,
                height: dotH,
                decoration: BoxDecoration(
                  gradient: isActive ? const LinearGradient(colors: [_cyan, _green]) : null,
                  color: isActive ? null : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(dotH / 2),
                ),
              );
            }),
          ),
          AnimatedOpacity(
            opacity: _currentPage < 2 ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _currentPage < 2 ? _nextPage : null,
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F14),
                  borderRadius: BorderRadius.circular(r.scale(14).clamp(10.0, 18.0)),
                  border: Border.all(color: _green.withValues(alpha: 0.35)),
                  boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.arrow_forward_rounded, color: _green, size: r.scale(22).clamp(16.0, 28.0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
