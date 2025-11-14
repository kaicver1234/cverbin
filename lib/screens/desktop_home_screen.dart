import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/desktop_vpn_provider.dart';
import '../providers/language_provider.dart';
import '../utils/app_localizations.dart';
import '../models/connection_mode.dart';
import '../services/windows_proxy_service.dart';

class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({Key? key}) : super(key: key);

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  int _selectedNavIndex = 0;
  ConnectionMode _connectionMode = ConnectionMode.vpn;
  
  @override
  void initState() {
    super.initState();
    debugPrint('💻 DesktopHomeScreen: initState');
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, localizations),
                        const SizedBox(height: 32),
                        
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
                                  _buildModeSelector(localizations),
                                  const SizedBox(height: 20),
                                  _buildStatsPanel(context, vpnProvider, localizations),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeSelector(AppLocalizations localizations) {
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
              const Text(
                'Connection Mode',
                style: TextStyle(
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
            'VPN Mode',
            'Full system VPN protection',
            const Color(0xFF00FF87),
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            ConnectionMode.proxy,
            Icons.lan_rounded,
            'Proxy Mode',
            'System-wide proxy',
            const Color(0xFF667EEA),
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
  ) {
    final isSelected = _connectionMode == mode;
    
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
          onTap: () => setState(() => _connectionMode = mode),
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
    return Container(
      width: 280,
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
                      const Text(
                        'Tiksar VPN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Windows v1.1.1',
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
          
          _buildNavItem(Icons.home_rounded, 'Home', 0),
          _buildNavItem(Icons.dns_rounded, 'Servers', 1),
          _buildNavItem(Icons.settings_rounded, 'Settings', 2),
          _buildNavItem(Icons.info_rounded, 'About', 3),
          
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
        ? 'Connecting...'
        : (isConnected ? 'Connected' : 'Disconnected');
    
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
          
          _buildServerCard(context, vpnProvider, localizations),
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
        
        if (_connectionMode == ConnectionMode.proxy && isConnected)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF667EEA).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lan_rounded,
                  color: Color(0xFF667EEA),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Proxy Mode Active',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                  isConnected ? 'Disconnect' : 'Connect',
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

  Widget _buildServerCard(BuildContext context, DesktopVpnProvider vpnProvider, AppLocalizations localizations) {
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
                  'Current Server',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vpnProvider.selectedServer ?? 'No server selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          IconButton(
            onPressed: () => _showServerDialog(context, vpnProvider),
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
              const Text(
                'Connection Stats',
                style: TextStyle(
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
            'Upload',
            _formatSpeed(vpnProvider.uploadSpeed),
            const Color(0xFF72D9FF),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            Icons.download_rounded,
            'Download',
            _formatSpeed(vpnProvider.downloadSpeed),
            const Color(0xFF76F959),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            Icons.timer_rounded,
            'Duration',
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
      if (_connectionMode == ConnectionMode.proxy) {
        await WindowsProxyService.disableSystemProxy();
      }
      await vpnProvider.disconnect();
    } else {
      if (vpnProvider.selectedServer == null) {
        _showServerDialog(context, vpnProvider);
        return;
      }
      
      await vpnProvider.connect();
      
      if (_connectionMode == ConnectionMode.proxy) {
        await WindowsProxyService.enableSystemProxy(
          host: '127.0.0.1',
          port: 10808,
        );
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

  void _showServerDialog(BuildContext context, DesktopVpnProvider vpnProvider) {
    final servers = [
      'Germany - Frankfurt',
      'United States - New York',
      'United Kingdom - London',
      'Singapore',
      'Japan - Tokyo',
      'France - Paris',
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Select Server',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: servers.length,
            itemBuilder: (context, index) {
              final server = servers[index];
              final isSelected = vpnProvider.selectedServer == server;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF667EEA).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF667EEA)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF667EEA),
                  ),
                  title: Text(
                    server,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF667EEA),
                        )
                      : null,
                  onTap: () {
                    vpnProvider.selectServer(server);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
