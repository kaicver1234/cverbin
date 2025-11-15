import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/desktop_vpn_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../models/connection_mode.dart';
import '../models/v2ray_config.dart';
import '../services/windows_proxy_service.dart';
import '../services/windows_v2ray_service.dart';
import '../services/windows_tun_service.dart';
import '../services/server_service.dart';

class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({Key? key}) : super(key: key);

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  int _selectedNavIndex = 0;
  ConnectionMode _connectionMode = ConnectionMode.vpn;
  List<V2RayConfig> _servers = [];
  bool _isLoadingServers = false;
  Timer? _statsTimer;
  
  @override
  void initState() {
    super.initState();
    debugPrint('💻 DesktopHomeScreen: initState');
    _loadServers();
    _checkAdminRights();
  }
  
  Future<void> _checkAdminRights() async {
    final hasAdmin = await WindowsTunService.checkAdminRights();
    if (!hasAdmin && mounted) {
      // Show warning that VPN mode requires admin
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Run as Administrator for true VPN mode'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadServers() async {
    setState(() => _isLoadingServers = true);
    try {
      final serverService = ServerService();
      final servers = await serverService.fetchServers(
        customUrl: ServerService.defaultServerUrl,
      );
      setState(() {
        _servers = servers;
        _isLoadingServers = false;
      });
      debugPrint('✅ Loaded ${servers.length} servers');
    } catch (e) {
      debugPrint('❌ Error loading servers: $e');
      setState(() => _isLoadingServers = false);
    }
  }
  
  void _startStatsMonitoring(DesktopVpnProvider provider) {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (WindowsV2rayService.isRunning) {
        provider.updateStats(
          WindowsV2rayService.uploadSpeed,
          WindowsV2rayService.downloadSpeed,
          _formatDuration(timer.tick),
        );
      }
    });
  }
  
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('💻 DesktopHomeScreen: build');
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DesktopVpnProvider()),
      ],
      child: Consumer2<DesktopVpnProvider, LanguageProvider>(
        builder: (context, vpnProvider, languageProvider, child) {
          final localizations = AppLocalizations.of(context);
          
          return Scaffold(
            backgroundColor: const Color(0xFF0A0E1A),
            body: Row(
              children: [
                _buildSidebar(context, localizations),
                Expanded(
                  child: _selectedNavIndex == 0
                      ? _buildHomeContent(context, vpnProvider, localizations)
                      : _selectedNavIndex == 1
                          ? _buildServersContent(context, vpnProvider, localizations)
                          : _selectedNavIndex == 2
                              ? _buildSettingsContent(context, localizations)
                              : _buildAboutContent(context, localizations),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildHomeContent(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth * 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, localizations),
              const SizedBox(height: 32),
              
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildMainPanel(context, vpnProvider, localizations),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildModeSelector(localizations, vpnProvider),
                          const SizedBox(height: 20),
                          _buildStatsPanel(context, vpnProvider, localizations),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildMainPanel(context, vpnProvider, localizations),
                    const SizedBox(height: 24),
                    _buildModeSelector(localizations, vpnProvider),
                    const SizedBox(height: 20),
                    _buildStatsPanel(context, vpnProvider, localizations),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildServersContent(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.translate('desktop.available_servers'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _loadServers,
                icon: const Icon(Icons.refresh_rounded),
                color: Colors.white,
                iconSize: 28,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isLoadingServers)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_servers.isEmpty)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    localizations.translate('desktop.no_servers_available'),
                    style: const TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadServers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _servers.length,
              itemBuilder: (context, index) {
                final server = _servers[index];
                final isSelected = vpnProvider.selectedServerConfig?.id == server.id;
                
                return _buildServerCard(server, isSelected, vpnProvider);
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildServerCard(V2RayConfig server, bool isSelected, DesktopVpnProvider vpnProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF667EEA) : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => vpnProvider.selectServerConfig(server),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF667EEA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: isSelected ? Colors.white : const Color(0xFF667EEA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        server.remark,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${server.address}:${server.port}',
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsContent(BuildContext context, AppLocalizations localizations) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('common.settings'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          
          // Language Settings - Only essential setting
          _buildSettingCard(
            localizations.translate('language_settings.title'),
            Icons.language_rounded,
            [
              _buildLanguageSelector(context, languageProvider, localizations),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLanguageSelector(BuildContext context, LanguageProvider languageProvider, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.translate('language_settings.current_language'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        
        ...languageProvider.supportedLanguages.map((language) {
          final isSelected = languageProvider.currentLanguage.code == language.code;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF667EEA)
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (!isSelected) {
                    await languageProvider.changeLanguage(language);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.translate('language_settings.language_changed')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        language.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          language.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildSettingCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
  

  
  Widget _buildAboutContent(BuildContext context, AppLocalizations localizations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('desktop.about_tiksar'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          
          Center(
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
                ),
                const SizedBox(height: 24),
                Text(
                  localizations.translate('app.title'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('common.windows_version'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
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
                        localizations.translate('common.welcome_subtitle'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizations.translate('desktop.about_description'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
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
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Developed with',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'in Iran',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Abol Jahany',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Connect with us:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildSocialButton(
                      icon: Icons.telegram,
                      label: 'Telegram',
                      gradient: const [Color(0xFF0088CC), Color(0xFF00A0E3)],
                      onTap: () => _launchUrl('https://t.me/tiksar_vpn'),
                    ),
                    _buildSocialButton(
                      icon: Icons.camera_alt,
                      label: 'Instagram',
                      gradient: const [Color(0xFFE1306C), Color(0xFFF56040)],
                      onTap: () => _launchUrl('https://instagram.com/aboljahany'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  '© 2024 Tiksar VPN. All rights reserved.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
            Icon(icon, color: Colors.white, size: 24),
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
    );
  }
  
  Future<void> _launchUrl(String url) async {
    // For Windows, we can use Process.run to open URLs
    try {
      await Process.run('cmd', ['/c', 'start', url]);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildModeSelector(AppLocalizations localizations, DesktopVpnProvider vpnProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F2E), Color(0xFF0F131E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                localizations.translate('common.connection_mode'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildModeOption(
            ConnectionMode.vpn,
            Icons.vpn_lock_rounded,
            localizations.translate('common.vpn_mode'),
            localizations.translate('common.vpn_mode_desc'),
            const Color(0xFF00FF87),
            vpnProvider,
            requiresAdmin: false,
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            ConnectionMode.proxy,
            Icons.lan_rounded,
            localizations.translate('common.proxy_mode'),
            localizations.translate('common.proxy_mode_desc'),
            const Color(0xFF667EEA),
            vpnProvider,
            requiresAdmin: false,
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    ConnectionMode mode,
    IconData icon,
    String title,
    String description,
    Color accentColor,
    DesktopVpnProvider vpnProvider, {
    bool requiresAdmin = false,
  }) {
    final isSelected = _connectionMode == mode;
    final isDisabled = vpnProvider.isConnected;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  accentColor.withOpacity(0.3),
                  accentColor.withOpacity(0.1),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : () {
            setState(() => _connectionMode = mode);
            vpnProvider.setConnectionMode(mode);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? accentColor : Colors.white.withOpacity(0.6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: accentColor,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, AppLocalizations localizations) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1200 ? 240.0 : 280.0;
    
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1F2E),
            Color(0xFF0F131E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.vpn_lock_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('app.title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        localizations.translate('common.windows_version'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1E2433), thickness: 1),
          const SizedBox(height: 20),
          
          _buildNavItem(Icons.home_rounded, localizations.translate('nav.home'), 0),
          _buildNavItem(Icons.dns_rounded, localizations.translate('nav.servers'), 1),
          _buildNavItem(Icons.settings_rounded, localizations.translate('nav.settings'), 2),
          _buildNavItem(Icons.info_rounded, localizations.translate('nav.about'), 3),
          
          const Spacer(),
          
          const Divider(color: Color(0xFF1E2433), thickness: 1),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Made with ❤️ in Iran',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _selectedNavIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedNavIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Tiksar VPN',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fast, Secure, and Free VPN for Windows',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.computer_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Windows',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
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

  Widget _buildMainPanel(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
    final isConnected = vpnProvider.isConnected;
    final isConnecting = vpnProvider.isConnecting;
    final status = isConnecting 
        ? localizations.translate('home.connecting')
        : (isConnected 
            ? localizations.translate('home.connected') 
            : localizations.translate('home.disconnected'));
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected 
            ? [const Color(0xFF1A3A2E), const Color(0xFF0F2922)]
            : [const Color(0xFF1A1F2E), const Color(0xFF0F131E)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnected 
            ? const Color(0xFF00FF87).withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected 
              ? const Color(0xFF00FF87).withOpacity(0.2)
              : Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          _buildStatusIndicator(isConnected, isConnecting, status),
          
          const SizedBox(height: 40),
          
          _buildConnectionButton(context, vpnProvider, localizations, isConnected, isConnecting),
          
          const SizedBox(height: 32),
          
          _buildCurrentServerCard(context, vpnProvider, localizations),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isConnected, bool isConnecting, String status) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isConnected 
                    ? [
                        const Color(0xFF00FF87).withOpacity(0.3),
                        const Color(0xFF00FF87).withOpacity(0.0),
                      ]
                    : [
                        const Color(0xFF667EEA).withOpacity(0.3),
                        const Color(0xFF667EEA).withOpacity(0.0),
                      ],
                ),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              duration: 2.seconds,
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.05, 1.05),
            ),
            
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isConnected 
                    ? [const Color(0xFF00FF87), const Color(0xFF60EFFF)]
                    : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isConnected 
                      ? const Color(0xFF00FF87).withOpacity(0.5)
                      : const Color(0xFF667EEA).withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: isConnecting
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    isConnected ? Icons.verified_user_rounded : Icons.shield_outlined,
                    color: Colors.white,
                    size: 64,
                  ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          ],
        ),
        
        const SizedBox(height: 32),
        
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isConnected 
              ? [const Color(0xFF00FF87), const Color(0xFF60EFFF)]
              : [const Color(0xFF667EEA), const Color(0xFFB06AB3)],
          ).createShader(bounds),
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          isConnected 
            ? 'Your connection is secure and encrypted'
            : 'Connect to secure your connection',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        if (isConnected)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _connectionMode == ConnectionMode.vpn
                  ? const Color(0xFF00FF87).withOpacity(0.15)
                  : const Color(0xFF667EEA).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _connectionMode == ConnectionMode.vpn
                    ? const Color(0xFF00FF87).withOpacity(0.3)
                    : const Color(0xFF667EEA).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _connectionMode == ConnectionMode.vpn
                      ? Icons.vpn_lock_rounded
                      : Icons.lan_rounded,
                  color: _connectionMode == ConnectionMode.vpn
                      ? const Color(0xFF00FF87)
                      : const Color(0xFF667EEA),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _connectionMode == ConnectionMode.vpn
                        ? 'True VPN - All system traffic routed'
                        : 'HTTP Proxy - Browsers only',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

      ],
    );
  }

  Widget _buildConnectionButton(
    BuildContext context,
    DesktopVpnProvider vpnProvider,
    AppLocalizations localizations,
    bool isConnected,
    bool isConnecting,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: isConnecting ? null : () => _handleConnection(vpnProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isConnected 
                ? [const Color(0xFFE72E44), const Color(0xFFB91C1C)]
                : [const Color(0xFF00FF87), const Color(0xFF60EFFF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isConnected 
                  ? const Color(0xFFE72E44).withOpacity(0.4)
                  : const Color(0xFF00FF87).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.power_off_rounded : Icons.power_settings_new_rounded,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  isConnected 
                      ? localizations.translate('home.disconnect') 
                      : localizations.translate('home.connect'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }

  Widget _buildCurrentServerCard(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.all(24),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dns_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('common.current_server'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vpnProvider.selectedServerConfig?.remark ?? localizations.translate('common.no_server_selected'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          IconButton(
            onPressed: () => setState(() => _selectedNavIndex = 1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white.withOpacity(0.8),
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F2E), Color(0xFF0F131E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                localizations.translate('common.connection_stats'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildStatRow(
            Icons.upload_rounded,
            localizations.translate('home.upload'),
            _formatSpeed(vpnProvider.uploadSpeed),
            const Color(0xFF72D9FF),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            Icons.download_rounded,
            localizations.translate('home.download'),
            _formatSpeed(vpnProvider.downloadSpeed),
            const Color(0xFF76F959),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            Icons.timer_rounded,
            localizations.translate('home.duration'),
            vpnProvider.duration,
            const Color(0xFFFFAA66),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleConnection(DesktopVpnProvider vpnProvider) async {
    if (vpnProvider.isConnected) {
      _statsTimer?.cancel();
      
      // Stop based on mode
      if (_connectionMode == ConnectionMode.vpn) {
        // Stop TUN mode
        await WindowsTunService.stopTunMode();
        await WindowsTunService.disableSystemRouting();
      } else {
        // Stop proxy mode
        await WindowsProxyService.disableSystemProxy();
      }
      
      await WindowsV2rayService.stopV2ray();
      await vpnProvider.disconnect();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (vpnProvider.selectedServerConfig == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a server first'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _selectedNavIndex = 1);
        return;
      }
      
      // Check admin rights for VPN mode
      if (_connectionMode == ConnectionMode.vpn) {
        final hasAdmin = await WindowsTunService.checkAdminRights();
        if (!hasAdmin) {
          vpnProvider.setConnecting(false);
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Administrator Rights Required'),
                content: const Text(
                  'True VPN mode requires administrator privileges to route all system traffic.\n\n'
                  'Please:\n'
                  '1. Close this app\n'
                  '2. Right-click on the app\n'
                  '3. Select "Run as administrator"\n\n'
                  'Or use Proxy mode which works without admin rights.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
      
      vpnProvider.setConnecting(true);
      
      try {
        final config = vpnProvider.selectedServerConfig!.fullConfig;
        
        bool success = false;
        
        if (_connectionMode == ConnectionMode.vpn) {
          // True VPN Mode: Routes ALL system traffic
          success = await WindowsTunService.startTunMode(config);
          if (success) {
            await WindowsTunService.enableSystemRouting();
          }
        } else {
          // Proxy Mode: Only browsers and apps that respect proxy
          success = await WindowsV2rayService.startV2ray(config);
          if (success) {
            await WindowsProxyService.enableSystemProxy(
              host: '127.0.0.1',
              port: 10809,
              isSocks: false,
            );
          }
        }
        
        if (success) {
          await vpnProvider.connect();
          _startStatsMonitoring(vpnProvider);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _connectionMode == ConnectionMode.vpn
                      ? 'Connected - True VPN Mode (All traffic)'
                      : 'Connected - Proxy Mode (Browsers only)'
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          vpnProvider.setConnecting(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connection failed'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        vpnProvider.setConnecting(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().substring(0, 50)}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
  
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }
}
