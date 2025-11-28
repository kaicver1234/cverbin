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
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
    _tabController.dispose();
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).translate('server_selection.servers_updated')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error refreshing servers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).translate('server_selection.error_updating')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Free Servers Tab
                      _buildFreeServersTab(),
                      // Premium Servers Tab
                      _buildPremiumTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Top row: Back button and title
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('server_selection.title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).translate('server_selection.select_server'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tab Bar (Free / Premium)
          _buildTabBar(),
          // Action buttons (only show for Free tab)
          if (_currentTab == 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRefreshButton(),
                const SizedBox(width: 10),
                Expanded(child: _buildPingTestButtonSmall(context)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).translate('server_selection.free')),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).translate('server_selection.premium')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingTestButtonSmall(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _isTesting
            ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
            : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isTesting ? null : _testAllServerPings,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTesting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.speed, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  _isTesting ? '...' : AppLocalizations.of(context).translate('server_selection.test_ping'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: _isRefreshing
            ? LinearGradient(colors: [
                const Color(0xFF10B981).withValues(alpha: 0.3),
                const Color(0xFF059669).withValues(alpha: 0.2),
              ])
            : null,
        color: _isRefreshing ? null : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRefreshing
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: IconButton(
        icon: RotationTransition(
          turns: _refreshAnimController,
          child: Icon(
            Icons.refresh,
            color: _isRefreshing ? const Color(0xFF10B981) : Colors.white,
            size: 20,
          ),
        ),
        onPressed: _isRefreshing ? null : _refreshServers,
        tooltip: 'Refresh servers',
      ),
    );
  }



  Widget _buildFreeServersTab() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingServers) return _buildLoadingState();
        final configs = _sortedConfigs ?? provider.configs;
        if (configs.isEmpty) return _buildEmptyState(context);
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                    const Color(0xFFFFA500).withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 64,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).translate('server_selection.premium'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).translate('server_selection.coming_soon'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('server_selection.coming_soon_desc'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context, V2RayProvider provider, List<V2RayConfig> configs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      physics: const ClampingScrollPhysics(),
      itemCount: configs.length,
      itemBuilder: (context, index) {
        final config = configs[index];
        if (config.isSmartConnect) {
          return _buildSmartConnectCard(context, provider, config);
        }
        final isSelected = !provider.wasUsingSmartConnect && provider.selectedConfig?.id == config.id;
        return _buildServerCard(context, provider, config, isSelected);
      },
    );
  }

  Widget _buildSmartConnectCard(BuildContext context, V2RayProvider provider, V2RayConfig config) {
    final isSelected = provider.wasUsingSmartConnect;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [const Color(0xFF10B981).withValues(alpha: 0.2), const Color(0xFF059669).withValues(alpha: 0.15)]
              : [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(config);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/apk.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        AppLocalizations.of(context).translate('server_selection.smart_connect_description'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.3), size: 14),
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
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.selectConfig(config);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _buildCountryFlag(countryCode),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cleanServerName(config.remark),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ping != null) _buildPingIndicator(ping),
                const SizedBox(width: 8),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.25), size: 12),
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
        width: 36,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.public, color: Colors.white, size: 16),
      );
    }
    return Container(
      width: 36,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: 'https://flagcdn.com/w80/${countryCode.toLowerCase()}.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          placeholder: (context, url) => const Center(
            child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white)),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.public, color: Colors.white, size: 16),
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
      pingColor = const Color(0xFF10B981);
      pingText = '${ping}ms';
    } else if (ping < 2000) {
      pingColor = Colors.orange;
      pingText = '${ping}ms';
    } else {
      pingColor = Colors.red;
      pingText = '${ping}ms';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: pingColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(pingText, style: TextStyle(color: pingColor, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF10B981)),
          SizedBox(height: 16),
          Text('Loading servers...', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.dns_outlined, size: 64, color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isRefreshing ? null : _refreshServers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return remark.replaceAll(RegExp(r'^\[([A-Z]{2})\]\s*'), '').trim();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('server_selection.no_servers_available')),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    final Map<String, int> results = {};
    int successCount = 0;
    int failCount = 0;
    
    try {
      for (int i = 0; i < configs.length; i++) {
        if (!mounted) return;
        final config = configs[i];
        try {
          debugPrint('🔍 Testing server ${i + 1}/${configs.length}: ${config.remark}');
          final ping = await provider.v2rayService.getServerDelay(config);
          if (!mounted) return;
          final pingValue = ping ?? 99999;
          results[config.id] = pingValue;
          if (pingValue < 99999) {
            successCount++;
          } else {
            failCount++;
          }
          setState(() => _pingResults = Map.from(results));
          debugPrint('✅ Server ${config.remark}: ${ping ?? "timeout"}ms');
        } catch (e) {
          debugPrint('❌ Error testing ${config.remark}: $e');
          results[config.id] = 99999;
          failCount++;
          if (mounted) setState(() => _pingResults = Map.from(results));
        }
      }

      if (!mounted) return;
      _sortServersByPing(provider, results);
      setState(() => _pingResults = results);

      final String message;
      final Color bgColor;
      if (successCount == 0) {
        message = AppLocalizations.of(context).translate('server_selection.all_servers_timeout');
        bgColor = Colors.orange;
      } else if (failCount > 0) {
        message = '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})';
        bgColor = const Color(0xFF10B981);
      } else {
        message = AppLocalizations.of(context).translate('server_selection.servers_updated');
        bgColor = const Color(0xFF10B981);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error testing server pings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('server_selection.error_updating')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
    final sortedList = [smartConnect, ...serverConfigs];
    setState(() => _sortedConfigs = sortedList);
    debugPrint('🔄 Sorted ${serverConfigs.length} servers by ping speed');
  }
}
