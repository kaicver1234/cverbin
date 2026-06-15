import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../utils/country_flags.dart';
import '../utils/responsive_helper.dart';
import '../widgets/app_background.dart';
import '../widgets/modern_glass_card.dart';
import '../widgets/modern_connection_button.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/announcement_banner.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../screens/dns_settings_screen.dart';
import '../screens/per_app_proxy_screen.dart';
import '../screens/donation_screen.dart';
import '../screens/routing_settings_screen.dart';
import '../services/remote_config_service.dart';
import '../services/analytics_service.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> 
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isConnecting = false;
  int _currentPage = 1; // Start from VPN tab (middle)
  final Stream<int> _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i).asBroadcastStream();
  final Stream<int> _statsStream = Stream.periodic(const Duration(milliseconds: 500), (i) => i).asBroadcastStream();
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServers();
      AnalyticsService().logScreenView(screenName: 'Safheh_Asli');
    });
  }
  
  Future<void> _syncVpnStatus() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.forceSyncVpnStatus();
  }
  
  Future<void> _loadServers() async {
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    if (provider.serverConfigs.isEmpty) {
      await provider.fetchServers();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _syncVpnStatus();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleConnectionToggle() async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);

    // Ignore taps while the previous connect is still being cancelled — the
    // button shows "Cancelling…" until teardown finishes and a real connect
    // would actually go through.
    if (provider.isCancelling) return;

    if (_isConnecting) {
      provider.cancelConnect();
      if (mounted) setState(() => _isConnecting = false);
      return;
    }

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
              _showSnackBar(
                AppLocalizations.of(context).translate('common.please_select_server'), 
                Colors.red
              );
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
        _showSnackBar(
          '${AppLocalizations.of(context).translate('common.connection_failed')}: $e', 
          Colors.red
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, v2rayProvider, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _buildModernHeader(context, languageProvider),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: ResponsiveHelper(context).maxContentWidth),
                        child: IndexedStack(
                          index: _currentPage,
                          children: [
                            _buildToolsPage(context),
                            _buildVPNPage(v2rayProvider),
                            _buildAboutPage(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ModernBottomNav(
                    currentIndex: _currentPage,
                    onTap: (index) {
                      if (mounted) {
                        setState(() => _currentPage = index);
                      }
                    },
                    items: [
                      ModernNavItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: AppLocalizations.of(context).translate('navigation.tools'),
                        color: const Color(0xFFFF6B9D),
                      ),
                      ModernNavItem(
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield,
                        label: 'VPN',
                        color: const Color(0xFF00D9FF),
                      ),
                      ModernNavItem(
                        icon: Icons.info_outline,
                        activeIcon: Icons.info,
                        label: AppLocalizations.of(context).translate('navigation.about'),
                        color: const Color(0xFF00FFA3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(BuildContext context, LanguageProvider languageProvider) {
    final responsive = ResponsiveHelper(context);
    
    return Padding(
      padding: EdgeInsets.all(responsive.horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Info - Simple (No Logo)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TiksarVPN',
                style: GoogleFonts.poppins(
                  fontSize: responsive.headerFontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Secure & Fast',
                style: GoogleFonts.poppins(
                  fontSize: responsive.headerFontSize * 0.55,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          
          // Language Button
          GestureDetector(
            onTap: () => _showLanguageModal(context),
            child: ModernGlassCard(
              padding: EdgeInsets.all(responsive.scale(12)),
              borderRadius: BorderRadius.circular(14),
              child: Icon(
                Icons.language,
                color: Colors.white,
                size: responsive.scale(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageModal(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final languages = [
      {'name': 'پارسی', 'code': 'fa', 'flag': '🇮🇷'},
      {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
    ];

    final r = ResponsiveHelper(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.dialogMaxWidth + 40),
          child: Container(
        margin: EdgeInsets.all(r.scale(20).clamp(14.0, 28.0)),
        padding: EdgeInsets.all(r.scale(24).clamp(16.0, 32.0)),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('language_settings.language'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...languages.map((lang) {
              final isSelected = languageProvider.currentLanguage.code == lang['code'];
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
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: lang['code'] == 'fa' ? 16 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
        ),
      ),
    );
  }



  String _cleanServerName(String name) {
    return name.replaceAll(RegExp(r'^\[[A-Z]{2}\]\s*'), '').trim();
  }

  Widget _buildConnectionTimer(V2RayProvider provider) {
    final responsive = ResponsiveHelper(context);
    final isConnected = provider.activeConfig != null;

    return StreamBuilder(
      // Only tick while connected. When disconnected the timer reads a constant
      // "00:00:00", so leaving the periodic stream running just burns CPU/battery
      // (this screen is kept alive, so the listener never detaches on its own).
      stream: isConnected ? _timerStream : null,
      builder: (context, snapshot) {
        return Center(
          child: Text(
            isConnected
                ? provider.v2rayService.getFormattedConnectedTime()
                : '00:00:00',
            key: const ValueKey('timer'),
            style: GoogleFonts.poppins(
              fontSize: responsive.timerFontSize * 0.95,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: isConnected ? 1.0 : 0.35),
              letterSpacing: 2.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }



  // VPN Page - Main connection page (minimal & modern)
  Widget _buildVPNPage(V2RayProvider provider) {
    final responsive = ResponsiveHelper(context);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
        child: Column(
          children: [
            SizedBox(height: responsive.responsiveValue(small: 8, medium: 12, large: 16)),

            const AnnouncementBannerWidget(),

            SizedBox(height: responsive.responsiveValue(small: 24, medium: 30, large: 36)),

            // Connection button (centerpiece)
            _buildConnectionButtonWithStatus(provider),

            SizedBox(height: responsive.responsiveValue(small: 14, medium: 18, large: 22)),

            // Status pill (connect text) - below button
            _buildStatusPill(provider),

            SizedBox(height: responsive.responsiveValue(small: 16, medium: 20, large: 24)),

            // Timer below status
            _buildConnectionTimer(provider),

            SizedBox(height: responsive.responsiveValue(small: 28, medium: 34, large: 40)),

            // Server card (minimal) - above stats
            _buildServerCard(provider),

            SizedBox(height: responsive.responsiveValue(small: 22, medium: 28, large: 34)),

            // Minimal stats (no card, simple)
            _buildSimpleStats(provider),

            SizedBox(height: responsive.scale(100).clamp(70.0, 130.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    final isCancelling = provider.isCancelling;
    final isConnecting = _isConnecting || provider.isConnecting;

    final String text;
    final Color color;

    if (isCancelling) {
      text = AppLocalizations.of(context).translate('home.cancelling');
      color = const Color(0xFFFFB020);
    } else if (isConnecting) {
      text = AppLocalizations.of(context).translate('home.connecting');
      color = const Color(0xFF00D9FF);
    } else if (isConnected) {
      text = AppLocalizations.of(context).translate('home.connected');
      color = const Color(0xFF00FFA3);
    } else {
      text = AppLocalizations.of(context).translate('home.disconnected');
      color = Colors.white.withValues(alpha: 0.5);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(isCancelling ? 'x' : isConnecting ? 'c' : isConnected ? 'on' : 'off'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8, spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionButtonWithStatus(V2RayProvider provider) {
    final responsive = ResponsiveHelper(context);
    final isConnected = provider.activeConfig != null;
    // Keep the spinner running during the cancel-teardown window so the button
    // visibly stays "busy" instead of snapping back to the idle state while the
    // tap is still being ignored.
    final isConnecting = _isConnecting || provider.isConnecting || provider.isCancelling;

    final btnSize = responsive.connectionButtonSize;
    return ModernConnectionButton(
      key: const ValueKey('connection_button'),
      isConnected: isConnected,
      isConnecting: isConnecting,
      onTap: _handleConnectionToggle,
      size: btnSize,
    );
  }

  Widget _buildServerCard(V2RayProvider provider) {
    final responsive = ResponsiveHelper(context);
    final isSmartConnect = provider.wasUsingSmartConnect;
    final selectedConfig = provider.selectedConfig ?? provider.activeConfig;

    String serverName;
    String? countryCode;

    if (provider.activeConfig != null) {
      serverName = _cleanServerName(provider.activeConfig!.remark);
      countryCode = provider.activeConfig!.countryCode;
    } else if (isSmartConnect) {
      serverName = AppLocalizations.of(context).translate('server_selection.smart_connect');
    } else if (selectedConfig != null) {
      serverName = _cleanServerName(selectedConfig.remark);
      countryCode = selectedConfig.countryCode;
    } else {
      serverName = AppLocalizations.of(context).translate('server_selection.select_server');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServerSelectionScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          key: const ValueKey('server_card'),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.scale(16).clamp(12.0, 22.0),
            vertical: responsive.scale(14).clamp(10.0, 18.0),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Flag / icon
              Container(
                width: responsive.homeFlagWidth,
                height: responsive.homeFlagHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildServerIconContent(
                    countryCode,
                    isSmartConnect && provider.activeConfig == null,
                  ),
                ),
              ),
              SizedBox(width: responsive.scale(14).clamp(10.0, 18.0)),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('server_selection.current_server').toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: responsive.scale(9.5).clamp(8.5, 11.5),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serverName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: responsive.scale(15).clamp(13.0, 17.0),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: responsive.scale(22).clamp(18.0, 26.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerIconContent(String? countryCode, bool isSmartConnect) {
    if (countryCode != null && CountryFlags.isValidCountryCode(countryCode)) {
      return CachedNetworkImage(
        imageUrl: CountryFlags.getFlagUrl(countryCode),
        // Flag container is a true 4:3 rectangle, so `cover` fills it without
        // cropping or distorting the (also 4:3) flag image.
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 240,
        placeholder: (context, url) => Container(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.white.withValues(alpha: 0.08),
          child: const Center(
            child: Icon(Icons.public, color: Colors.white70, size: 18),
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        isSmartConnect ? Icons.bolt_rounded : Icons.language_rounded,
        color: Colors.white.withValues(alpha: 0.85),
        size: 18,
      ),
    );
  }

  Widget _buildSimpleStats(V2RayProvider provider) {
    final v2rayService = provider.v2rayService;
    final isConnected = provider.activeConfig != null;

    return StreamBuilder(
      // Same as the connection timer: only poll traffic stats while connected.
      // Disconnected stats are constant ("0 B"), so there's nothing to refresh.
      stream: isConnected ? _statsStream : null,
      builder: (context, snapshot) {
        return Row(
          children: [
            Expanded(
              child: _buildSimpleStatItem(
                icon: Icons.arrow_downward_rounded,
                label: AppLocalizations.of(context).translate('home.download'),
                value: isConnected ? v2rayService.getFormattedDownload() : '0 B',
                color: const Color(0xFF00FFA3),
              ),
            ),
            Expanded(
              child: _buildSimpleStatItem(
                icon: Icons.arrow_upward_rounded,
                label: AppLocalizations.of(context).translate('home.upload'),
                value: isConnected ? v2rayService.getFormattedUpload() : '0 B',
                color: const Color(0xFF00D9FF),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final responsive = ResponsiveHelper(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: responsive.scale(12).clamp(10.5, 14.0),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: responsive.scale(4)),
        Icon(
          icon,
          color: Colors.white,
          size: responsive.scale(18).clamp(14.0, 22.0),
        ),
        SizedBox(height: responsive.scale(4)),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: responsive.scale(13.5).clamp(11.5, 16.0),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // Tools Page - Quick access to tools
  Widget _buildToolsPage(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final tools = [
      {
        'icon': Icons.speed_rounded,
        'label': AppLocalizations.of(context).translate('home.speed_test'),
        'subtitle': AppLocalizations.of(context).translate('tools.speed_test_desc'),
        'color': const Color(0xFF00D9FF),
        'screen': const SpeedTestScreen(),
      },
      {
        'icon': Icons.info_outline_rounded,
        'label': AppLocalizations.of(context).translate('home.ip_info'),
        'subtitle': AppLocalizations.of(context).translate('tools.ip_information_desc'),
        'color': const Color(0xFF00FFA3),
        'screen': const IpInfoScreen(),
      },
      {
        'icon': Icons.dns_rounded,
        'label': AppLocalizations.of(context).translate('home.host_checker'),
        'subtitle': AppLocalizations.of(context).translate('tools.host_checker_desc'),
        'color': const Color(0xFFFF6B9D),
        'screen': const HostCheckerScreen(),
      },
      {
        'icon': Icons.manage_search_rounded,
        'label': AppLocalizations.of(context).translate('home.dns_server'),
        'subtitle': AppLocalizations.of(context).translate('tools.dns_server_desc'),
        'color': const Color(0xFFA78BFA),
        'screen': const DnsSettingsScreen(),
      },
      {
        'icon': Icons.apps_rounded,
        'label': AppLocalizations.of(context).translate('home.per_app_proxy'),
        'subtitle': AppLocalizations.of(context).translate('tools.per_app_proxy_desc'),
        'color': const Color(0xFFFFB347),
        'screen': const PerAppProxyScreen(),
      },
      {
        'icon': Icons.alt_route_rounded,
        'label': AppLocalizations.of(context).translate('home.routing'),
        'subtitle': AppLocalizations.of(context).translate('tools.routing_desc'),
        'color': const Color(0xFF00D9FF),
        'screen': const RoutingSettingsScreen(),
      },
    ];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.all(responsive.horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Simple Title Only
          Text(
            AppLocalizations.of(context).translate('navigation.tools'),
            style: GoogleFonts.poppins(
              fontSize: responsive.pageTitleFontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: responsive.verticalSpacing),
          
          // Tools Grid
          ...tools.map((tool) => Padding(
            padding: EdgeInsets.only(bottom: responsive.scale(10)),
            child: _buildToolCard(
              icon: tool['icon'] as IconData,
              label: tool['label'] as String,
              subtitle: tool['subtitle'] as String,
              color: tool['color'] as Color,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => tool['screen'] as Widget),
              ),
            ),
          )),
          
          SizedBox(height: responsive.scale(80).clamp(60.0, 110.0)), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final responsive = ResponsiveHelper(context);
    return GestureDetector(
      onTap: onTap,
      child: ModernGlassCard(
        padding: EdgeInsets.all(responsive.toolCardPadding),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scale(9).clamp(7.0, 13.0)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: responsive.toolIconSize),
            ),
            SizedBox(width: responsive.scale(11).clamp(8.0, 16.0)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.scale(13).clamp(11.5, 16.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: responsive.scale(11).clamp(9.5, 13.0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Consumer<LanguageProvider>(
              builder: (context, langProvider, _) => Container(
                padding: EdgeInsets.all(responsive.scale(6).clamp(4.0, 9.0)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  langProvider.isRtl ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white,
                  size: responsive.scale(16).clamp(13.0, 22.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutPage(BuildContext context) {
    final remoteConfig = RemoteConfigService();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final description = remoteConfig.getAboutDescription(languageProvider.currentLanguage.code);
    return _AboutPageView(
      description: description,
      remoteConfig: remoteConfig,
    );
  }

}

class _AboutPageView extends StatefulWidget {
  final String description;
  final RemoteConfigService remoteConfig;

  const _AboutPageView({
    required this.description,
    required this.remoteConfig,
  });

  @override
  State<_AboutPageView> createState() => _AboutPageViewState();
}

class _AboutPageViewState extends State<_AboutPageView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  static const _intervals = [
    [0.0, 0.35],
    [0.1, 0.45],
    [0.2, 0.55],
    [0.35, 0.7],
    [0.55, 0.85],
    [0.7, 1.0],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnims = _intervals.map((iv) => CurvedAnimation(
      parent: _controller,
      curve: Interval(iv[0], iv[1], curve: Curves.easeOut),
    )).toList();

    _slideAnims = _intervals.map((iv) => Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(iv[0], iv[1], curve: Curves.easeOut),
    ))).toList();

    _controller.forward();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _heartAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.95), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.28), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 56),
    ]).animate(_heartController);
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

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final remoteConfig = widget.remoteConfig;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: Column(
        children: [
          SizedBox(height: responsive.scale(44).clamp(32.0, 56.0)),

          // Logo with glow ring
          _animated(0, _buildLogo(responsive)),

          SizedBox(height: responsive.scale(24).clamp(18.0, 32.0)),

          // App name + version
          _animated(1, Column(
            children: [
              Text(
                'TiksarVPN',
                style: GoogleFonts.poppins(
                  fontSize: responsive.aboutTitleFontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Version 1.1.5',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          )),

          SizedBox(height: responsive.scale(30).clamp(22.0, 40.0)),

          // Description
          _animated(2, Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: responsive.scale(13.5).clamp(12.0, 15.5),
              height: 1.85,
            ),
          )),

          SizedBox(height: responsive.scale(36).clamp(26.0, 46.0)),

          // Gradient divider + developer row
          _animated(3, Column(
            children: [
              _buildGradientDivider(),
              const SizedBox(height: 28),
              _buildDeveloperRow(context),
              const SizedBox(height: 28),
              _buildGradientDivider(),
            ],
          )),

          SizedBox(height: responsive.scale(28).clamp(20.0, 38.0)),

          // Social links
          _animated(4, Column(
            children: [
              _buildSocialLink(
                icon: Icons.send_rounded,
                iconColor: const Color(0xFF29B6F6),
                name: AppLocalizations.of(context).translate('about.telegram'),
                title: remoteConfig.telegramId,
                url: remoteConfig.telegramUrl,
                isTelegram: true,
              ),
              const SizedBox(height: 10),
              _buildSocialLink(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFFEC407A),
                name: AppLocalizations.of(context).translate('about.instagram'),
                title: remoteConfig.instagramId,
                url: remoteConfig.instagramUrl,
              ),
              const SizedBox(height: 10),
              _buildSocialLink(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFFEC407A),
                name: AppLocalizations.of(context).translate('about.tiksar_village_page'),
                title: remoteConfig.tiksarPageId,
                url: remoteConfig.tiksarPageUrl,
              ),
            ],
          )),

          SizedBox(height: responsive.scale(28).clamp(20.0, 38.0)),

          // Donation Button
          _animated(4, _buildDonationButton(context, responsive)),

          SizedBox(height: responsive.scale(48).clamp(36.0, 60.0)),

          // Copyright
          _animated(5, Text(
            '© 2026 TiksarVPN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          )),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLogo(ResponsiveHelper responsive) {
    final size = responsive.aboutLogoSize;
    return SizedBox(
      width: size + 16,
      height: size + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/apk.png', fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppLocalizations.of(context).translate('about.developed_with'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        ScaleTransition(
          scale: _heartAnimation,
          child: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 15),
        ),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).translate('about.developer'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLink({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String title,
    required String url,
    bool isTelegram = false,
  }) {
    return GestureDetector(
      onTap: () async {
        try {
          if (isTelegram) {
            final webUri = Uri.parse(url);
            final username = webUri.pathSegments.isNotEmpty ? webUri.pathSegments.last : '';
            if (username.isNotEmpty) {
              final tgUri = Uri.parse('tg://resolve?domain=$username');
              if (await canLaunchUrl(tgUri)) {
                await launchUrl(tgUri);
                return;
              }
            }
          }
          final uri = Uri.parse(url);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Consumer<LanguageProvider>(
              builder: (context, langProvider, _) => Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  langProvider.isRtl
                      ? Icons.arrow_back_ios_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationButton(BuildContext context, ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DonationScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: responsive.scale(18),
          horizontal: responsive.scale(24),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFFF4D6D),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).translate('donation.button'),
              style: GoogleFonts.poppins(
                fontSize: responsive.scale(16).clamp(14.0, 18.0),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
