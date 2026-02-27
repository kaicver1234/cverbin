import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/v2ray_provider.dart';
import '../providers/language_provider.dart';
import '../models/v2ray_config.dart';
import '../utils/app_localizations.dart';
import '../utils/country_flags.dart';
import '../utils/responsive_helper.dart';
import '../widgets/app_background.dart';
import '../services/analytics_service.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen>
    with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 2, vsync: this);
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
      final saved = prefs.getInt('ping_batch_size') ?? 15;
      if (mounted) setState(() => _batchSize = saved.clamp(1, 30));
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
          child: Column(
            children: [
              _buildHeader(context, responsive),
              _buildTabBar(responsive),
              if (_activeTabIndex == 0)
                _buildActionButtons(responsive),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildFreeTab(),
                    _buildPremiumTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        12,
        responsive.horizontalPadding,
        12,
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
              icon: Icons.workspace_premium_rounded,
              isActive: _activeTabIndex == 1,
              onTap: () => _tabController.animateTo(1),
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

  Widget _buildActionButtons(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        12,
        responsive.horizontalPadding,
        8,
      ),
      child: Row(
        children: [
          _buildIconActionBtn(
            icon: Icons.refresh_rounded,
            isLoading: _isRefreshing,
            onTap: _isRefreshing ? null : _refreshServers,
            animController: _refreshAnimController,
            responsive: responsive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPingActionBtn(responsive),
          ),
        ],
      ),
    );
  }

  Widget _buildIconActionBtn({
    required IconData icon,
    required bool isLoading,
    required VoidCallback? onTap,
    required AnimationController animController,
    required ResponsiveHelper responsive,
  }) {
    final size = responsive.scale(44).clamp(38.0, 54.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: RotationTransition(
          turns: animController,
          child: Icon(
            icon,
            color: isLoading ? Colors.white : Colors.white.withValues(alpha: 0.7),
            size: responsive.scale(20).clamp(16.0, 24.0),
          ),
        ),
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
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.7),
                  ),
                ),
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
            : [V2RayConfig.smartConnect(), ...provider.configs];

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
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(20).clamp(16.0, 26.0)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: responsive.scale(48).clamp(36.0, 60.0),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).translate('server_selection.premium'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.scale(22).clamp(18.0, 28.0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).translate('server_selection.coming_soon'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: responsive.scale(14).clamp(12.0, 17.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('common.loading_servers'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('server_selection.no_servers_available'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _refreshServers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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

    final configs = provider.serverConfigs;
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

          if (delay >= 0 && delay < 10000) {
            _pingResults[config.id] = delay;
            successCount++;
          } else {
            _pingResults[config.id] = 99999;
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

      _sortServersByPing(provider, _pingResults);
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
      final delay = await provider.v2rayService.getServerDelay(config).timeout(
        const Duration(seconds: 8),
        onTimeout: () => -1,
      );
      return delay ?? -1;
    } catch (_) {
      return -1;
    }
  }

  void _sortServersByPing(V2RayProvider provider, Map<String, int> pingResults) {
    final servers = List<V2RayConfig>.from(provider.serverConfigs)
      ..sort((a, b) {
        final pA = pingResults[a.id] ?? 99999;
        final pB = pingResults[b.id] ?? 99999;
        return pA.compareTo(pB);
      });
    _sortedConfigs = [V2RayConfig.smartConnect(), ...servers];
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                width: 44,
                height: 44,
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
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('server_selection.smart_connect'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
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
                        fontSize: 12,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
              _buildFlag(countryCode),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _cleanName(config.remark),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ping != null) ...[
                const SizedBox(width: 8),
                _PingBadge(ping: ping!),
              ],
              const SizedBox(width: 8),
              if (isSelected)
                Container(
                  width: 20,
                  height: 20,
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

  Widget _buildFlag(String? countryCode) {
    const w = 40.0;
    const h = 28.0;

    if (countryCode == null || !CountryFlags.isValidCountryCode(countryCode)) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.public_rounded, color: Colors.white38, size: 16),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: CountryFlags.getFlagUrl(countryCode),
        width: w,
        height: h,
        fit: BoxFit.cover,
        memCacheWidth: 80,
        memCacheHeight: 56,
        maxWidthDiskCache: 80,
        maxHeightDiskCache: 56,
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

    if (ping >= 99999) {
      color = Colors.white24;
      label = '—';
    } else if (ping < 300) {
      color = const Color(0xFF00FFA3);
      label = '${ping}ms';
    } else if (ping < 700) {
      color = const Color(0xFFFBBF24);
      label = '${ping}ms';
    } else if (ping < 1500) {
      color = const Color(0xFFF97316);
      label = '${ping}ms';
    } else {
      color = const Color(0xFFEF4444);
      label = '${ping}ms';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
