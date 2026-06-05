import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../widgets/modern_glass_card.dart';
import '../widgets/cyber_glow_background.dart';
import '../widgets/app_background.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _heartController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;
  late Animation<double> _heartAnimation;
  late Animation<double> _glowAnimation;

  // Wallet addresses
  final Map<String, String> _wallets = {
    'Ethereum (ETH)': '0xae963BF541F90Dd687419C8c442c7d6b85F60d55',
    'Tether (USDT-TRC20)': 'TXd74xCtRAvpZaHsxEYF4WdoHQBLQwo3ob',
    'Tron (TRX)': 'TXd74xCtRAvpZaHsxEYF4WdoHQBLQwo3ob',
    'Toncoin (TON)': 'UQBRCtsfiqEVVdjO9lejWdcq1OumwL2dvht2P0G7aTlXo8mQ',
  };

  // Total animated items: icon, title, description, N wallet cards, trust button, thank-you card
  int get _animatedItemCount => 3 + _wallets.length + 2;

  List<List<double>> _buildIntervals(int count) {
    // Distribute staggered intervals across [0, 1]
    final intervals = <List<double>>[];
    const double itemDuration = 0.45; // each item's animation span
    final double maxStart = (1.0 - itemDuration).clamp(0.0, 1.0);
    for (int i = 0; i < count; i++) {
      final double start = count <= 1 ? 0.0 : (i / (count - 1)) * maxStart;
      final double end = (start + itemDuration).clamp(0.0, 1.0);
      intervals.add([start, end]);
    }
    return intervals;
  }

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final intervals = _buildIntervals(_animatedItemCount);

    _fadeAnims = intervals.map((iv) => CurvedAnimation(
      parent: _controller,
      curve: Interval(iv[0], iv[1], curve: Curves.easeOut),
    )).toList();

    _slideAnims = intervals.map((iv) => Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(iv[0], iv[1], curve: Curves.easeOutCubic),
    ))).toList();

    // Heart animation
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _heartAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.15), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(_heartController);

    // Glow animation for icon
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartController.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(position: _slideAnims[index], child: child),
    );
  }

  Future<void> _copyToClipboard(String text, String cryptoName) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('donation.address_copied')
                      .replaceAll('{crypto}', cryptoName),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00FFA3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openTrustWallet() async {
    final Uri trustWalletUri = Uri.parse('trust://');
    
    try {
      final bool launched = await launchUrl(
        trustWalletUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && mounted) {
        final Uri storeUri = Uri.parse(
          Theme.of(context).platform == TargetPlatform.iOS
              ? 'https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409'
              : 'https://play.google.com/store/apps/details?id=com.wallet.crypto.trustapp',
        );
        
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('donation.wallet_open_error'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AppBackground(
            useSecondaryBackground: true,
            child: CyberGlowBackground(
              child: SafeArea(
                child: ResponsivePageWrapper(
                  child: Column(
                  children: [
                    // Header
                    _buildHeader(context, responsive, languageProvider),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
                        child: Column(
                          children: [
                            SizedBox(height: responsive.scale(32)),

                            // Icon with animated glow
                            _animated(0, _buildDonationIcon(responsive)),

                            SizedBox(height: responsive.scale(28)),

                            // Title
                            _animated(1, Text(
                              AppLocalizations.of(context).translate('donation.title'),
                              style: GoogleFonts.poppins(
                                fontSize: responsive.scale(28).clamp(24.0, 34.0),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            )),

                            SizedBox(height: responsive.scale(12)),

                            // Description
                            _animated(2, Padding(
                              padding: EdgeInsets.symmetric(horizontal: responsive.scale(8)),
                              child: Text(
                                AppLocalizations.of(context).translate('donation.description'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: responsive.scale(14).clamp(12.0, 16.0),
                                  height: 1.8,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )),

                            SizedBox(height: responsive.scale(36)),

                            // Wallet addresses
                            ..._wallets.entries.map((entry) {
                              final index = _wallets.keys.toList().indexOf(entry.key);
                              return _animated(
                                index + 3,
                                Padding(
                                  padding: EdgeInsets.only(bottom: responsive.scale(14)),
                                  child: _buildWalletCard(
                                    cryptoName: entry.key,
                                    address: entry.value,
                                    responsive: responsive,
                                  ),
                                ),
                              );
                            }),

                            SizedBox(height: responsive.scale(20)),

                            // Open Trust Wallet Button
                            _animated(
                              _wallets.length + 3,
                              _buildTrustWalletButton(responsive),
                            ),

                            SizedBox(height: responsive.scale(28)),

                            // Thank you message
                            _animated(
                              _wallets.length + 4,
                              _buildThankYouCard(responsive),
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildHeader(BuildContext context, ResponsiveHelper responsive, LanguageProvider languageProvider) {
    return Padding(
      padding: EdgeInsets.all(responsive.horizontalPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(responsive.scale(12)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                languageProvider.isRtl ? Icons.arrow_forward : Icons.arrow_back,
                color: Colors.white,
                size: responsive.scale(20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('donation.header'),
              style: GoogleFonts.poppins(
                fontSize: responsive.scale(19).clamp(17.0, 23.0),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationIcon(ResponsiveHelper responsive) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: responsive.scale(110),
          height: responsive.scale(110),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(
                  const Color(0xFFFFD700).withValues(alpha: 0.4),
                  const Color(0xFFFFD700).withValues(alpha: 0.6),
                  _glowAnimation.value,
                )!,
                Colors.transparent,
              ],
              stops: const [0.3, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  const Color(0xFFFFD700).withValues(alpha: 0.3),
                  const Color(0xFFFFD700).withValues(alpha: 0.5),
                  _glowAnimation.value,
                )!,
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.25),
                  const Color(0xFFFFA500).withValues(alpha: 0.25),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ScaleTransition(
              scale: _heartAnimation,
              child: Icon(
                Icons.volunteer_activism_rounded,
                color: const Color(0xFFFFD700),
                size: responsive.scale(52),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletCard({
    required String cryptoName,
    required String address,
    required ResponsiveHelper responsive,
  }) {
    return ModernGlassCard(
      padding: EdgeInsets.all(responsive.scale(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crypto name with icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(10)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCryptoColor(cryptoName).withValues(alpha: 0.2),
                      _getCryptoColor(cryptoName).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getCryptoColor(cryptoName).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getCryptoColor(cryptoName).withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  _getCryptoIcon(cryptoName),
                  color: _getCryptoColor(cryptoName),
                  size: responsive.scale(22),
                ),
              ),
              SizedBox(width: responsive.scale(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cryptoName.split(' ').first,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.scale(16).clamp(14.0, 18.0),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      cryptoName.contains('(') 
                          ? cryptoName.substring(cryptoName.indexOf('('))
                          : '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: responsive.scale(12).clamp(10.0, 14.0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: responsive.scale(14)),
          
          // Address with copy button
          Container(
            padding: EdgeInsets.all(responsive.scale(14)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: responsive.scale(12).clamp(10.0, 14.0),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: responsive.scale(10)),
                GestureDetector(
                  onTap: () => _copyToClipboard(address, cryptoName),
                  child: Container(
                    padding: EdgeInsets.all(responsive.scale(10)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getCryptoColor(cryptoName).withValues(alpha: 0.3),
                          _getCryptoColor(cryptoName).withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getCryptoColor(cryptoName).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: _getCryptoColor(cryptoName),
                      size: responsive.scale(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustWalletButton(ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: _openTrustWallet,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: responsive.scale(20),
          horizontal: responsive.scale(24),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA78BFA), // Purple
              Color(0xFFEC4899), // Pink
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scale(8)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: responsive.scale(22),
              ),
            ),
            SizedBox(width: responsive.scale(14)),
            Text(
              AppLocalizations.of(context).translate('donation.open_trust_wallet'),
              style: GoogleFonts.poppins(
                fontSize: responsive.scale(16).clamp(14.0, 18.0),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThankYouCard(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.scale(22)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00FFA3).withValues(alpha: 0.15),
            const Color(0xFF00D9FF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00FFA3).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFA3).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scale(12)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF6B9D).withValues(alpha: 0.3),
                  const Color(0xFFFF6B9D).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF6B9D).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: ScaleTransition(
              scale: _heartAnimation,
              child: Icon(
                Icons.favorite,
                color: const Color(0xFFFF6B9D),
                size: responsive.scale(28),
              ),
            ),
          ),
          SizedBox(width: responsive.scale(18)),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('donation.thank_you'),
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.scale(14).clamp(12.0, 16.0),
                fontWeight: FontWeight.w600,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCryptoIcon(String cryptoName) {
    if (cryptoName.contains('Ethereum')) return Icons.diamond_outlined;
    if (cryptoName.contains('Tether')) return Icons.attach_money;
    if (cryptoName.contains('Tron')) return Icons.flash_on;
    if (cryptoName.contains('Toncoin')) return Icons.currency_exchange;
    return Icons.currency_exchange;
  }

  Color _getCryptoColor(String cryptoName) {
    if (cryptoName.contains('Ethereum')) return const Color(0xFF627EEA);
    if (cryptoName.contains('Tether')) return const Color(0xFF26A17B);
    if (cryptoName.contains('Tron')) return const Color(0xFFEB0029);
    if (cryptoName.contains('Toncoin')) return const Color(0xFF0088CC);
    return const Color(0xFF00D9FF);
  }
}
