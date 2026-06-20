import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../models/subscription.dart';
import '../utils/app_localizations.dart';
import '../utils/country_flags.dart';
import '../utils/responsive_helper.dart';
import '../widgets/app_background.dart';
import '../widgets/wave_loading.dart';
import '../services/analytics_service.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen>
    with TickerProviderStateMixin {
  bool _isTesting = false;
  bool _isRefreshing = false;
  final Map<String, int> _pingResults = {};
  List<V2RayConfig>? _sortedConfigs;
  late AnimationController _refreshAnimController;
  late TabController _tabController;

  String _testStatusText = '';
  int _totalCount = 0;
  int _batchSize = 10;

  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Entekhab_Server');
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _activeTabIndex != _tabController.index) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadBatchSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadFlags();
    });
  }

  Future<void> _loadBatchSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('ping_batch_size') ?? 8;
      if (mounted) setState(() => _batchSize = saved.clamp(1, 16));
    } catch (_) {}
  }

  Future<void> _preloadFlags() async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final codes = provider.serverConfigs
        .map((c) => c.countryCode)
        .where((code) => code != null && CountryFlags.isValidCountryCode(code))
        .toSet();

    for (final code in codes) {
      if (!mounted) break;
      try {
        await precacheImage(
          CachedNetworkImageProvider(CountryFlags.getFlagUrl(code)),
          context,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      await provider.fetchServers();
      if (mounted) {
        AnalyticsService().logServerListRefresh(serverCount: provider.serverConfigs.length);
        setState(() {
          _sortedConfigs = null;
          _pingResults.clear();
        });
        _showSnackBar(
          provider.errorMessage.isEmpty
              ? AppLocalizations.of(context).translate('server_selection.servers_updated')
              : provider.errorMessage,
          provider.errorMessage.isEmpty ? const Color(0xFF00FFA3) : Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to refresh', Colors.red);
    } finally {
      if (mounted) {
        _refreshAnimController
          ..stop()
          ..reset();
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
    final responsive = ResponsiveHelper(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
              child: Column(
            children: [
              _buildHeader(context, responsive),
              _buildTabBar(responsive),
              if (_activeTabIndex == 0)
                _buildActionToolbar(responsive),
              if (_activeTabIndex == 2)
                _buildMyServersToolbar(responsive),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildFreeTab(),
                    _buildPremiumTab(context),
                    _buildMyServersTab(),
                  ],
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        responsive.scale(12).clamp(8.0, 18.0),
        responsive.horizontalPadding,
        responsive.scale(12).clamp(8.0, 18.0),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: responsive.scale(44).clamp(38.0, 52.0),
              height: responsive.scale(44).clamp(38.0, 52.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, langProvider, _) => Icon(
                  langProvider.isRtl
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: responsive.scale(18).clamp(15.0, 22.0),
                ),
              ),
            ),
          ),
          SizedBox(width: responsive.scale(14).clamp(10.0, 18.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('server_selection.title'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.scale(22).clamp(18.0, 28.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Consumer<V2RayProvider>(
                  builder: (context, provider, _) => Text(
                    '${provider.configs.length} ${AppLocalizations.of(context).translate('server_selection.select_server')}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: responsive.scale(12).clamp(10.0, 14.0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: Container(
        height: responsive.scale(46).clamp(40.0, 56.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            _buildTabButton(
              label: AppLocalizations.of(context).translate('server_selection.free'),
              icon: Icons.public_rounded,
              isActive: _activeTabIndex == 0,
              onTap: () => _tabController.animateTo(0),
              responsive: responsive,
            ),
            _buildTabButton(
              label: AppLocalizations.of(context).translate('server_selection.premium'),
              icon: Icons.diamond_rounded,
              isActive: _activeTabIndex == 1,
              onTap: () => _tabController.animateTo(1),
              responsive: responsive,
            ),
            _buildTabButton(
              label: AppLocalizations.of(context).translate('server_selection.my_servers'),
              icon: Icons.bookmark_rounded,
              isActive: _activeTabIndex == 2,
              onTap: () => _tabController.animateTo(2),
              responsive: responsive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required ResponsiveHelper responsive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF1a1a1a), Color(0xFF2a2a2a)],
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: Colors.white.withValues(alpha: 0.15))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                size: responsive.scale(16).clamp(14.0, 20.0),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  fontSize: responsive.scale(13).clamp(11.0, 16.0),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionToolbar(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        0,
        responsive.horizontalPadding,
        10,
      ),
      child: Row(
        children: [
          // Primary action: Test Ping
          Expanded(child: _buildPingActionBtn(responsive)),
          const SizedBox(width: 8),
          // Refresh server list
          _ToolbarIconButton(
            icon: Icons.refresh_rounded,
            tooltip: AppLocalizations.of(context)
                .translate('server_selection.refresh'),
            color: Colors.white,
            enabled: !_isRefreshing,
            spinning: _isRefreshing,
            animController: _refreshAnimController,
            onTap: _isRefreshing ? null : _refreshServers,
            responsive: responsive,
          ),
        ],
      ),
    );
  }

  Widget _buildPingActionBtn(ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: _isTesting ? null : _testAllServerPings,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: responsive.scale(44).clamp(38.0, 54.0),
        decoration: BoxDecoration(
          gradient: _isTesting
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                ),
          color: _isTesting ? Colors.white.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isTesting
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFF00D9FF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isTesting) ...[
              WaveLoading.small(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                _testStatusText.isNotEmpty ? _testStatusText : '...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: responsive.scale(13).clamp(11.0, 15.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const Icon(Icons.speed_rounded, color: Color(0xFF00D9FF), size: 16),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.of(context).translate('server_selection.test_ping'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.scale(13).clamp(11.0, 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTab() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingServers) return _buildLoadingState();

        final List<V2RayConfig> configs = _sortedConfigs != null
            ? _sortedConfigs!
            : [V2RayConfig.smartConnect(), ...provider.officialConfigs];

        if (configs.length <= 1) return _buildEmptyState();

        return ListView.builder(
          padding: EdgeInsets.only(
            left: ResponsiveHelper(context).horizontalPadding,
            right: ResponsiveHelper(context).horizontalPadding,
            top: 8,
            bottom: 24,
          ),
          physics: const ClampingScrollPhysics(),
          itemCount: configs.length,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final config = configs[index];
            if (config.isSmartConnect) {
              return _SmartConnectCard(
                provider: provider,
                onDisconnectFirst: () => _showDisconnectFirstDialog(context),
              );
            }
            final isSelected = !provider.wasUsingSmartConnect &&
                provider.selectedConfig?.id == config.id;
            return _ServerCard(
              config: config,
              isSelected: isSelected,
              ping: _pingResults[config.id],
              onTap: () {
                if (provider.activeConfig != null) {
                  _showDisconnectFirstDialog(context);
                } else {
                  provider.selectConfig(config);
                  Navigator.pop(context);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumTab(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium icon with gradient background
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow circle
                Container(
                  width: responsive.scale(140).clamp(110.0, 170.0),
                  height: responsive.scale(140).clamp(110.0, 170.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Middle circle
                Container(
                  width: responsive.scale(100).clamp(80.0, 120.0),
                  height: responsive.scale(100).clamp(80.0, 120.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.diamond_rounded,
                    size: responsive.scale(50).clamp(40.0, 60.0),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: responsive.scale(32).clamp(24.0, 40.0)),
            
            // Premium title
            Text(
              AppLocalizations.of(context).translate('server_selection.premium'),
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.scale(28).clamp(22.0, 34.0),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            
            SizedBox(height: responsive.scale(24).clamp(18.0, 30.0)),
            
            // Coming Soon badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.scale(24).clamp(18.0, 30.0),
                vertical: responsive.scale(12).clamp(10.0, 16.0),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    const Color(0xFFA855F7).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Text(
                AppLocalizations.of(context).translate('server_selection.coming_soon'),
                style: TextStyle(
                  color: const Color(0xFFA855F7),
                  fontSize: responsive.scale(14).clamp(12.0, 17.0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wave loading animation (shared, matches splash)
          const WaveLoading(),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('common.loading_servers'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final r = ResponsiveHelper(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: r.scale(56).clamp(40.0, 72.0), color: Colors.white.withValues(alpha: 0.2)),
          SizedBox(height: r.scale(16).clamp(10.0, 22.0)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
            child: Text(
              AppLocalizations.of(context).translate('server_selection.no_servers_available'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: r.scale(15).clamp(12.0, 18.0)),
            ),
          ),
          SizedBox(height: r.scale(20).clamp(14.0, 28.0)),
          GestureDetector(
            onTap: _refreshServers,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.scale(24).clamp(16.0, 32.0),
                vertical: r.scale(12).clamp(8.0, 16.0),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                'Refresh',
                style: TextStyle(color: Colors.white, fontSize: r.scale(14).clamp(12.0, 17.0), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisconnectFirstDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).translate('server_selector.connection_active'),
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).translate('server_selector.disconnect_first'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF00D9FF), fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testAllServerPings() async {
    if (_isTesting || !mounted) return;

    setState(() {
      _isTesting = true;
      _pingResults.clear();
      _sortedConfigs = null;
      _totalCount = 0;
      _testStatusText = '...';
    });

    final V2RayProvider provider;
    try {
      provider = Provider.of<V2RayProvider>(context, listen: false);
    } catch (_) {
      if (mounted) setState(() => _isTesting = false);
      return;
    }

    final configs = provider.officialConfigs;
    if (configs.isEmpty) {
      if (mounted) setState(() { _isTesting = false; _testStatusText = ''; });
      return;
    }

    try {
      setState(() {
        _totalCount = configs.length;
        _testStatusText = '0 / $_totalCount';
      });

      int successCount = 0;
      int completed = 0;
      int nextIndex = 0;

      Future<void> worker() async {
        while (mounted && _isTesting) {
          if (nextIndex >= configs.length) break;
          final idx = nextIndex++;

          final config = configs[idx];
          final delay = await _testSingleServer(config, provider);

          if (!mounted || !_isTesting) break;

          if (delay >= 0 && delay < 10000) {
            _pingResults[config.id] = delay;
            successCount++;
          } else {
            _pingResults[config.id] = -1;
          }
          completed++;

          if (mounted) {
            setState(() {
              _testStatusText = '$completed / $_totalCount';
              _sortServersByPing(provider, _pingResults);
            });
          }
        }
      }

      final workerCount = _batchSize.clamp(1, configs.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));

      if (!mounted) return;

      setState(() => _sortServersByPing(provider, _pingResults));
      _showSnackBar(
        '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})',
        const Color(0xFF00FFA3),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context).translate('server_selection.error_updating'),
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() { _isTesting = false; _testStatusText = ''; });
    }
  }

  Future<int> _testSingleServer(V2RayConfig config, V2RayProvider provider) async {
    try {
      // Use direct (uncached) ping for manual "Test all" so each tap reflects
      // real-time latency instead of stale 30s-cached values.
      final delay = await provider.v2rayService.getServerDelayDirect(config).timeout(
        const Duration(seconds: 6),
        onTimeout: () => -1,
      );
      return delay ?? -1;
    } catch (_) {
      return -1;
    }
  }

  void _sortServersByPing(V2RayProvider provider, Map<String, int> pingResults) {
    final servers = List<V2RayConfig>.from(provider.officialConfigs)
      ..sort((a, b) {
        final rawA = pingResults[a.id];
        final rawB = pingResults[b.id];
        final pA = (rawA == null || rawA < 0) ? 99999999 : rawA;
        final pB = (rawB == null || rawB < 0) ? 99999999 : rawB;
        return pA.compareTo(pB);
      });
    _sortedConfigs = [V2RayConfig.smartConnect(), ...servers];
  }

  // ─── My Servers tab ────────────────────────────────────────────────────────

  Widget _buildMyServersToolbar(ResponsiveHelper responsive) {
    final hasAny = context.select<V2RayProvider, bool>(
      (p) => p.userConfigs.isNotEmpty || p.userSubscriptions.isNotEmpty,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        0,
        responsive.horizontalPadding,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openAddMenu,
              child: Container(
                height: responsive.scale(44).clamp(38.0, 54.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: Color(0xFF00D9FF), size: 18),
                    const SizedBox(width: 7),
                    Text(
                      AppLocalizations.of(context)
                          .translate('server_selection.add_menu_title'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.scale(13).clamp(11.0, 15.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasAny) ...[
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _isTesting ? null : _testUserServerPings,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: responsive.scale(44).clamp(38.0, 54.0),
                  decoration: BoxDecoration(
                    color: _isTesting
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isTesting
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isTesting) ...[
                        WaveLoading.small(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _testStatusText.isNotEmpty
                              ? _testStatusText
                              : '...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize:
                                responsive.scale(13).clamp(11.0, 15.0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.speed_rounded,
                            color: Color(0xFF00D9FF), size: 16),
                        const SizedBox(width: 7),
                        Text(
                          AppLocalizations.of(context)
                              .translate('server_selection.test_ping'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize:
                                responsive.scale(13).clamp(11.0, 15.0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _testUserServerPings() async {
    if (_isTesting || !mounted) return;

    final V2RayProvider provider;
    try {
      provider = Provider.of<V2RayProvider>(context, listen: false);
    } catch (_) {
      return;
    }

    final configs = <V2RayConfig>[
      ...provider.userConfigs,
      ...provider.userSubscriptions
          .expand((s) => provider.configsForSubscription(s.id)),
    ];

    if (configs.isEmpty) return;

    setState(() {
      _isTesting = true;
      _totalCount = configs.length;
      _testStatusText = '0 / $_totalCount';
      // Clear only the results for the configs we're about to retest so
      // ping badges for other tabs aren't wiped out.
      for (final c in configs) {
        _pingResults.remove(c.id);
      }
    });

    try {
      int successCount = 0;
      int completed = 0;
      int nextIndex = 0;

      Future<void> worker() async {
        while (mounted && _isTesting) {
          if (nextIndex >= configs.length) break;
          final idx = nextIndex++;

          final config = configs[idx];
          final delay = await _testSingleServer(config, provider);

          if (!mounted || !_isTesting) break;

          if (delay >= 0 && delay < 10000) {
            _pingResults[config.id] = delay;
            successCount++;
          } else {
            _pingResults[config.id] = -1;
          }
          completed++;

          if (mounted) {
            setState(() {
              _testStatusText = '$completed / $_totalCount';
            });
          }
        }
      }

      final workerCount = _batchSize.clamp(1, configs.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));

      if (!mounted) return;
      _showSnackBar(
        '${AppLocalizations.of(context).translate('server_selection.servers_updated')} ($successCount/${configs.length})',
        const Color(0xFF00FFA3),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context)
              .translate('server_selection.error_updating'),
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatusText = '';
        });
      }
    }
  }

  Widget _buildMyServersTab() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, _) {
        final subs = provider.userSubscriptions;
        final manualConfigs = provider.userConfigs;
        final r = ResponsiveHelper(context);

        if (subs.isEmpty && manualConfigs.isEmpty) {
          return _buildMyServersEmpty();
        }

        return ListView(
          padding: EdgeInsets.only(
            left: r.horizontalPadding,
            right: r.horizontalPadding,
            top: 8,
            bottom: 24,
          ),
          physics: const ClampingScrollPhysics(),
          children: [
            if (subs.isNotEmpty) ...[
              _buildSectionHeader(
                AppLocalizations.of(context)
                    .translate('server_selection.subscriptions_section'),
                Icons.cloud_download_rounded,
              ),
              const SizedBox(height: 8),
              for (final sub in subs)
                _SubscriptionCard(
                  subscription: sub,
                  configs: provider.configsForSubscription(sub.id),
                  selectedId: provider.wasUsingSmartConnect
                      ? null
                      : provider.selectedConfig?.id,
                  hasActive: provider.activeConfig != null,
                  pingResults: _pingResults,
                  onUpdate: () => _updateSubscription(sub),
                  onRename: () => _renameSubscription(sub),
                  onDelete: () => _deleteSubscription(sub),
                  onTapConfig: (cfg) => _tapUserConfig(cfg),
                ),
              const SizedBox(height: 16),
            ],
            if (manualConfigs.isNotEmpty) ...[
              _buildSectionHeader(
                AppLocalizations.of(context)
                    .translate('server_selection.manual_configs_section'),
                Icons.dns_rounded,
              ),
              const SizedBox(height: 8),
              for (final cfg in manualConfigs)
                _UserServerCard(
                  config: cfg,
                  isSelected: !provider.wasUsingSmartConnect &&
                      provider.selectedConfig?.id == cfg.id,
                  ping: _pingResults[cfg.id],
                  onTap: () => _tapUserConfig(cfg),
                  onRename: () => _renameUserConfig(cfg),
                  onDelete: () => _deleteUserConfig(cfg),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2, left: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyServersEmpty() {
    final r = ResponsiveHelper(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: r.scale(80).clamp(60.0, 100.0),
            height: r.scale(80).clamp(60.0, 100.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withValues(alpha: 0.15),
                  const Color(0xFF00FFA3).withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.bookmark_outline_rounded,
              color: const Color(0xFF00D9FF),
              size: r.scale(40).clamp(30.0, 50.0),
            ),
          ),
          SizedBox(height: r.scale(20).clamp(14.0, 26.0)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
            child: Text(
              AppLocalizations.of(context)
                  .translate('server_selection.no_user_servers'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: r.scale(16).clamp(13.0, 19.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding + 8),
            child: Text(
              AppLocalizations.of(context)
                  .translate('server_selection.no_user_servers_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: r.scale(13).clamp(11.0, 16.0),
              ),
            ),
          ),
          SizedBox(height: r.scale(24).clamp(16.0, 30.0)),
          GestureDetector(
            onTap: _openAddMenu,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.scale(24).clamp(16.0, 32.0),
                vertical: r.scale(12).clamp(8.0, 16.0),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      color: Color(0xFF00D9FF), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)
                        .translate('server_selection.add_menu_title'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.scale(14).clamp(12.0, 17.0),
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

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _tapUserConfig(V2RayConfig cfg) {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    if (provider.activeConfig != null) {
      _showDisconnectFirstDialog(context);
    } else {
      provider.selectConfig(cfg);
      Navigator.pop(context);
    }
  }

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddMenuSheet(
        onAddServer: () {
          Navigator.pop(context);
          _showAddServerDialog();
        },
        onAddSubscription: () {
          Navigator.pop(context);
          _showAddSubscriptionDialog();
        },
      ),
    );
  }

  Future<void> _showAddServerDialog() async {
    final configCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogCtx) => _UserDialogShell(
        title: AppLocalizations.of(context)
            .translate('server_selection.add_server_title'),
        icon: Icons.add_link_rounded,
        children: [
          _DialogTextField(
            controller: configCtrl,
            hintKey: 'server_selection.config_hint',
            maxLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: 10),
          _DialogTextField(
            controller: nameCtrl,
            hintKey: 'server_selection.server_name_hint',
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          _PasteFromClipboardButton(
            onPaste: (text) => configCtrl.text = text,
          ),
        ],
        onSave: () {
          if (configCtrl.text.trim().isEmpty) {
            _showSnackBar(
              AppLocalizations.of(context)
                  .translate('server_selection.config_required'),
              Colors.orange,
            );
            return;
          }
          Navigator.pop(dialogCtx, {
            'config': configCtrl.text.trim(),
            'name': nameCtrl.text.trim(),
          });
        },
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    try {
      await provider.addUserConfigFromUri(
        result['config']!,
        customName: result['name'],
      );
      if (!mounted) return;
      _showSnackBar(
        AppLocalizations.of(context)
            .translate('server_selection.server_added'),
        const Color(0xFF00FFA3),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        AppLocalizations.of(context)
            .translate('server_selection.invalid_config'),
        Colors.red,
      );
    }
  }

  Future<void> _showAddSubscriptionDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogCtx) => _UserDialogShell(
        title: AppLocalizations.of(context)
            .translate('server_selection.add_subscription_title'),
        icon: Icons.cloud_download_rounded,
        children: [
          _DialogTextField(
            controller: nameCtrl,
            hintKey: 'server_selection.subscription_name_hint',
            maxLines: 1,
            autofocus: true,
          ),
          const SizedBox(height: 10),
          _DialogTextField(
            controller: urlCtrl,
            hintKey: 'server_selection.subscription_url_hint',
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          _PasteFromClipboardButton(
            onPaste: (text) => urlCtrl.text = text,
          ),
        ],
        onSave: () {
          if (urlCtrl.text.trim().isEmpty) {
            _showSnackBar(
              AppLocalizations.of(context)
                  .translate('server_selection.url_required'),
              Colors.orange,
            );
            return;
          }
          Navigator.pop(dialogCtx, {
            'name': nameCtrl.text.trim(),
            'url': urlCtrl.text.trim(),
          });
        },
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    final before = provider.userSubscriptions.length;
    await provider.addSubscription(result['name']!, result['url']!);
    if (!mounted) return;
    if (provider.errorMessage.isNotEmpty) {
      _showSnackBar(provider.errorMessage, Colors.red);
    } else {
      final added = provider.userSubscriptions.length > before
          ? provider.userSubscriptions.last
          : null;
      final count = added != null ? added.configIds.length : 0;
      _showSnackBar(
        AppLocalizations.of(context).translate(
          'server_selection.subscription_added',
          parameters: {'count': '$count'},
        ),
        const Color(0xFF00FFA3),
      );
    }
  }

  Future<void> _updateSubscription(Subscription sub) async {
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.updateSubscription(sub);
    if (!mounted) return;
    if (provider.errorMessage.isNotEmpty) {
      _showSnackBar(provider.errorMessage, Colors.red);
    } else {
      _showSnackBar(
        AppLocalizations.of(context)
            .translate('server_selection.subscription_updated'),
        const Color(0xFF00FFA3),
      );
    }
  }

  Future<void> _renameSubscription(Subscription sub) async {
    final ctrl = TextEditingController(text: sub.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _UserDialogShell(
        title: AppLocalizations.of(context)
            .translate('server_selection.edit_subscription_title'),
        icon: Icons.edit_rounded,
        children: [
          _DialogTextField(
            controller: ctrl,
            hintKey: 'server_selection.subscription_name_hint',
            maxLines: 1,
            autofocus: true,
          ),
        ],
        onSave: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.renameSubscription(sub.id, result);
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc.translate('server_selection.delete_subscription_title'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          loc.translate(
            'server_selection.delete_subscription_message',
            parameters: {
              'name': sub.name,
              'count': '${sub.configIds.length}',
            },
          ),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              loc.translate('server_selection.cancel'),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              loc.translate('server_selection.delete'),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.removeSubscription(sub);
    if (!mounted) return;
    _showSnackBar(
      loc.translate('server_selection.subscription_removed'),
      const Color(0xFF00FFA3),
    );
  }

  Future<void> _renameUserConfig(V2RayConfig cfg) async {
    final ctrl = TextEditingController(text: cfg.remark);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => _UserDialogShell(
        title: AppLocalizations.of(context)
            .translate('server_selection.edit_server_title'),
        icon: Icons.edit_rounded,
        children: [
          _DialogTextField(
            controller: ctrl,
            hintKey: 'server_selection.server_name_hint',
            maxLines: 1,
            autofocus: true,
          ),
        ],
        onSave: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
      ),
    );
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.renameUserConfig(cfg.id, result);
  }

  Future<void> _deleteUserConfig(V2RayConfig cfg) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc.translate('server_selection.delete_server_title'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          loc.translate(
            'server_selection.delete_server_message',
            parameters: {'name': cfg.remark},
          ),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              loc.translate('server_selection.cancel'),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              loc.translate('server_selection.delete'),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final provider = Provider.of<V2RayProvider>(context, listen: false);
    await provider.removeConfig(cfg);
    if (!mounted) return;
    _showSnackBar(
      loc.translate('server_selection.server_removed'),
      const Color(0xFF00FFA3),
    );
  }
}

// ─── Add Menu Sheet ──────────────────────────────────────────────────────────

class _AddMenuSheet extends StatelessWidget {
  final VoidCallback onAddServer;
  final VoidCallback onAddSubscription;
  const _AddMenuSheet({
    required this.onAddServer,
    required this.onAddSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111418),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  loc.translate('server_selection.add_menu_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _AddMenuOption(
              icon: Icons.add_link_rounded,
              title: loc.translate('server_selection.add_server_option'),
              subtitle:
                  loc.translate('server_selection.add_server_option_desc'),
              onTap: onAddServer,
            ),
            const SizedBox(height: 8),
            _AddMenuOption(
              icon: Icons.cloud_download_rounded,
              title:
                  loc.translate('server_selection.add_subscription_option'),
              subtitle: loc
                  .translate('server_selection.add_subscription_option_desc'),
              onTap: onAddSubscription,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AddMenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: const Color(0xFF00D9FF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Consumer<LanguageProvider>(
              builder: (context, lang, _) => Icon(
                lang.isRtl ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog shell + text field ───────────────────────────────────────────────

class _UserDialogShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback onSave;
  const _UserDialogShell({
    required this.title,
    required this.icon,
    required this.children,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            loc.translate('server_selection.cancel'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
          ),
        ),
        TextButton(
          onPressed: onSave,
          child: Text(
            loc.translate('server_selection.save'),
            style: const TextStyle(
              color: Color(0xFF00D9FF),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintKey;
  final int maxLines;
  final bool autofocus;
  const _DialogTextField({
    required this.controller,
    required this.hintKey,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: const Color(0xFF00D9FF),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).translate(hintKey),
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF00D9FF).withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _PasteFromClipboardButton extends StatelessWidget {
  final void Function(String text) onPaste;
  const _PasteFromClipboardButton({required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        onPressed: () async {
          final data = await Clipboard.getData('text/plain');
          final text = data?.text?.trim() ?? '';
          if (text.isNotEmpty) onPaste(text);
        },
        icon: const Icon(Icons.paste_rounded,
            size: 16, color: Color(0xFF00D9FF)),
        label: const Text(
          'Paste',
          style: TextStyle(
            color: Color(0xFF00D9FF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ─── Subscription Card ───────────────────────────────────────────────────────

class _SubscriptionCard extends StatefulWidget {
  final Subscription subscription;
  final List<V2RayConfig> configs;
  final String? selectedId;
  final bool hasActive;
  final Map<String, int> pingResults;
  final VoidCallback onUpdate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(V2RayConfig) onTapConfig;

  const _SubscriptionCard({
    required this.subscription,
    required this.configs,
    required this.selectedId,
    required this.hasActive,
    required this.pingResults,
    required this.onUpdate,
    required this.onRename,
    required this.onDelete,
    required this.onTapConfig,
  });

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00D9FF)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.cloud_done_rounded,
                        color: Color(0xFF00D9FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subscription.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${loc.translate(
                            'server_selection.servers_count',
                            parameters: {
                              'count': '${widget.configs.length}'
                            },
                          )} · ${_relativeTime(context, widget.subscription.lastUpdated)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _CardAction(
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFF00D9FF),
                    onTap: widget.onUpdate,
                  ),
                  _CardAction(
                    icon: Icons.edit_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    onTap: widget.onRename,
                  ),
                  _CardAction(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    onTap: widget.onDelete,
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.configs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                    margin: const EdgeInsets.only(bottom: 6),
                  ),
                  for (final cfg in widget.configs)
                    _SubConfigRow(
                      config: cfg,
                      isSelected: widget.selectedId == cfg.id,
                      ping: widget.pingResults[cfg.id],
                      onTap: () => widget.onTapConfig(cfg),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CardAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsetsDirectional.only(end: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _SubConfigRow extends StatelessWidget {
  final V2RayConfig config;
  final bool isSelected;
  final int? ping;
  final VoidCallback onTap;
  const _SubConfigRow({
    required this.config,
    required this.isSelected,
    required this.ping,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final countryCode =
        config.countryCode ?? CountryFlags.extractCountryCode(config.remark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            _miniFlag(countryCode),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _cleanName(config.remark),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ping != null) ...[
              const SizedBox(width: 6),
              _PingBadge(ping: ping!),
            ],
            if (isSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.black, size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniFlag(String? countryCode) {
    if (countryCode == null ||
        !CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: 22,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.public_rounded,
            color: Colors.white38, size: 12),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: CountryFlags.getFlagUrl(countryCode),
        width: 22,
        height: 16,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        placeholder: (_, __) => Container(
          width: 22,
          height: 16,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 22,
          height: 16,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  String _cleanName(String remark) {
    String clean = remark;
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Z]{2}[\]\)]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^[A-Z]{2}[-\s]+'), '');
    return clean.trim().isEmpty ? remark : clean.trim();
  }
}

// ─── User Server Card (manual config) ────────────────────────────────────────

class _UserServerCard extends StatelessWidget {
  final V2RayConfig config;
  final bool isSelected;
  final int? ping;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _UserServerCard({
    required this.config,
    required this.isSelected,
    required this.ping,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E3A5F).withValues(alpha: 0.8),
                      const Color(0xFF0D2137).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF00D9FF).withValues(alpha: 0.25)),
                ),
                child: Icon(
                  _iconForType(config.configType),
                  color: const Color(0xFF00D9FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.remark,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${config.configType.toUpperCase()} · ${config.address}:${config.port}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (ping != null) ...[
                const SizedBox(width: 6),
                _PingBadge(ping: ping!),
              ],
              const SizedBox(width: 4),
              _CardAction(
                icon: Icons.edit_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                onTap: onRename,
              ),
              _CardAction(
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent.withValues(alpha: 0.85),
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'vmess':
        return Icons.vpn_lock_rounded;
      case 'vless':
        return Icons.shield_rounded;
      case 'shadowsocks':
        return Icons.security_rounded;
      case 'trojan':
        return Icons.lock_rounded;
      default:
        return Icons.dns_rounded;
    }
  }
}

// ─── Relative time helper ────────────────────────────────────────────────────

String _relativeTime(BuildContext context, DateTime then) {
  final loc = AppLocalizations.of(context);
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) {
    return loc.translate('server_selection.just_now');
  }
  if (diff.inHours < 1) {
    return loc.translate(
      'server_selection.minutes_ago',
      parameters: {'n': '${diff.inMinutes}'},
    );
  }
  if (diff.inDays < 1) {
    return loc.translate(
      'server_selection.hours_ago',
      parameters: {'n': '${diff.inHours}'},
    );
  }
  return loc.translate(
    'server_selection.days_ago',
    parameters: {'n': '${diff.inDays}'},
  );
}

// ─── Toolbar Icon Button ─────────────────────────────────────────────────────

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool enabled;
  final bool spinning;
  final AnimationController? animController;
  final VoidCallback? onTap;
  final ResponsiveHelper responsive;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.enabled,
    required this.responsive,
    this.spinning = false,
    this.animController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = responsive.scale(44).clamp(40.0, 52.0);
    final iconColor = enabled ? color : Colors.white.withValues(alpha: 0.25);
    final iconWidget = Icon(icon, color: iconColor, size: 20);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Center(
            child: spinning && animController != null
                ? RotationTransition(turns: animController!, child: iconWidget)
                : iconWidget,
          ),
        ),
      ),
    );
  }
}

// ─── Smart Connect Card ───────────────────────────────────────────────────────

class _SmartConnectCard extends StatelessWidget {
  final V2RayProvider provider;
  final VoidCallback onDisconnectFirst;

  const _SmartConnectCard({
    required this.provider,
    required this.onDisconnectFirst,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = provider.wasUsingSmartConnect;
    final r = ResponsiveHelper(context);

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(10).clamp(6.0, 14.0)),
      child: GestureDetector(
        onTap: () {
          if (provider.activeConfig != null) {
            onDisconnectFirst();
          } else {
            provider.selectConfig(V2RayConfig.smartConnect());
            Navigator.pop(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(16).clamp(11.0, 22.0),
            vertical: r.scale(14).clamp(10.0, 20.0),
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: r.scale(44).clamp(36.0, 56.0),
                height: r.scale(44).clamp(36.0, 56.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF00FFA3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/apk.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: r.scale(22).clamp(18.0, 28.0),
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.scale(14).clamp(10.0, 18.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('server_selection.smart_connect'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.scale(15).clamp(13.0, 19.0),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).translate('server_selection.smart_connect_description'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: r.scale(12).clamp(10.0, 15.0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                )
              else
                Consumer<LanguageProvider>(
                  builder: (context, lang, _) => Icon(
                    lang.isRtl ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Server Card ─────────────────────────────────────────────────────────────

class _ServerCard extends StatelessWidget {
  final V2RayConfig config;
  final bool isSelected;
  final int? ping;
  final VoidCallback onTap;

  const _ServerCard({
    required this.config,
    required this.isSelected,
    required this.ping,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final countryCode = config.countryCode ?? CountryFlags.extractCountryCode(config.remark);
    final r = ResponsiveHelper(context);

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(10).clamp(6.0, 14.0)),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14).clamp(10.0, 20.0),
            vertical: r.scale(13).clamp(9.0, 18.0),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _buildFlag(countryCode, r),
              SizedBox(width: r.scale(12).clamp(8.0, 16.0)),
              Expanded(
                child: Text(
                  _cleanName(config.remark),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontSize: r.scale(14).clamp(12.0, 18.0),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ping != null) ...[
                SizedBox(width: r.scale(8).clamp(5.0, 12.0)),
                _PingBadge(ping: ping!),
              ],
              SizedBox(width: r.scale(8).clamp(5.0, 12.0)),
              if (isSelected)
                Container(
                  width: r.scale(20).clamp(16.0, 26.0),
                  height: r.scale(20).clamp(16.0, 26.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 13),
                )
              else
                Consumer<LanguageProvider>(
                  builder: (context, lang, _) => Icon(
                    lang.isRtl ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlag(String? countryCode, ResponsiveHelper r) {
    final w = r.flagWidth * 0.85;
    final h = r.flagHeight * 0.78;

    if (countryCode == null || !CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.public_rounded, color: Colors.white38, size: r.scale(16).clamp(12.0, 20.0)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: CountryFlags.getFlagUrl(countryCode),
        width: w,
        height: h,
        fit: BoxFit.cover,
        memCacheWidth: 240,
        maxWidthDiskCache: 360,
        fadeInDuration: const Duration(milliseconds: 100),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => Container(
          width: w,
          height: h,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        errorWidget: (_, __, ___) => Container(
          width: w,
          height: h,
          color: Colors.white.withValues(alpha: 0.08),
          child: const Icon(Icons.flag_rounded, color: Colors.white38, size: 16),
        ),
      ),
    );
  }

  String _cleanName(String remark) {
    String clean = remark;
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Z]{2}[\]\)]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^[A-Z]{2}[-\s]+'), '');
    return clean.trim().isEmpty ? remark : clean.trim();
  }
}

// ─── Ping Badge ──────────────────────────────────────────────────────────────

class _PingBadge extends StatelessWidget {
  final int ping;

  const _PingBadge({required this.ping});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (ping < 0) {
      // Server didn't respond to ping
      color = const Color(0xFFEF4444);
      label = '-1ms';
    } else if (ping >= 99999) {
      color = Colors.white24;
      label = '—';
    } else if (ping < 400) {
      // Excellent (0-399ms) - Green
      color = const Color(0xFF00FFA3);
      label = '${ping}ms';
    } else if (ping < 700) {
      // Good (400-699ms) - Yellow
      color = const Color(0xFFFBBF24);
      label = '${ping}ms';
    } else if (ping < 1500) {
      // Average (700-1499ms) - Orange
      color = const Color(0xFFF97316);
      label = '${ping}ms';
    } else {
      // Poor (1500+ms) - Red
      color = const Color(0xFFEF4444);
      label = '${ping}ms';
    }

    final r = ResponsiveHelper(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(7).clamp(5.0, 11.0),
        vertical: r.scale(3).clamp(2.0, 6.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: r.scale(11).clamp(9.5, 14.0),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
