import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import 'main_navigation_screen.dart';
import '../utils/app_localizations.dart';
import 'dart:ui';

class PrivacyWelcomeScreen extends StatefulWidget {
  const PrivacyWelcomeScreen({super.key});

  @override
  State<PrivacyWelcomeScreen> createState() => _PrivacyWelcomeScreenState();
}

class _PrivacyWelcomeScreenState extends State<PrivacyWelcomeScreen> 
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    
    if (!mounted) return;
    
    // Simply navigate - provider is already available in the widget tree
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: VPNGradientBackground(
            status: VPNBackgroundStatus.disconnected,
            child: Stack(
              children: [
                // Floating Particles (kept for visual effect)
                ...List.generate(15, (index) {
                  return Positioned(
                    left: (index * 73) % MediaQuery.of(context).size.width,
                    child: _FloatingParticle(
                      delay: Duration(milliseconds: index * 200),
                    ),
                  );
                }),
                
                // Content
                SafeArea(
                  child: Column(
                    children: [
                      // Skip Button
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: TextButton(
                            onPressed: _completeOnboarding,
                            child: Text(
                              AppLocalizations.of(context).translate('privacy_welcome.skip'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms),
                      
                      // Page Content
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (page) {
                            if (mounted) {
                              setState(() {
                                _currentPage = page;
                              });
                            }
                          },
                          children: [
                            _buildWelcomePage(),
                            _buildFeaturePage(),
                            _buildGetStartedPage(),
                          ],
                        ),
                      ),
                      
                      // Bottom Controls
                      _buildBottomControls(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo Animation with Glassmorphism
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.8),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 5,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ).animate()
              .scale(duration: 1000.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 600.ms)
              .then()
              .shimmer(duration: 2000.ms, color: Colors.white.withValues(alpha: 0.3)),
          
          const SizedBox(height: 50),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.welcome_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -1.5,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
          ).animate()
              .fadeIn(delay: 300.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 20),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.welcome_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.6,
              letterSpacing: 0.3,
            ),
          ).animate()
              .fadeIn(delay: 500.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 60),
          
          // Features Grid with Glassmorphism
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(Icons.lock_outline, AppLocalizations.of(context).translate('privacy_welcome.secure'), 700),
              _buildFeatureIcon(Icons.flash_on, AppLocalizations.of(context).translate('privacy_welcome.fast'), 850),
              _buildFeatureIcon(Icons.public, AppLocalizations.of(context).translate('privacy_welcome.global'), 1000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage() {
    final features = [
      {
        'icon': Icons.security,
        'title': AppLocalizations.of(context).translate('privacy_welcome.military_grade_encryption'),
        'desc': AppLocalizations.of(context).translate('privacy_welcome.military_grade_desc'),
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.speed,
        'title': AppLocalizations.of(context).translate('privacy_welcome.lightning_fast'),
        'desc': AppLocalizations.of(context).translate('privacy_welcome.lightning_fast_desc'),
        'color': const Color(0xFF6366F1),
      },
      {
        'icon': Icons.location_on,
        'title': AppLocalizations.of(context).translate('privacy_welcome.global_network'),
        'desc': AppLocalizations.of(context).translate('privacy_welcome.global_network_desc'),
        'color': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.no_encryption,
        'title': AppLocalizations.of(context).translate('privacy_welcome.no_logs'),
        'desc': AppLocalizations.of(context).translate('privacy_welcome.no_logs_desc'),
        'color': const Color(0xFFEC4899),
      },
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.why_choose_us'),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
          ).animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 40),
          
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (feature['color'] as Color).withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (feature['color'] as Color).withValues(alpha: 0.8),
                              (feature['color'] as Color).withValues(alpha: 0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (feature['color'] as Color).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              feature['desc'] as String,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate()
                .fadeIn(delay: Duration(milliseconds: 200 + index * 120), duration: 500.ms)
                .slideX(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
                .scale(begin: const Offset(0.95, 0.95), delay: Duration(milliseconds: 200 + index * 120));
          }),
        ],
      ),
    );
  }

  Widget _buildGetStartedPage() {
    return Padding(
      padding: const EdgeInsets.all(30), // Reduced padding for better fit on smaller screens
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Modern Success Animation (Optimized)
          RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse Animation (Outer Ring)
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                 .scale(duration: 2000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3))
                 .fadeOut(duration: 2000.ms, curve: Curves.easeOut),
                 
                // Inner Glow
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  ),
                ).animate()
                 .scale(duration: 1000.ms, curve: Curves.elasticOut, begin: const Offset(0, 0)),

                // Main Circle with Gradient
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF34D399), // Lighter Green
                        Color(0xFF059669), // Darker Green
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded, // Clean check icon without circle border
                    size: 56,
                    color: Colors.white,
                  ),
                ).animate()
                 .scale(duration: 800.ms, curve: Curves.elasticOut, begin: const Offset(0, 0))
                 .fadeIn(duration: 400.ms)
                 .then()
                 .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.4), delay: 1000.ms),
              ],
            ),
          ),
          
          const SizedBox(height: 50),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.ready_to_start'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32, // Slightly smaller for better fit
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ).animate()
              .fadeIn(delay: 300.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 16),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.one_tap_away'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ).animate()
              .fadeIn(delay: 500.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          
          const SizedBox(height: 60),
          
          // Get Started Button - Optimized (Removed BackdropFilter for performance)
          GestureDetector(
            onTap: _completeOnboarding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1), // Indigo
                    Color(0xFF8B5CF6), // Violet
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('privacy_welcome.get_started'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ).animate()
              .fadeIn(delay: 700.ms, duration: 600.ms)
              .scale(delay: 700.ms, begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
          
          const SizedBox(height: 30),
          
          // No Registration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).translate('privacy_welcome.no_registration'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate()
              .fadeIn(delay: 900.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, int delayMs) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delayMs), duration: 500.ms)
        .scale(delay: Duration(milliseconds: delayMs), begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button with Glassmorphism
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage > 0 ? _previousPage : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Page Indicators with Enhanced Design
          Row(
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: isActive ? 32 : 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        )
                      : null,
                  color: isActive ? null : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          
          // Next Button with Glassmorphism
          AnimatedOpacity(
            opacity: _currentPage < 2 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage < 2 ? _nextPage : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingParticle extends StatefulWidget {
  final Duration delay;
  
  const _FloatingParticle({required this.delay});
  
  @override
  State<_FloatingParticle> createState() => _FloatingParticleState();
}

class _FloatingParticleState extends State<_FloatingParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10 + (widget.delay.inMilliseconds % 5)),
    );
    
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize animation here where context is available
    _animation ??= Tween<double>(
      begin: MediaQuery.of(context).size.height + 50,
      end: -50,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_animation == null) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation!.value),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
