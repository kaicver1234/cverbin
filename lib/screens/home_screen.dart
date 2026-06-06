import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme_model.dart';
import '../widgets/app_background.dart';
import '../widgets/cyber_glow_background.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../utils/country_flags.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../widgets/announcement_banner.dart';
import '../services/remote_config_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isConnecting = false;
  late PageController _pageController;
  int _currentPage = 1; // Start from VPN tab (middle)
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1, keepPage: true, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVpnStatus();
      _loadServers();
    });
  }
  
  Future<void> _syncVpnStatus() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.forceSyncVpnStatus();
    // Wait a bit and sync again to ensure UI is updated
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await provider.forceSyncVpnStatus();
      setState(() {});
    }
  }
  
  Future<void> _loadServers() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    if (provider.serverConfigs.isEmpty) {
      await provider.fetchServers();
    }
    // Preload flags in background
    _preloadFlags();
  }
  
  /// Preload country flags for faster display in server selection
  Future<void> _preloadFlags() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final configs = provider.serverConfigs;
    
    final countryCodes = configs
        .map((c) => c.countryCode)
        .where((code) => code != null && CountryFlags.isValidCountryCode(code))
        .toSet();
    
    for (final code in countryCodes) {
      if (!mounted) break;
      final url = CountryFlags.getFlagUrl(code);
      try {
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
        ).timeout(const Duration(seconds: 2), onTimeout: () {});
      } catch (_) {}
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Sync immediately and again after a short delay
      _syncVpnStatus();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectionToggle() async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);

    if (provider.isConnecting) {
      provider.cancelConnect();
      return;
    }

    if (_isConnecting) return;

    if (!mounted) return;
    setState(() => _isConnecting = true);

    try {
      if (provider.activeConfig != null) {
        await provider.disconnect();
      } else {
        if (provider.wasUsingSmartConnect) {
          await provider.smartConnect();
        } else {
          if (provider.selectedConfig == null && provider.configs.isNotEmpty) {
            await provider.selectConfig(provider.configs.first);
          }
          
          if (provider.selectedConfig == null) {
            if (mounted) {
              _showSnackBar(AppLocalizations.of(context).translate('common.please_select_server'), Colors.red);
            }
          } else {
            await provider.connectToServer(provider.selectedConfig!);
          }
        }
        
        if (mounted && provider.errorMessage.isNotEmpty) {
          _showSnackBar(provider.errorMessage, Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${AppLocalizations.of(context).translate('common.connection_failed')}: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer3<V2RayProvider, LanguageProvider, ThemeProvider>(
      builder: (context, v2rayProvider, languageProvider, themeProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AppBackground(
            child: CyberGlowBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        onPageChanged: (index) {
                          if (mounted) setState(() => _currentPage = index);
                        },
                        children: [
                          _buildToolsTab(context),
                          _buildVPNTab(v2rayProvider),
                          _buildAboutTab(context),
                        ],
                      ),
                    ),
                    _buildBottomNav(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Name
          Text(
            'TiksarVPN',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          // Language Button
          GestureDetector(
            onTap: () => _showLanguageModal(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.language, color: Color(0xFF00D9FF), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageModal(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final colors = themeProvider.colors;
    final languages = [
      {'name': 'پارسی', 'code': 'fa', 'flag': '🇮🇷'},
      {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(colors.cardColor),
          border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('language_settings.language'),
                    style: TextStyle(
                      color: Color(colors.textPrimaryColor),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, color: Color(colors.textSecondaryColor).withValues(alpha: 0.7), size: 18),
                    ),
                  ),
                ],
              ),
            ),
            ...languages.map((lang) {
              final isSelected = languageProvider.currentLanguage.code == lang['code'];
              final isFarsi = lang['code'] == 'fa';
              return GestureDetector(
                onTap: () async {
                  final newLanguage = AppLanguage(
                    name: lang['name']!,
                    code: lang['code']!,
                    flag: lang['flag']!,
                    direction: lang['code'] == 'fa' ? 'rtl' : 'ltr',
                  );
                  await languageProvider.changeLanguage(newLanguage);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: isFarsi ? 16 : 14, // More padding for Farsi
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Color(colors.primaryColor).withValues(alpha: 0.12) 
                        : Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                    border: Border.all(
                      color: isSelected 
                          ? Color(colors.primaryColor).withValues(alpha: 0.3) 
                          : Color(colors.borderColor).withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: TextStyle(
                            color: Color(colors.textPrimaryColor),
                            fontSize: isFarsi ? 16 : 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: isFarsi ? 0.3 : 0,
                            height: isFarsi ? 1.6 : 1.4,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Color(colors.primaryColor) : Colors.transparent,
                          border: Border.all(
                            color: isSelected 
                                ? Color(colors.primaryColor) 
                                : Color(colors.borderColor).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildVPNTab(V2RayProvider provider) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 20.0 : 24.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmallScreen ? 8 : 12),
        child: Column(
          children: [
            const AnnouncementBannerWidget(),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Status chip
            _buildStatusChip(provider),

            SizedBox(height: isSmallScreen ? 28 : 40),

            // Connection button (minimal)
            _buildConnectionButton(provider),

            SizedBox(height: isSmallScreen ? 20 : 28),

            // Timer
            _buildTimerSection(provider, isSmallScreen),

            SizedBox(height: isSmallScreen ? 28 : 40),

            // Minimal stats row
            _buildStatsRow(provider, isSmallScreen),

            SizedBox(height: isSmallScreen ? 28 : 40),

            // Server selection card (minimal)
            _buildServerCard(provider, isSmallScreen),

            SizedBox(height: isSmallScreen ? 8 : 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    final Color dot;
    final String label;

    if (_isConnecting) {
      dot = const Color(0xFF00D9FF);
      label = AppLocalizations.of(context).translate('home.connecting');
    } else if (isConnected) {
      dot = const Color(0xFF00FFA3);
      label = AppLocalizations.of(context).translate('home.connected');
    } else {
      dot = Colors.white.withValues(alpha: 0.4);
      label = AppLocalizations.of(context).translate('home.disconnected');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dot,
              boxShadow: [
                BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(V2RayProvider provider, bool isSmallScreen) {
    final isConnected = provider.activeConfig != null;
    final timerFontSize = isSmallScreen ? 26.0 : 30.0;

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Text(
          isConnected
              ? provider.v2rayService.getFormattedConnectedTime()
              : '00:00:00',
          style: GoogleFonts.jetBrainsMono(
            fontSize: timerFontSize,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: isConnected ? 0.95 : 0.35),
            letterSpacing: 3,
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(V2RayProvider provider, bool isSmallScreen) {
    final v2rayService = provider.v2rayService;
    final isConnected = provider.activeConfig != null;

    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 18 : 22,
            vertical: isSmallScreen ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMinimalStat(
                  label: 'DOWNLOAD',
                  value: isConnected ? v2rayService.getFormattedDownload() : '0 B',
                  color: const Color(0xFF00FFA3),
                  icon: Icons.arrow_downward_rounded,
                  isSmallScreen: isSmallScreen,
                ),
              ),
              Container(
                width: 1,
                height: isSmallScreen ? 36 : 42,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _buildMinimalStat(
                  label: 'UPLOAD',
                  value: isConnected ? v2rayService.getFormattedUpload() : '0 B',
                  color: const Color(0xFF00D9FF),
                  icon: Icons.arrow_upward_rounded,
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMinimalStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isSmallScreen,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 16 : 18),
        SizedBox(width: isSmallScreen ? 8 : 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: isSmallScreen ? 9 : 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionButton(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    final screenHeight = MediaQuery.of(context).size.height;

    final double buttonSize = screenHeight < 700 ? 150 : 175;
    final double iconSize = screenHeight < 700 ? 46 : 54;

    final Color accent;
    if (_isConnecting) {
      accent = const Color(0xFF00D9FF);
    } else if (isConnected) {
      accent = const Color(0xFF00FFA3);
    } else {
      accent = const Color(0xFF00D9FF);
    }

    return GestureDetector(
      onTap: _handleConnectionToggle,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft ambient glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: buttonSize + 60,
            height: buttonSize + 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: (isConnected || _isConnecting) ? 0.25 : 0.08),
                  blurRadius: 60,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),

          // Animated pulsing ring while connecting
          if (_isConnecting)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.15),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Container(
                  width: buttonSize * value,
                  height: buttonSize * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 1.2 - value),
                      width: 1.5,
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted && _isConnecting) setState(() {});
              },
            ),

          // Outer thin ring
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),

          // Inner button
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: buttonSize - 24,
            height: buttonSize - 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: (isConnected || _isConnecting)
                    ? [
                        accent.withValues(alpha: 0.35),
                        accent.withValues(alpha: 0.08),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.01),
                      ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: (isConnected || _isConnecting) ? 0.6 : 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: _isConnecting
                  ? SizedBox(
                      width: iconSize * 0.6,
                      height: iconSize * 0.6,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: iconSize,
                      color: isConnected ? Colors.white : accent,
                    ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildServerCard(V2RayProvider provider, bool isSmallScreen) {
    final isSmartConnect = provider.wasUsingSmartConnect;
    final selectedConfig = provider.selectedConfig ?? provider.activeConfig;

    String serverName;
    String? subtitle;
    String? countryCode;

    if (provider.activeConfig != null) {
      serverName = _cleanServerName(provider.activeConfig!.remark);
      countryCode = provider.activeConfig!.countryCode ?? _extractCountryCode(provider.activeConfig!.remark);
    } else if (isSmartConnect) {
      serverName = AppLocalizations.of(context).translate('server_selection.smart_connect');
      subtitle = AppLocalizations.of(context).translate('server_selection.smart_connect_description');
    } else if (selectedConfig != null) {
      serverName = _cleanServerName(selectedConfig.remark);
      countryCode = selectedConfig.countryCode ?? _extractCountryCode(selectedConfig.remark);
    } else {
      serverName = AppLocalizations.of(context).translate('server_selection.select_server');
    }

    final iconSize = isSmallScreen ? 40.0 : 44.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onServerCardTap(provider),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 14 : 16,
            vertical: isSmallScreen ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _buildServerIcon(countryCode, isSmartConnect && provider.activeConfig == null, iconSize),
              SizedBox(width: isSmallScreen ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('home.server_location_label'),
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      serverName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: isSmallScreen ? 20 : 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerIcon(String? countryCode, bool isSmartConnect, double size) {
    if (countryCode != null && CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: CountryFlags.getFlagUrl(countryCode),
            fit: BoxFit.cover,
            // Home screen: larger flag (52x52 container)
            memCacheWidth: 120,
            memCacheHeight: 120,
            maxWidthDiskCache: 120,
            maxHeightDiskCache: 120,
            fadeInDuration: const Duration(milliseconds: 100),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholderFadeInDuration: Duration.zero,
            placeholder: (context, url) => Container(
              color: Colors.white.withValues(alpha: 0.1),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
              child: Icon(Icons.public, color: const Color(0xFF00D9FF), size: size * 0.46),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSmartConnect
              ? [const Color(0xFF00FFA3).withValues(alpha: 0.2), const Color(0xFF00D9FF).withValues(alpha: 0.1)]
              : [const Color(0xFF00D9FF).withValues(alpha: 0.15), const Color(0xFF00FFA3).withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isSmartConnect ? Icons.flash_on : Icons.language,
        color: isSmartConnect ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF),
        size: size * 0.5,
      ),
    );
  }

  void _onServerCardTap(V2RayProvider provider) {
    // Always allow navigation to server selection screen
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerSelectionScreen()));
  }

  String _cleanServerName(String name) {
    return name.replaceAll(RegExp(r'^\[[A-Z]{2}\]\s*'), '').trim();
  }

  String? _extractCountryCode(String remark) {
    return CountryFlags.extractCountryCode(remark);
  }


  Widget _buildToolsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).translate('navigation.tools'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('home.quick_actions'),
            style: TextStyle(color: const Color(0xFF00D9FF).withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildToolsList(context)),
        ],
      ),
    );
  }

  Widget _buildToolsList(BuildContext context) {
    final tools = [
      {
        'icon': Icons.info_outline,
        'label': AppLocalizations.of(context).translate('home.ip_info'),
        'subtitle': AppLocalizations.of(context).translate('tools.ip_information_desc'),
        'screen': const IpInfoScreen(),
      },
      {
        'icon': Icons.speed,
        'label': AppLocalizations.of(context).translate('home.speed_test'),
        'subtitle': AppLocalizations.of(context).translate('tools.speed_test_desc'),
        'screen': const SpeedTestScreen(),
      },
      {
        'icon': Icons.dns,
        'label': AppLocalizations.of(context).translate('home.host_checker'),
        'subtitle': AppLocalizations.of(context).translate('tools.host_checker_desc'),
        'screen': const HostCheckerScreen(),
      },
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildToolCard(
          icon: tool['icon'] as IconData,
          label: tool['label'] as String,
          subtitle: tool['subtitle'] as String,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tool['screen'] as Widget)),
        );
      },
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF00D9FF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: const Color(0xFF00D9FF).withValues(alpha: 0.5), fontSize: 13)),
                    ],
                  ),
                ),
                Consumer<LanguageProvider>(
                  builder: (context, langProvider, _) => Icon(
                    langProvider.isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    final remoteConfig = RemoteConfigService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final description = remoteConfig.getAboutDescription(languageProvider.currentLanguage.code);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 700;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 24,
        vertical: isSmallScreen ? 16 : 20,
      ),
      child: Column(
        children: [
          SizedBox(height: isSmallScreen ? 12 : 20),
          
          // Logo with animated glow effect
          Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  final logoSize = isSmallScreen ? 100.0 : 120.0;
                  return Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.3 * value),
                          blurRadius: isSmallScreen ? 40 : 50,
                          spreadRadius: isSmallScreen ? 8 : 10,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00FFA3).withValues(alpha: 0.2 * value),
                          blurRadius: isSmallScreen ? 60 : 70,
                          spreadRadius: isSmallScreen ? 12 : 15,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Container(
                width: isSmallScreen ? 80 : 100,
                height: isSmallScreen ? 80 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: 0.3),
                      const Color(0xFF00FFA3).withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/apk.png', fit: BoxFit.cover),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 28),
          
          // App Name with gradient animation
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFF00D9FF), Color(0xFF00FFA3)],
            ).createShader(bounds),
            child: Text(
              'TiksarVPN',
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 32 : (isMediumScreen ? 36 : 38),
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 10 : 12),
          
          // Version with icon
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 14,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withValues(alpha: 0.2),
                  const Color(0xFF00FFA3).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: const Color(0xFF00D9FF), size: isSmallScreen ? 14 : 16),
                SizedBox(width: isSmallScreen ? 5 : 6),
                Text(
                  'Version 1.1.5',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Description with subtle background
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 20,
              vertical: isSmallScreen ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.7),
                fontSize: isSmallScreen ? 13 : 15,
                height: isSmallScreen ? 1.6 : 1.8,
              ),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 28),
          
          // Developer with beating heart
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 14 : 18,
              vertical: isSmallScreen ? 12 : 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00FFA3).withValues(alpha: 0.15),
                  const Color(0xFF00FFA3).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              border: Border.all(
                color: const Color(0xFF00FFA3).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).translate('about.developed_with'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: isSmallScreen ? 13 : 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                const _BeatingHeart(),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).translate('about.developer'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 28 : 36),
          
          // Social Links with hover effect
          _buildAnimatedSocialLink(
            icon: Icons.send_rounded,
            name: AppLocalizations.of(context).translate('about.telegram'),
            title: remoteConfig.telegramId,
            color: const Color(0xFF0088CC),
            url: remoteConfig.telegramUrl,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildAnimatedSocialLink(
            icon: Icons.camera_alt_rounded,
            name: AppLocalizations.of(context).translate('about.instagram'),
            title: remoteConfig.instagramId,
            color: const Color(0xFFE1306C),
            url: remoteConfig.instagramUrl,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildAnimatedSocialLink(
            icon: Icons.location_city_rounded,
            name: AppLocalizations.of(context).translate('about.tiksar_village_page'),
            title: remoteConfig.tiksarPageId,
            color: const Color(0xFF833AB4),
            url: remoteConfig.tiksarPageUrl,
            isSmallScreen: isSmallScreen,
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Copyright with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.copyright,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                size: isSmallScreen ? 12 : 14,
              ),
              SizedBox(width: isSmallScreen ? 5 : 6),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).translate('about.copyright'),
                  style: TextStyle(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildAnimatedSocialLink({
    required IconData icon,
    required String name,
    required String title,
    required Color color,
    required String url,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 14 : 18,
          vertical: isSmallScreen ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
          border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: isSmallScreen ? 44 : 48,
              height: isSmallScreen ? 44 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: isSmallScreen ? 10 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: isSmallScreen ? 22 : 24),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Consumer<LanguageProvider>(
              builder: (context, langProvider, _) => Container(
                padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  langProvider.isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.5),
                  size: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left button (Tools)
          _buildNavItem(0, Icons.settings_outlined, colors),
          const SizedBox(width: 30),
          // Center button (VPN/Home) - Larger
          _buildNavItem(1, Icons.shield_outlined, colors, isCenter: true),
          const SizedBox(width: 30),
          // Right button (About)
          _buildNavItem(2, Icons.public, colors),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, ThemeColors colors, {bool isCenter = false}) {
    final isActive = _currentPage == index;
    
    // Sizes matching the reference image - closer together
    final size = isCenter ? 95.0 : 75.0;
    final iconSize = isCenter ? 40.0 : 30.0;
    
    // Colors: Active center is cyan, inactive are dark gray
    final Color buttonColor;
    if (isActive && isCenter) {
      // Cyan/blue gradient for active center button
      buttonColor = const Color(0xFF1E88A8); // Teal/cyan blue
    } else if (isActive && !isCenter) {
      // If side buttons are active, also use cyan
      buttonColor = const Color(0xFF1E88A8);
    } else {
      // Inactive buttons are dark gray
      buttonColor = const Color(0xFF6B7280);
    }
    
    return GestureDetector(
      onTap: () {
        if (_currentPage != index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor,
          boxShadow: (isActive && isCenter)
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E88A8).withValues(alpha: 0.5),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}


// Beating heart widget
class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart();

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Transform.scale(
          scale: _animation.value,
          child: const Icon(
            Icons.favorite,
            color: Color(0xFFef4444),
            size: 16,
          ),
        );
      },
    );
  }
}
