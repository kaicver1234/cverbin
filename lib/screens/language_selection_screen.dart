import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../models/app_language.dart';
import 'privacy_welcome_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> 
    with SingleTickerProviderStateMixin {
  AppLanguage? _selectedLanguage;
  late AnimationController _contentController;
  bool _isChangingLanguage = false;

  final List<Map<String, dynamic>> languages = [
    {
      'language': const AppLanguage(name: 'English', code: 'en', flag: '🇬🇧', direction: 'ltr'),
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇬🇧',
      'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    },
    {
      'language': const AppLanguage(name: 'فارسی', code: 'fa', flag: '🇮🇷', direction: 'rtl'),
      'name': 'Persian',
      'nativeName': 'فارسی',
      'flag': '🇮🇷',
      'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    // Get current language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = Provider.of<LanguageProvider>(
        context, 
        listen: false
      );
      setState(() {
        _selectedLanguage = languageProvider.currentLanguage;
      });
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_isChangingLanguage) return;
    
    if (!mounted) return;
    
    setState(() {
      _selectedLanguage = language;
      _isChangingLanguage = true;
    });
    
    // Apply language change
    final languageProvider = Provider.of<LanguageProvider>(
      context, 
      listen: false
    );
    await languageProvider.changeLanguage(language);
    
    // Save selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    
    // Navigate to welcome screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              const PrivacyWelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPNGradientBackground(
      status: VPNBackgroundStatus.disconnected,
      child: Stack(
        children: [
          // Floating Orbs (kept for visual effect)
          ...List.generate(5, (index) {
            return _FloatingOrb(
              delay: Duration(milliseconds: index * 400),
              size: 150.0 + (index * 30),
              color: [
                const Color(0xFF6366F1),
                const Color(0xFF8B5CF6),
                const Color(0xFF10B981),
                const Color(0xFFF59E0B),
                const Color(0xFFEC4899),
              ][index],
            );
          }),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    // Title
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.language,
                        size: 50,
                        color: Colors.white,
                      ),
                    ).animate()
                        .scale(duration: 800.ms, curve: Curves.elasticOut)
                        .fadeIn(),
                    
                    const SizedBox(height: 30),
                    
                    Text(
                      'Choose Your Language',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ).animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.3, end: 0),
                    
                    const SizedBox(height: 10),
                    
                    Text(
                      'Select your preferred language',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ).animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.3, end: 0),
                    
                    const SizedBox(height: 40),
                    
                    // Language Options
                    ...languages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final lang = entry.value;
                      final isSelected = _selectedLanguage == lang['language'];
                      
                      return GestureDetector(
                        onTap: () => _selectLanguage(lang['language']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: lang['gradient'])
                                : null,
                            color: isSelected
                                ? null
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (lang['gradient'] as List<Color>)[0]
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                : [],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Row(
                            children: [
                              Text(
                                lang['flag'],
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lang['nativeName'],
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ).animate()
                                    .scale(duration: 300.ms, curve: Curves.elasticOut),
                            ],
                          ),
                        ),
                      ).animate()
                          .fadeIn(delay: Duration(milliseconds: 400 + index * 100))
                          .slideX(begin: 0.3, end: 0);
                    }),
                    
                    const SizedBox(height: 40),
                    
                    if (_selectedLanguage != null)
                      GestureDetector(
                        onTap: _isChangingLanguage 
                            ? null 
                            : () => _selectLanguage(_selectedLanguage!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _isChangingLanguage
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'CONTINUE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ).animate()
                          .fadeIn(delay: 1000.ms)
                          .scale(delay: 1000.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingOrb extends StatefulWidget {
  final Duration delay;
  final double size;
  final Color color;
  
  const _FloatingOrb({
    required this.delay,
    required this.size,
    required this.color,
  });
  
  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20 + (widget.delay.inMilliseconds % 10)),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: -widget.size,
      end: MediaQuery.of(context).size.height + widget.size,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: (widget.size * 2) % MediaQuery.of(context).size.width,
          top: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withValues(alpha: 0.3),
                  widget.color.withValues(alpha: 0.1),
                  widget.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
