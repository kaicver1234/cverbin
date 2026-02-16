import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_background.dart';
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
  int _currentPage = 0;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(keepPage: true, viewportFraction: 1.0);
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
    if (_isConnecting) return;

    if (!mounted) return;
    setState(() => _isConnecting = true);

    final provider = Provider.of<V2RayProvider>(context, listen: false);

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
            useSecondaryBackground: _currentPage != 0, // Use background2 for Tools and About
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
                        _buildVPNTab(v2rayProvider),
                        _buildToolsTab(context),
                        _buildAboutTab(context),
                      ],
                    ),
                  ),
                  _buildBottomNav(),
                ],
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Name
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              children: const [
                TextSpan(text: 'Tiksar', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'VPN', style: TextStyle(color: Color(0xFF00D9FF))),
              ],
            ),
          ),
          // Language Button
          GestureDetector(
            onTap: () => _showLanguageModal(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
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
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 20 : 24,
          vertical: isSmallScreen ? 16 : 20,
        ),
        child: Column(
          children: [
            const AnnouncementBannerWidget(),
            SizedBox(height: isSmallScreen ? 20 : 28),
            
            // Main Connection Card
            _buildMainConnectionCard(provider, isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            // Server Selection Card
            _buildServerSelectionCard(provider, isSmallScreen),
            
            if (provider.activeConfig != null) ...[
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildStatsCard(provider),
            ],
            
            SizedBox(height: isSmallScreen ? 16 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMainConnectionCard(V2RayProvider provider, bool isSmallScreen) {
    final isConnected = provider.activeConfig != null;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 28 : 36),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isConnected 
              ? const Color(0xFF00FFA3).withValues(alpha: 0.3)
              : const Color(0xFF00D9FF).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: isConnected ? [
          BoxShadow(
            color: const Color(0xFF00FFA3).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ] : [],
      ),
      child: Column(
        children: [
          // Status Badge
          _buildStatusBadge(provider, isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Connection Button
          _buildModernConnectionButton(provider, isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Timer or Status Text
          _buildConnectionInfo(provider, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(V2RayProvider provider, bool isSmallScreen) {
    final isConnected = provider.activeConfig != null;
    
    if (!isConnected && !_isConnecting) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSmallScreen ? 8 : 10,
              height: isSmallScreen ? 8 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 10),
            Text(
              AppLocalizations.of(context).translate('home.disconnected'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 18 : 22,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [
                  const Color(0xFF00FFA3).withValues(alpha: 0.2),
                  const Color(0xFF00FFA3).withValues(alpha: 0.1),
                ]
              : [
                  const Color(0xFF00D9FF).withValues(alpha: 0.2),
                  const Color(0xFF00D9FF).withValues(alpha: 0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF00FFA3).withValues(alpha: 0.4)
              : const Color(0xFF00D9FF).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmallScreen ? 8 : 10,
            height: isSmallScreen ? 8 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF),
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF))
                      .withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Text(
            isConnected
                ? AppLocalizations.of(context).translate('home.connected')
                : AppLocalizations.of(context).translate('home.connecting'),
            style: TextStyle(
              color: isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF),
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernConnectionButton(V2RayProvider provider, bool isSmallScreen) {
    final isConnected = provider.activeConfig != null;
    final buttonSize = isSmallScreen ? 140.0 : 160.0;
    final iconSize = isSmallScreen ? 50.0 : 60.0;
    
    return GestureDetector(
      onTap: _isConnecting ? null : _handleConnectionToggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          if (isConnected || _isConnecting)
            Container(
              width: buttonSize + 40,
              height: buttonSize + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF))
                        .withValues(alpha: 0.0),
                    (isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF))
                        .withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          
          // Animated pulse ring for connecting
          if (_isConnecting)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: buttonSize + 20,
                    height: buttonSize + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted && _isConnecting) setState(() {});
              },
            ),
          
          // Main button
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isConnecting
                    ? [
                        const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        const Color(0xFF0088CC).withValues(alpha: 0.2),
                      ]
                    : isConnected
                        ? [
                            const Color(0xFF00FFA3).withValues(alpha: 0.3),
                            const Color(0xFF00D9FF).withValues(alpha: 0.2),
                          ]
                        : [
                            const Color(0xFF1A3A4A).withValues(alpha: 0.5),
                            const Color(0xFF0A1929).withValues(alpha: 0.3),
                          ],
              ),
              border: Border.all(
                color: _isConnecting
                    ? const Color(0xFF00D9FF).withValues(alpha: 0.5)
                    : isConnected
                        ? const Color(0xFF00FFA3).withValues(alpha: 0.5)
                        : const Color(0xFF00D9FF).withValues(alpha: 0.3),
                width: 3,
              ),
              boxShadow: (isConnected || _isConnecting) ? [
                BoxShadow(
                  color: (isConnected ? const Color(0xFF00FFA3) : const Color(0xFF00D9FF))
                      .withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ] : [],
            ),
            child: Center(
              child: _isConnecting
                  ? SizedBox(
                      width: iconSize * 0.5,
                      height: iconSize * 0.5,
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00D9FF),
                        strokeWidth: 4,
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: iconSize,
                      color: isConnected
                          ? const Color(0xFF00FFA3)
                          : const Color(0xFF00D9FF),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(V2RayProvider provider, bool isSmallScreen) {
    final isConnected = provider.activeConfig != null;
    
    if (!isConnected && !_isConnecting) {
      return Text(
        AppLocalizations.of(context).translate('home.tap_to_connect'),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    
    if (_isConnecting) {
      return Column(
        children: [
          Text(
            AppLocalizations.of(context).translate('home.establishing_connection'),
            style: TextStyle(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 14 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          SizedBox(
            width: isSmallScreen ? 120 : 140,
            child: LinearProgressIndicator(
              backgroundColor: const Color(0xFF00D9FF).withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF00D9FF).withValues(alpha: 0.6),
              ),
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    }
    
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Column(
          children: [
            Text(
              provider.v2rayService.getFormattedConnectedTime(),
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 32 : 38,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00FFA3),
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              AppLocalizations.of(context).translate('home.connection_duration'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServerSelectionCard(V2RayProvider provider, bool isSmallScreen) {
    final isSmartConnect = provider.wasUsingSmartConnect;
    final selectedConfig = provider.selectedConfig ?? provider.activeConfig;
    
    String serverName;
    String subtitle;
    String? countryCode;
    
    if (provider.activeConfig != null) {
      serverName = _cleanServerName(provider.activeConfig!.remark);
      countryCode = provider.activeConfig!.countryCode ?? _extractCountryCode(provider.activeConfig!.remark);
      subtitle = AppLocalizations.of(context).translate('home.current_server');
    } else if (isSmartConnect) {
      serverName = AppLocalizations.of(context).translate('server_selection.smart_connect');
      subtitle = AppLocalizations.of(context).translate('server_selection.smart_connect_description');
    } else if (selectedConfig != null) {
      serverName = _cleanServerName(selectedConfig.remark);
      countryCode = selectedConfig.countryCode ?? _extractCountryCode(selectedConfig.remark);
      subtitle = AppLocalizations.of(context).translate('home.selected_server');
    } else {
      serverName = AppLocalizations.of(context).translate('server_selection.select_server');
      subtitle = AppLocalizations.of(context).translate('home.tap_to_select');
    }
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ServerSelectionScreen()),
      ),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Server Icon/Flag
            _buildServerIconLarge(countryCode, isSmartConnect && provider.activeConfig == null, isSmallScreen),
            
            SizedBox(width: isSmallScreen ? 14 : 18),
            
            // Server Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Text(
                    serverName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Arrow Icon
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerIconLarge(String? countryCode, bool isSmartConnect, bool isSmallScreen) {
    final size = isSmallScreen ? 56.0 : 64.0;
    
    if (countryCode != null && CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: CountryFlags.getFlagUrl(countryCode),
            fit: BoxFit.cover,
            memCacheWidth: 150,
            memCacheHeight: 150,
            maxWidthDiskCache: 150,
            maxHeightDiskCache: 150,
            fadeInDuration: const Duration(milliseconds: 100),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholderFadeInDuration: Duration.zero,
            placeholder: (context, url) => Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.3),
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Icon(
                Icons.public,
                color: const Color(0xFF6366F1),
                size: size * 0.5,
              ),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSmartConnect
              ? [
                  const Color(0xFF00FFA3).withValues(alpha: 0.3),
                  const Color(0xFF00D9FF).withValues(alpha: 0.2),
                ]
              : [
                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSmartConnect
              ? const Color(0xFF00FFA3).withValues(alpha: 0.4)
              : const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Icon(
        isSmartConnect ? Icons.auto_awesome_rounded : Icons.language_rounded,
        color: isSmartConnect ? const Color(0xFF00FFA3) : const Color(0xFF6366F1),
        size: size * 0.5,
      ),
    );
  }

  String _cleanServerName(String name) {
    return name.replaceAll(RegExp(r'^\[[A-Z]{2}\]\s*'), '').trim();
  }

  String? _extractCountryCode(String remark) {
    return CountryFlags.extractCountryCode(remark);
  }


  Widget _buildStatsCard(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 2)),
      builder: (context, snapshot) {
        final ip = v2rayService.ipInfo?.ip ?? '...';
        final download = v2rayService.getFormattedDownload();
        final upload = v2rayService.getFormattedUpload();
        
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 18 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1929).withValues(alpha: 0.5),
            border: Border.all(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // IP Address - Large at top
              Text(
                ip,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 18),
              // Download and Upload - Side by side
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleStatItem(
                      icon: Icons.arrow_downward_rounded,
                      value: download,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: _buildSimpleStatItem(
                      icon: Icons.arrow_upward_rounded,
                      value: upload,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleStatItem({
    required IconData icon,
    required String value,
    required bool isSmallScreen,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
          size: isSmallScreen ? 18 : 20,
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
              color: const Color(0xFF0A1929).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D9FF).withValues(alpha: 0.25),
                        const Color(0xFF00D9FF).withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFF00D9FF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                  size: 16,
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
                  'Version 1.1.4',
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
              color: const Color(0xFF0A1929).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
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
              color: const Color(0xFF0A1929).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              border: Border.all(
                color: const Color(0xFF00FFA3).withValues(alpha: 0.3),
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
          color: const Color(0xFF0A1929).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
          border: Border.all(color: const Color(0xFF00D9FF).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: isSmallScreen ? 44 : 48,
              height: isSmallScreen ? 44 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.9),
                    color.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
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
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.6),
                size: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 80,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background bar
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1929).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          // Navigation items
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildNavItem(
                  index: 1,
                  icon: Icons.build_outlined,
                ),
                const SizedBox(width: 80), // Space for center button
                _buildNavItem(
                  index: 2,
                  icon: Icons.info_outline,
                ),
              ],
            ),
          ),
          // Center VPN button (elevated)
          Positioned(
            top: 0,
            child: _buildCenterNavItem(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    final isActive = _currentPage == index;
    
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
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
                ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                : Colors.transparent,
            border: isActive
                ? Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isActive 
                ? const Color(0xFF00D9FF)
                : Colors.white.withValues(alpha: 0.4),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isActive = _currentPage == 0;
    
    return GestureDetector(
      onTap: () {
        if (_currentPage != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [
                    const Color(0xFF00D9FF),
                    const Color(0xFF0088CC),
                  ]
                : [
                    const Color(0xFF4A5568),
                    const Color(0xFF2D3748),
                  ],
          ),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00D9FF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: const Icon(
          Icons.shield_outlined,
          color: Colors.white,
          size: 32,
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
