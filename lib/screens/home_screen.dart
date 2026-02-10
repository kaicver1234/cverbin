import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/cyber_glow_background.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../screens/theme_selection_screen.dart';
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
  Color _timerColor = const Color(0xFF10b981);
  
  // Single colors for timer (no pink)
  static const List<Color> _timerColorOptions = [
    Color(0xFF10b981), // Green
    Color(0xFF06b6d4), // Cyan
    Color(0xFF3b82f6), // Blue
    Color(0xFF8b5cf6), // Purple
    Color(0xFFf59e0b), // Amber
    Color(0xFF14b8a6), // Teal
    Color(0xFF22c55e), // Emerald
    Color(0xFF6366f1), // Indigo
    Color(0xFFef4444), // Red
    Color(0xFFFFFFFF), // White
  ];
  
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
        .where((code) => code != null && code.isNotEmpty)
        .toSet();
    
    for (final code in countryCodes) {
      if (!mounted) break;
      final url = 'https://flagcdn.com/w80/${code!.toLowerCase()}.png';
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
        // Change timer color on new connection
        _changeTimerColor();
        
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

  void _changeTimerColor() {
    final random = Random();
    setState(() {
      _timerColor = _timerColorOptions[random.nextInt(_timerColorOptions.length)];
    });
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Name
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(text: 'Tiksar', style: TextStyle(color: Color(colors.textPrimaryColor))),
                    const TextSpan(text: 'VPN', style: TextStyle(color: Color(0xFF10b981))),
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
                    color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                    border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.language, color: Color(colors.textSecondaryColor).withValues(alpha: 0.7), size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageModal(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final colors = themeProvider.colors;
    final languages = [
      {'name': 'فارسی', 'code': 'fa', 'flag': '🇮🇷'},
      {'name': 'English', 'code': 'en', 'flag': '🇬🇧'},
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
    final verticalPadding = screenHeight < 700 ? 12.0 : 20.0;
    final horizontalPadding = screenHeight < 700 ? 16.0 : 20.0;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: Column(
          children: [
            const AnnouncementBannerWidget(),
            SizedBox(height: screenHeight < 700 ? 16 : 20),
            _buildConnectionButton(provider),
            SizedBox(height: screenHeight < 700 ? 16 : 24),
            _buildStatusSection(provider),
            SizedBox(height: screenHeight < 700 ? 16 : 24),
            _buildServerCard(provider),
            if (provider.activeConfig != null) ...[
              SizedBox(height: screenHeight < 700 ? 12 : 16),
              _buildStatsCard(provider),
            ],
            SizedBox(height: screenHeight < 700 ? 16 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionButton(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing based on screen height
    final double buttonSize = screenHeight < 700 ? 130 : 150;
    final double glowSize = screenHeight < 700 ? 170 : 200;
    final double iconSize = screenHeight < 700 ? 45 : 55;
    
    // Colors based on state
    final Color buttonColor;
    final Color glowColor;
    
    if (_isConnecting) {
      buttonColor = const Color(0xFFfbbf24); // Yellow for connecting
      glowColor = const Color(0xFFfbbf24);
    } else if (isConnected) {
      buttonColor = const Color(0xFF10b981); // Green for connected
      glowColor = const Color(0xFF10b981);
    } else {
      buttonColor = const Color(0xFF4A5568); // Gray for disconnected
      glowColor = const Color(0xFF4A5568);
    }
    
    return GestureDetector(
      onTap: _isConnecting ? null : _handleConnectionToggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: isConnected || _isConnecting ? 0.4 : 0.2),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          // 3 expanding rings for connecting state
          if (_isConnecting) ...[
            _ExpandingRing(buttonSize: buttonSize, color: glowColor, delayMs: 0),
            _ExpandingRing(buttonSize: buttonSize, color: glowColor, delayMs: 600),
            _ExpandingRing(buttonSize: buttonSize, color: glowColor, delayMs: 1200),
          ],
          // Main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  buttonColor.withValues(alpha: 0.6),
                  buttonColor.withValues(alpha: 0.4),
                ],
              ),
              border: Border.all(
                color: buttonColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new,
                size: iconSize,
                color: Colors.white.withValues(alpha: _isConnecting ? 0.9 : (isConnected ? 1.0 : 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final timerFontSize = screenHeight < 700 ? 28.0 : 34.0;
    
    if (!isConnected && !_isConnecting) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isConnected 
                ? const Color(0xFF10b981).withValues(alpha: 0.12)
                : const Color(0xFFfbbf24).withValues(alpha: 0.12),
            border: Border.all(
              color: isConnected 
                  ? const Color(0xFF10b981).withValues(alpha: 0.3)
                  : const Color(0xFFfbbf24).withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF10b981) : const Color(0xFFfbbf24),
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? const Color(0xFF10b981) : const Color(0xFFfbbf24)).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected 
                    ? AppLocalizations.of(context).translate('home.connected')
                    : AppLocalizations.of(context).translate('home.connecting'),
                style: TextStyle(
                  color: isConnected ? const Color(0xFF10b981) : const Color(0xFFfbbf24),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 8),
          // Timer
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              return Text(
                provider.v2rayService.getFormattedConnectedTime(),
                style: GoogleFonts.poppins(
                  fontSize: timerFontSize,
                  fontWeight: FontWeight.w700,
                  color: _timerColor,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildServerCard(V2RayProvider provider) {
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
    
    return GestureDetector(
      onTap: () => _onServerCardTap(provider),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Icon/Flag
            _buildServerIcon(countryCode, isSmartConnect && provider.activeConfig == null),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildServerIcon(String? countryCode, bool isSmartConnect) {
    if (countryCode != null) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: 'https://flagcdn.com/w160/${countryCode.toLowerCase()}.png',
            fit: BoxFit.cover,
            memCacheWidth: 160,
            memCacheHeight: 120,
            maxWidthDiskCache: 160,
            maxHeightDiskCache: 120,
            placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.1)),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              child: const Icon(Icons.public, color: Color(0xFF6366F1), size: 24),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSmartConnect
              ? [const Color(0xFF10b981).withValues(alpha: 0.2), const Color(0xFF06b6d4).withValues(alpha: 0.1)]
              : [const Color(0xFF6366f1).withValues(alpha: 0.15), const Color(0xFF8b5cf6).withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isSmartConnect ? Icons.flash_on : Icons.language,
        color: isSmartConnect ? const Color(0xFF10b981) : const Color(0xFF6366f1),
        size: 26,
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
    // Try to extract country code from remark: [CC], (CC), CC-, -CC-
    final match = RegExp(r'[\[\(]([A-Z]{2})[\]\)]|^([A-Z]{2})[-\s]', caseSensitive: false).firstMatch(remark.toUpperCase());
    if (match != null) {
      return match.group(1) ?? match.group(2);
    }
    return null;
  }


  Widget _buildStatsCard(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 2)),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _buildStatItem(
                label: AppLocalizations.of(context).translate('home.download'),
                value: v2rayService.getFormattedDownload(),
                color: const Color(0xFF10b981),
                icon: '↓',
              ),
              _buildStatDivider(),
              _buildStatItem(
                label: AppLocalizations.of(context).translate('home.upload'),
                value: v2rayService.getFormattedUpload(),
                color: const Color(0xFF06b6d4),
                icon: '↑',
              ),
              _buildStatDivider(),
              _buildStatItem(
                label: 'IP',
                value: v2rayService.ipInfo?.ip ?? '...',
                color: const Color(0xFFa78bfa),
                icon: '●',
                smallFont: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required String icon,
    bool smallFont = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  smallFont ? value : value.split(' ').first,
                  style: TextStyle(
                    color: color,
                    fontSize: smallFont ? (isSmallScreen ? 10 : 12) : (isSmallScreen ? 15 : 18),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (!smallFont && value.contains(' ')) ...[
                const SizedBox(width: 2),
                Text(
                  value.split(' ').last,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: isSmallScreen ? 9 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: isSmallScreen ? 8 : 10)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: isSmallScreen ? 9 : 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildToolsTab(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).translate('navigation.tools'),
            style: TextStyle(
              color: Color(colors.textPrimaryColor),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('home.quick_actions'),
            style: TextStyle(color: Color(colors.textSecondaryColor).withValues(alpha: 0.7), fontSize: 14),
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
      {
        'icon': Icons.palette_outlined,
        'label': AppLocalizations.of(context).translate('theme.title'),
        'subtitle': AppLocalizations.of(context).translate('theme.subtitle'),
        'screen': const ThemeSelectionScreen(),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;
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
                  color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(colors.primaryColor).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Color(colors.primaryColor), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: Color(colors.textPrimaryColor), fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(subtitle, style: TextStyle(color: Color(colors.textSecondaryColor).withValues(alpha: 0.7), fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Color(colors.textSecondaryColor).withValues(alpha: 0.4), size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    final remoteConfig = RemoteConfigService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
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
                          color: Color(colors.primaryColor).withValues(alpha: 0.3 * value),
                          blurRadius: isSmallScreen ? 40 : 50,
                          spreadRadius: isSmallScreen ? 8 : 10,
                        ),
                        BoxShadow(
                          color: Color(colors.accentColor).withValues(alpha: 0.2 * value),
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
                      Color(colors.primaryColor).withValues(alpha: 0.3),
                      Color(colors.accentColor).withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Color(colors.primaryColor).withValues(alpha: 0.3),
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
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(colors.textPrimaryColor), Color(colors.secondaryColor), Color(colors.primaryColor)],
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
                  Color(colors.primaryColor).withValues(alpha: 0.2),
                  Color(colors.accentColor).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(colors.primaryColor).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Color(colors.primaryColor), size: isSmallScreen ? 14 : 16),
                SizedBox(width: isSmallScreen ? 5 : 6),
                Text(
                  'Version 1.1.3',
                  style: TextStyle(
                    color: Color(colors.textPrimaryColor).withValues(alpha: 0.8),
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
              color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              border: Border.all(
                color: Color(colors.borderColor).withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.8),
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
                  Color(colors.secondaryColor).withValues(alpha: 0.15),
                  Color(colors.secondaryColor).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              border: Border.all(
                color: Color(colors.secondaryColor).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).translate('about.developed_with'),
                    style: TextStyle(
                      color: Color(colors.textSecondaryColor).withValues(alpha: 0.7),
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
                      color: Color(colors.textPrimaryColor),
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
            name: 'Telegram',
            title: remoteConfig.telegramId,
            color: const Color(0xFF0088CC),
            url: remoteConfig.telegramUrl,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildAnimatedSocialLink(
            icon: Icons.camera_alt_rounded,
            name: 'Instagram',
            title: remoteConfig.instagramId,
            color: const Color(0xFFE1306C),
            url: remoteConfig.instagramUrl,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildAnimatedSocialLink(
            icon: Icons.location_city_rounded,
            name: 'Tiksar Village',
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
                color: Color(colors.textSecondaryColor).withValues(alpha: 0.4),
                size: isSmallScreen ? 12 : 14,
              ),
              SizedBox(width: isSmallScreen ? 5 : 6),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).translate('about.copyright'),
                  style: TextStyle(
                    color: Color(colors.textSecondaryColor).withValues(alpha: 0.4),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;
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
              color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
              borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
              border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
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
                          color: Color(colors.textPrimaryColor),
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: TextStyle(
                          color: Color(colors.textSecondaryColor).withValues(alpha: 0.6),
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
                    color: Color(colors.surfaceColor).withValues(alpha: colors.surfaceOpacity),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                    size: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 60,
      decoration: BoxDecoration(
        color: Color(colors.cardColor).withValues(alpha: colors.cardOpacity),
        border: Border.all(color: Color(colors.borderColor).withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildNavItem(0, 'VPN'),
          _buildNavItem(1, AppLocalizations.of(context).translate('navigation.tools')),
          _buildNavItem(2, AppLocalizations.of(context).translate('about.title')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    final isActive = _currentPage == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentPage != index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isActive 
                ? Color(colors.primaryColor).withValues(alpha: 0.15) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive 
                    ? Color(colors.primaryColor) 
                    : Color(colors.textSecondaryColor).withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
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

// Separate StatefulWidget for expanding ring to avoid freeze
class _ExpandingRing extends StatefulWidget {
  final double buttonSize;
  final Color color;
  final int delayMs;

  const _ExpandingRing({
    required this.buttonSize,
    required this.color,
    required this.delayMs,
  });

  @override
  State<_ExpandingRing> createState() => _ExpandingRingState();
}

class _ExpandingRingState extends State<_ExpandingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // Start with delay
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat();
      }
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
        return Opacity(
          opacity: (1 - _animation.value) * 0.5,
          child: Container(
            width: widget.buttonSize + (_animation.value * 100),
            height: widget.buttonSize + (_animation.value * 100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color,
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
