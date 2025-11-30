import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';
import '../utils/app_colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            child: SafeArea(
              child: Column(
                children: [
                  // Simple App Bar
                  _buildAppBar(context),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          
                          // App Icon & Name
                          _buildHeader(context),
                          
                          const SizedBox(height: 40),
                          
                          // Info Cards
                          _buildInfoSection(context),
                          
                          const SizedBox(height: 30),
                          
                          // Social Links
                          _buildSocialSection(context),
                          
                          const SizedBox(height: 40),
                          
                          // Footer
                          _buildFooter(context),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // App Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.bottomGradientConnected.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/apk.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // App Name
        Text(
          AppLocalizations.of(context).translate('about.app_name'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Version
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'v1.1.1',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      children: [
        // Description Card
        _buildCard(
          child: Text(
            AppLocalizations.of(context).translate('about.about_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Developer Card
        _buildCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context).translate('about.developed_with'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _heartAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartAnimation.value,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 16,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).translate('about.developer'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }

  Widget _buildSocialSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            AppLocalizations.of(context).translate('about.connect_with_me'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        // Telegram
        _buildSocialItem(
          context: context,
          icon: Icons.send,
          title: 'Telegram',
          subtitle: '@tiksar_vpn',
          color: const Color(0xFF0088CC),
          onTap: () => _launchUrl(context, 'https://t.me/tiksar_vpn'),
        ),
        
        const SizedBox(height: 8),
        
        // Instagram - Developer
        _buildSocialItem(
          context: context,
          icon: Icons.camera_alt_outlined,
          title: 'Instagram',
          subtitle: '@aboljahany',
          color: const Color(0xFFE1306C),
          onTap: () => _launchUrl(context, 'https://instagram.com/aboljahany'),
        ),
        
        const SizedBox(height: 8),
        
        // Instagram - Tiksar
        _buildSocialItem(
          context: context,
          icon: Icons.camera_alt_outlined,
          title: AppLocalizations.of(context).translate('about.tiksar_village_page'),
          subtitle: '@tiksaar_leyl_gilan',
          color: const Color(0xFF833AB4),
          onTap: () => _launchUrl(context, 'https://instagram.com/tiksaar_leyl_gilan'),
        ),
      ],
    );
  }

  Widget _buildSocialItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Text(
      AppLocalizations.of(context).translate('about.copyright'),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 11,
      ),
    );
  }
}
