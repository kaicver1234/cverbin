import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/cyber_glow_background.dart';
import '../models/app_language.dart';
import '../utils/app_localizations.dart';
import '../screens/server_selection_screen.dart';
import '../screens/ip_info_screen.dart';
import '../screens/speedtest_screen.dart';
import '../screens/host_checker_screen.dart';
import '../widgets/announcement_banner.dart';

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
    
    return Consumer2<V2RayProvider, LanguageProvider>(
      builder: (context, v2rayProvider, languageProvider, child) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Name
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              children: const [
                TextSpan(text: 'Tiksar', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'VPN', style: TextStyle(color: Color(0xFFa78bfa))),
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
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.language, color: Colors.white.withValues(alpha: 0.5), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageModal(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final languages = [
      {'name': 'فارسی', 'code': 'fa', 'flag': '🦁'},
      {'name': 'English', 'code': 'en', 'flag': '🇬🇧'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF14141a),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6), size: 18),
                    ),
                  ),
                ],
              ),
            ),
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
                    setState(() {});
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10b981).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10b981).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF10b981) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10b981) : Colors.white.withValues(alpha: 0.2),
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const AnnouncementBannerWidget(),
            const SizedBox(height: 20),
            _buildConnectionButton(provider),
            const SizedBox(height: 24),
            _buildStatusSection(provider),
            const SizedBox(height: 24),
            _buildServerCard(provider),
            if (provider.activeConfig != null) ...[
              const SizedBox(height: 16),
              _buildStatsCard(provider),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionButton(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    
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
            width: 200,
            height: 200,
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
          // Spinner for connecting
          if (_isConnecting)
            SizedBox(
              width: 170,
              height: 170,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(buttonColor.withValues(alpha: 0.8)),
              ),
            ),
          // Main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 150,
            height: 150,
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
              child: _isConnecting
                  ? const SizedBox(
                      width: 45,
                      height: 45,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new,
                      size: 55,
                      color: Colors.white.withValues(alpha: isConnected ? 1.0 : 0.6),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(V2RayProvider provider) {
    final isConnected = provider.activeConfig != null;
    
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
                  fontSize: 34,
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
    if (provider.activeConfig != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('server_selector.connection_active'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context).translate('server_selector.disconnect_first'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).translate('common.ok'),
                style: const TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerSelectionScreen()));
    }
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
                    fontSize: smallFont ? 12 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!smallFont && value.contains(' ')) ...[
                const SizedBox(width: 2),
                Text(
                  value.split(' ').last,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
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
              Text(icon, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
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
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).translate('navigation.tools'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('home.quick_actions'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.4), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10b981).withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/images/apk.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 18),
          // App Name
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700),
              children: const [
                TextSpan(text: 'Tiksar', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'VPN', style: TextStyle(color: Color(0xFFa78bfa))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10b981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10b981).withValues(alpha: 0.3)),
            ),
            child: Text(
              'v1.1.2',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Description
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              AppLocalizations.of(context).translate('about.about_description'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Developer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFf472b6).withValues(alpha: 0.1),
                  const Color(0xFFa78bfa).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFf472b6).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).translate('about.developed_with'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.favorite, color: Color(0xFFf472b6), size: 16),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).translate('about.developer'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Social Links
          _buildSocialLink(
            icon: Icons.send_rounded,
            title: AppLocalizations.of(context).translate('about.telegram'),
            subtitle: '@tiksar_vpn',
            color: const Color(0xFF0088CC),
            url: 'https://t.me/tiksar_vpn',
          ),
          const SizedBox(height: 10),
          _buildSocialLink(
            icon: Icons.camera_alt_rounded,
            title: AppLocalizations.of(context).translate('about.instagram'),
            subtitle: '@aboljahany',
            color: const Color(0xFFE1306C),
            url: 'https://instagram.com/aboljahany',
          ),
          const SizedBox(height: 28),
          // Copyright
          Text(
            AppLocalizations.of(context).translate('about.copyright'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSocialLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String url,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.3), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF121214).withValues(alpha: 0.9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
            color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
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
