import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen>
    with TickerProviderStateMixin {
  bool _isTesting = false;
  bool _isRefreshing = false;
  Map<String, int> _pingResults = {};
  List<V2RayConfig>? _sortedConfigs;
  late AnimationController _refreshAnimController;
  int _currentTab = 0; // 0 = Free, 1 = Premium

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _sortedConfigs = null;
    _pingResults.clear();
    super.dispose();
  }

  Future<void> _refreshServers() async {
    if (_isRefreshing || !mounted) return;
    
    setState(() => _isRefreshing = true);
    _refreshAnimController.repeat();
    
    try {
      final provider = Provider.of<V2RayProvider>(context, listen: false);
      await provider.fetchServers(
        customUrl: 'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub2.txt',
      );
      
      if (mounted) {
        setState(() {
          _sortedConfigs = null;
          _pingResults.clear();
        });
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.servers_updated'),
          const Color(0xFF10B981),
        );
      }
    } catch (e) {
      debugPrint('❌ Error refreshing servers: $e');
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.error_updating'),
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        _refreshAnimController.stop();
        _refreshAnimController.reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1629), Color(0xFF0A0E1A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabButtons(),
                if (_currentTab == 0) _buildActionButtons(),
                Expanded(
                  child: _currentTab == 0 
                      ? _buildFreeServersTab() 
                      : _buildPremiumTab(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).translate('server_selection.title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context).translate('server_selection.select_server'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Free Tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _currentTab == 0
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : null,
                    color: _currentTab == 0 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.public,
                        color: _currentTab == 0 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.free'),
                        style: TextStyle(
                          color: _currentTab == 0 
                              ? Colors.white 
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Premium Tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _currentTab == 1
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          )
                        : null,
                    color: _currentTab == 1 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: _currentTab == 1 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.premium'),
                        style: TextStyle(
                          color: _currentTab == 1 
                              ? Colors.white 
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Refresh button
          GestureDetector(
            onTap: _isRefreshing ? null : _refreshServers,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RotationTransition(
                turns: _refreshAnimController,
                child: Icon(
                  Icons.refresh,
                  color: _isRefreshing 
                      ? const Color(0xFF10B981) 
                      : Colors.white.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Test Ping button
          GestureDetector(
            onTap: _isTesting ? null : _testAllServerPings,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isTesting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.speed, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isTesting 
                        ? '...' 
                        : AppLocalizations.of(context).translate('server_selection.test_ping'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeServersTab() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingServers) return _buildLoadingState();
        
        List<V2RayConfig> configs;
        if (_sortedConfigs != null) {
          configs = _sortedConfigs!;
        } else {
          final smartConnect = V2RayConfig.smartConnect();
          configs = [smartConnect, ...provider.configs];
        }
        
        if (configs.length <= 1) return _buildEmptyState(context);
        return _buildServerList(context, provider, configs);
      },
    );
  }

  Widget _buildPremiumTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.15),
                    const Color(0xFFFFA500).withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 56,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).translate('server_selection.premium'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('server_selection.coming_soon'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, V2RayProvider provider, List<V2RayConfig> configs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        if (config.isSmartConnect) {
          return _buildSmartConnectCard(context, provider);
        }
        final isSelected = !provider.wasUsingSmartConnect && 
            provider.selectedConfig?.id == config.id;
        return _buildServerCard(context, provider, config, isSelected);
      },
    );
  }

  Widget _buildSmartConnectCard(BuildContext context, V2RayProvider provider) {
    final isSelected = provider.wasUsingSmartConnect;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF10B981).withValues(alpha: 0.5) 
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(V2RayConfig.smartConnect());
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // VPN Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/apk.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.vpn_key,
                          color: Color(0xFF10B981),
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect_description'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerCard(BuildContext context, V2RayProvider provider, V2RayConfig config, bool isSelected) {
    final countryCode = config.countryCode ?? _extractCountryCode(config.remark);
    final ping = _pingResults[config.id];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF10B981).withValues(alpha: 0.5) 
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(config);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Country Flag
                _buildCountryFlag(countryCode),
                const SizedBox(width: 14),
                // Server Name
                Expanded(
                  child: Text(
                    _cleanServerName(config.remark),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Ping indicator
                if (ping != null) ...[
                  _buildPingIndicator(ping),
                  const SizedBox(width: 10),
                ],
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryFlag(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) {
      return Container(
        width: 40,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.public, color: Colors.white54, size: 18),
      );
    }
    
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: 'https://flagcdn.com/w80/${countryCode.toLowerCase()}.png',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.white.withValues(alpha: 0.1),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.white.withValues(alpha: 0.1),
            child: const Icon(Icons.flag, color: Colors.white54, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildPingIndicator(int ping) {
    Color pingColor;
    String pingText;
    
    if (ping > 9999) {
      pingColor = Colors.red;
      pingText = '---';
    } else if (ping < 1000) {
      // 1-999ms: سبز
      pingColor = const Color(0xFF10B981);
      pingText = '${ping}ms';
    } else if (ping < 2000) {
      // 1000-1999ms: نارنجی
      pingColor = Colors.orange;
      pingText = '${ping}ms';
    } else {
      // 2000ms+: قرمز
      pingColor = Colors.red;
      pingText = '${ping}ms';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pingColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        pingText,
        style: TextStyle(
          color: pingColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('common.loading_servers'),
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _refreshServers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractCountryCode(String remark) {
    final regex = RegExp(r'\[([A-Z]{2})\]');
    final match = regex.firstMatch(remark);
    return match?.group(1);
  }

  String _cleanServerName(String remark) {
    // Remove country code patterns: [CC], (CC), CC-
    String clean = remark;
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Z]{2}[\]\)]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^[A-Z]{2}[-\s]+'), '');
    return clean.trim().isEmpty ? remark : clean.trim();
  }

  Future<void> _testAllServerPings() async {
    if (_isTesting || !mounted) return;
    setState(() {
      _isTesting = true;
      _pingResults.clear();
    });

    V2RayProvider? provider;
    try {
      provider = Provider.of<V2RayProvider>(context, listen: false);
    } catch (e) {
      debugPrint('❌ Could not get provider: $e');
      if (mounted) setState(() => _isTesting = false);
      return;
    }
    
    final configs = provider.serverConfigs;
    if (configs.isEmpty) {
      if (mounted) {
        setState(() => _isTesting = false);
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.no_servers_available'),
          Colors.orange,
        );
      }
      return;
    }

    final Map<String, int> results = {};
    int successCount = 0;
    
    try {
      for (int i = 0; i < configs.length; i++) {
        if (!mounted) return;
        final config = configs[i];
        try {
          debugPrint('🔍 Testing ${i + 1}/${configs.length}: ${config.remark}');
          final ping = await provider.v2rayService.getServerDelay(config);
          if (!mounted) return;
          final pingValue = ping ?? 99999;
          results[config.id] = pingValue;
          if (pingValue < 99999) successCount++;
          setState(() => _pingResults = Map.from(results));
        } catch (e) {
          results[config.id] = 99999;
          if (mounted) setState(() => _pingResults = Map.from(results));
        }
      }

      if (!mounted) return;
      _sortServersByPing(provider, results);

      _showSnackBar(
        '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})',
        const Color(0xFF10B981),
      );
    } catch (e) {
      debugPrint('❌ Error testing pings: $e');
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.error_updating'),
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _sortServersByPing(V2RayProvider provider, Map<String, int> pingResults) {
    final smartConnect = V2RayConfig.smartConnect();
    final serverConfigs = List<V2RayConfig>.from(provider.serverConfigs);
    serverConfigs.sort((a, b) {
      final pingA = pingResults[a.id] ?? 99999;
      final pingB = pingResults[b.id] ?? 99999;
      return pingA.compareTo(pingB);
    });
    setState(() => _sortedConfigs = [smartConnect, ...serverConfigs]);
  }
}
