import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/modern_animated_background.dart';
import '../utils/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> 
    with TickerProviderStateMixin {
  late AnimationController _heartController;
  late AnimationController _floatController;
  late AnimationController _backgroundController;
  
  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }
  
  @override
  void dispose() {
    _heartController.dispose();
    _floatController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      // For Telegram links, try app first, then fallback to web
      if (url.startsWith('https://t.me/')) {
        // First try: Open in Telegram app (if installed)
        bool launched = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          // Second try: Let user choose from multiple Telegram apps or web browser
          launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault, // This shows app chooser on Android
          );
          
          if (!launched) {
            // Final fallback: Open in web browser
            if (mounted) {
              _showSnackBar('Opening in browser...', Colors.orange);
            }
            await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
          }
        }
      } else {
        // For other URLs (Instagram, etc.), use external application
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            _showSnackBar('Could not open $url', Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error opening link: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: Scaffold(
            body: ModernAnimatedBackground(
              isConnected: false,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // App Bar
                      _buildAppBar(context),
                      
                      // Logo Section
                      _buildLogoSection(),
                      
                      // App Info
                      _buildAppInfo(),
                      
                      // Developer Info
                      _buildDeveloperCard(),
                      
                      // Social Media Buttons
                      _buildSocialButtons(),
                      
                      // Footer
                      _buildFooter(),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ).animate().fadeIn().slideX(),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('about.title'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn().slideX(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatController.value * 10 - 5),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
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
                    size: 60,
                    color: Colors.white,
                  ),
                ).animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut)
                    .fadeIn(),
                
                const SizedBox(height: 20),
                
                Text(
                  'Tiksar VPN',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ).animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.3, end: 0),
                
                const SizedBox(height: 8),
                
                Text(
                  'Version 1.1.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1,
                  ),
                ).animate()
                    .fadeIn(delay: 400.ms),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('about.tagline'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).translate('about.about_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildDeveloperCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.2),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Developed with',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _heartController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _heartController.value * 0.2,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 24,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('about.developer'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).scale();
  }

  Widget _buildSocialButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('about.connect_with_me'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: 700.ms),
          
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(
                icon: Icons.telegram,
                label: 'Telegram',
                gradient: const [Color(0xFF0088CC), Color(0xFF00A0E3)],
                onTap: () => _launchUrl('https://t.me/tiksar_vpn'),
                delay: 800,
              ),
              const SizedBox(width: 16),
              _buildSocialButton(
                icon: Icons.camera_alt,
                label: 'Instagram',
                gradient: const [Color(0xFFE1306C), Color(0xFFF56040), Color(0xFFFCAF45)],
                onTap: () => _launchUrl('https://instagram.com/aboljahany'),
                delay: 900,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildOfficialPageButton(
            icon: Icons.camera_alt,
            label: AppLocalizations.of(context).translate('about.tiksar_village_page'),
            gradient: const [
              Color(0xFFFCAF45),
              Color(0xFFF77737),
              Color(0xFFE1306C),
              Color(0xFFC13584),
              Color(0xFF833AB4),
            ],
            onTap: () => _launchUrl('https://instagram.com/tiksaar_leyl_gilan'),
            delay: 1000,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .scale(delay: Duration(milliseconds: delay));
  }

  Widget _buildOfficialPageButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .scale(delay: Duration(milliseconds: delay));
  }


  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).translate('about.copyright'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1500.ms);
  }
}
