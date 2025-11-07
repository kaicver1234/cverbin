import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import 'main_navigation_screen.dart';
import '../utils/app_localizations.dart';

class PrivacyWelcomeScreen extends StatefulWidget {
  const PrivacyWelcomeScreen({Key? key}) : super(key: key);

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
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
              const MainNavigationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
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
                                color: Colors.white.withOpacity(0.7),
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
          // Logo Animation
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 70,
              color: Colors.white,
            ),
          ).animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .fadeIn(),
          
          const SizedBox(height: 40),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.welcome_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -1,
            ),
          ).animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 20),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.welcome_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ).animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 60),
          
          // Features Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(Icons.lock_outline, AppLocalizations.of(context).translate('privacy_welcome.secure'), 600),
              _buildFeatureIcon(Icons.flash_on, AppLocalizations.of(context).translate('privacy_welcome.fast'), 700),
              _buildFeatureIcon(Icons.public, AppLocalizations.of(context).translate('privacy_welcome.global'), 800),
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
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.why_choose_us'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn().slideY(begin: -0.3, end: 0),
          
          const SizedBox(height: 40),
          
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (feature['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature['desc'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate()
                .fadeIn(delay: Duration(milliseconds: 200 + index * 100))
                .slideX(begin: 0.3, end: 0);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildGetStartedPage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
            ),
            child: const Icon(
              Icons.check,
              size: 60,
              color: Colors.white,
            ),
          ).animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .fadeIn(),
          
          const SizedBox(height: 40),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.ready_to_start'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ).animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 20),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.one_tap_away'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ).animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 60),
          
          // Get Started Button
          GestureDetector(
            onTap: _completeOnboarding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                AppLocalizations.of(context).translate('privacy_welcome.get_started'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ).animate()
              .fadeIn(delay: 600.ms)
              .scale(delay: 600.ms),
          
          const SizedBox(height: 40),
          
          Text(
            AppLocalizations.of(context).translate('privacy_welcome.no_registration'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, int delayMs) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .scale(delay: Duration(milliseconds: delayMs));
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage > 0 ? _previousPage : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Page Indicators
          Row(
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFF6366F1)
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          
          // Next Button
          AnimatedOpacity(
            opacity: _currentPage < 2 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage < 2 ? _nextPage : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
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
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10 + (widget.delay.inMilliseconds % 5)),
    )..repeat();
    
    _animation = Tween<double>(
      begin: MediaQuery.of(context).size.height + 50,
      end: -50,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
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
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
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
