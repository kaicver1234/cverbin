import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../models/app_language.dart';
import '../widgets/wave_loading.dart';
import 'privacy_welcome_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  AppLanguage? _selectedLanguage;
  bool _isChangingLanguage = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const Color _darkBg = Color(0xFF0A0A0A);

  static const List<_LanguageOption> _languages = [
    _LanguageOption(
      language: AppLanguage(name: 'English', code: 'en', flag: '🇺🇸', direction: 'ltr'),
      flag: '🇺🇸',
      displayName: 'English',
      subtitle: 'Continue in English',
      accentColor: Colors.white,
      bgColor: Color(0xFF181818),
    ),
    _LanguageOption(
      language: AppLanguage(name: 'پارسی', code: 'fa', flag: '🇮🇷', direction: 'rtl'),
      flag: '🇮🇷',
      displayName: 'پارسی',
      subtitle: 'ادامه به زبان پارسی',
      accentColor: Colors.white,
      bgColor: Color(0xFF181818),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
        setState(() => _selectedLanguage = lang);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_isChangingLanguage || !mounted) return;
    setState(() {
      _selectedLanguage = language;
      _isChangingLanguage = true;
    });

    try {
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      await lp.changeLanguage(language);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('language_selected', true);

      if (mounted) {
        await Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PrivacyWelcomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    } catch (_) {
      // If changing the language or persisting it failed, release the lock so
      // the user can tap again instead of being stuck on a spinning card.
      if (mounted) {
        setState(() => _isChangingLanguage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final hPad = (w * 0.064).clamp(16.0, 40.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _darkBg,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildHeader(w, h),
                  const Spacer(flex: 2),
                  _buildCards(w, h),
                  const Spacer(flex: 3),
                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double w, double h) {
    final iconBoxSize = (w * 0.192).clamp(56.0, 96.0);
    final iconSize    = iconBoxSize * 0.44;
    final titleSize   = (w * 0.069).clamp(20.0, 32.0);
    final subtitleSize = (w * 0.042).clamp(13.0, 20.0);

    return Column(
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF161616),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.language_rounded, size: iconSize, color: Colors.white.withValues(alpha: 0.8)),
        ),
        SizedBox(height: h * 0.025),
        Text(
          'Choose Language',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
            decoration: TextDecoration.none,
          ),
        ),
        SizedBox(height: h * 0.008),
        Text(
          'زبان خود را انتخاب کنید',
          style: TextStyle(
            fontSize: subtitleSize,
            color: Colors.white.withValues(alpha: 0.4),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildCards(double w, double h) {
    final gap = (h * 0.017).clamp(10.0, 20.0);
    return Column(
      children: _languages.asMap().entries.map((entry) {
        final i = entry.key;
        final opt = entry.value;
        final isSelected = _selectedLanguage == opt.language;
        return Padding(
          padding: EdgeInsets.only(bottom: i < _languages.length - 1 ? gap : 0),
          child: _LanguageCard(
            key: ValueKey(opt.language.code),
            option: opt,
            isSelected: isSelected,
            isLoading: _isChangingLanguage && isSelected,
            onTap: () => _selectLanguage(opt.language),
            screenW: w,
            screenH: h,
          ),
        );
      }).toList(),
    );
  }
}

class _LanguageOption {
  final AppLanguage language;
  final String flag;
  final String displayName;
  final String subtitle;
  final Color accentColor;
  final Color bgColor;

  const _LanguageOption({
    required this.language,
    required this.flag,
    required this.displayName,
    required this.subtitle,
    required this.accentColor,
    required this.bgColor,
  });
}

class _LanguageCard extends StatelessWidget {
  final _LanguageOption option;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final double screenW;
  final double screenH;

  const _LanguageCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
    required this.screenW,
    required this.screenH,
  });

  @override
  Widget build(BuildContext context) {
    final hPad       = (screenW * 0.053).clamp(16.0, 28.0);
    final vPad       = (screenH * 0.022).clamp(14.0, 26.0);
    final flagSize   = (screenW * 0.107).clamp(36.0, 52.0);
    final nameSize   = (screenW * 0.048).clamp(15.0, 22.0);
    final subSize    = (screenW * 0.032).clamp(11.0, 15.0);
    final checkSize  = (screenW * 0.064).clamp(22.0, 32.0);
    final radius     = (screenW * 0.048).clamp(14.0, 22.0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isSelected ? option.bgColor : const Color(0xFF111111),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Row(
          children: [
            Text(
              option.flag,
              style: TextStyle(fontSize: flagSize, decoration: TextDecoration.none),
            ),
            SizedBox(width: screenW * 0.042),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.displayName,
                    style: TextStyle(
                      fontSize: nameSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: screenH * 0.004),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: subSize,
                      color: Colors.white.withValues(alpha: 0.4),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: screenW * 0.032),
            isLoading
                ? const WaveLoading.small(color: Colors.white)
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: checkSize,
                    height: checkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: checkSize * 0.55,
                          )
                        : null,
                  ),
          ],
        ),
      ),
    );
  }
}
