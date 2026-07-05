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
import '../widgets/wave_loading.dart';
import '../services/analytics_service.dart';

/// Grouped-by-location server list.
///
/// Servers are grouped by their [V2RayConfig.countryCode] (injected by the
/// config_tester tool as a `[CC] ` line prefix). Each group is shown under a
/// header (flag + country name + count); rows show the per-server name (city)
/// and a live ping badge. A pinned Smart Connect card sits on top. Servers with
/// no detected country fall into a single "Other" group at the bottom.
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
  late AnimationController _refreshAnimController;

  String _testStatusText = '';
  int _totalCount = 0;
  int _batchSize = 8;
  String _query = '';

  static const String _otherGroupKey = 'OTHER';

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Entekhab_Server');
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadBatchSize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadFlags());
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
    _refreshAnimController.dispose();
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
        AnalyticsService()
            .logServerListRefresh(serverCount: provider.serverConfigs.length);
        setState(() => _pingResults.clear());
        _showSnackBar(
          provider.errorMessage.isEmpty
              ? AppLocalizations.of(context)
                  .translate('server_selection.servers_updated')
              : provider.errorMessage,
          provider.errorMessage.isEmpty
              ? const Color(0xFF00FFA3)
              : Colors.orange,
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
              constraints:
                  BoxConstraints(maxWidth: responsive.maxContentWidth),
              child: Column(
                children: [
                  _buildHeader(context, responsive),
                  _buildActionToolbar(responsive),
                  _buildSearchBox(responsive),
                  Expanded(child: _buildGroupedList()),
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
                  AppLocalizations.of(context)
                      .translate('server_selection.title'),
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
                    '${provider.serverConfigs.length} ${AppLocalizations.of(context).translate('server_selection.select_server')}',
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
          Expanded(child: _buildPingActionBtn(responsive)),
          const SizedBox(width: 8),
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
              WaveLoading.small(color: Colors.white.withValues(alpha: 0.7)),
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
              const Icon(Icons.speed_rounded,
                  color: Color(0xFF00D9FF), size: 16),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.of(context)
                    .translate('server_selection.test_ping'),
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

  Widget _buildSearchBox(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        0,
        responsive.horizontalPadding,
        10,
      ),
      child: Container(
        height: responsive.scale(44).clamp(38.0, 54.0),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: responsive.scale(18).clamp(15.0, 22.0)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: const Color(0xFF00D9FF),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)
                      .translate('server_selection.search_hint'),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Grouping ──────────────────────────────────────────────────────────────

  String _groupKey(V2RayConfig c) {
    final cc = c.countryCode;
    if (cc != null && CountryFlags.isValidCountryCode(cc)) {
      return cc.toUpperCase();
    }
    return _otherGroupKey;
  }

  int _pingOf(V2RayConfig c) {
    final raw = _pingResults[c.id];
    return (raw == null || raw < 0) ? 99999999 : raw;
  }

  bool _matchesQuery(V2RayConfig c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final cc = (c.countryCode ?? '').toLowerCase();
    final country = c.countryCode != null
        ? CountryFlags.getCountryName(c.countryCode).toLowerCase()
        : '';
    return _cleanName(c.remark).toLowerCase().contains(q) ||
        cc.contains(q) ||
        country.contains(q);
  }

  Widget _buildGroupedList() {
    return Consumer<V2RayProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingServers && provider.serverConfigs.isEmpty) {
          return _buildLoadingState();
        }

        final servers =
            provider.serverConfigs.where(_matchesQuery).toList(growable: false);
        if (servers.isEmpty) return _buildEmptyState();

        // Group by country code.
        final Map<String, List<V2RayConfig>> groups = {};
        for (final c in servers) {
          groups.putIfAbsent(_groupKey(c), () => []).add(c);
        }
        // Sort inside each group by ping (unknown last).
        for (final list in groups.values) {
          list.sort((a, b) => _pingOf(a).compareTo(_pingOf(b)));
        }
        // Sort groups: best-ping group first, then alphabetically; Other last.
        int groupBest(List<V2RayConfig> l) =>
            l.map(_pingOf).reduce((a, b) => a < b ? a : b);
        final sortedKeys = groups.keys.toList()
          ..sort((a, b) {
            if (a == _otherGroupKey) return 1;
            if (b == _otherGroupKey) return -1;
            final bestA = groupBest(groups[a]!);
            final bestB = groupBest(groups[b]!);
            if (bestA != bestB) return bestA.compareTo(bestB);
            return CountryFlags.getCountryName(a)
                .compareTo(CountryFlags.getCountryName(b));
          });

        // Flatten into row entries: smart connect + (header + servers)*.
        final entries = <_Entry>[_Entry.smart()];
        for (final key in sortedKeys) {
          final list = groups[key]!;
          entries.add(_Entry.header(key, list.length));
          for (final c in list) {
            entries.add(_Entry.server(c));
          }
        }

        final r = ResponsiveHelper(context);
        return ListView.builder(
          padding: EdgeInsets.only(
            left: r.horizontalPadding,
            right: r.horizontalPadding,
            top: 4,
            bottom: 24,
          ),
          physics: const ClampingScrollPhysics(),
          itemCount: entries.length,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final e = entries[index];
            switch (e.type) {
              case _EntryType.smart:
                return _SmartConnectCard(
                  provider: provider,
                  onDisconnectFirst: () => _showDisconnectFirstDialog(context),
                );
              case _EntryType.header:
                return _GroupHeader(
                  countryKey: e.groupKey!,
                  count: e.count!,
                  otherLabel: AppLocalizations.of(context)
                      .translate('server_selection.other'),
                );
              case _EntryType.server:
                final config = e.config!;
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
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const WaveLoading(),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).translate('common.loading_servers'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
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
          Icon(Icons.dns_outlined,
              size: r.scale(56).clamp(40.0, 72.0),
              color: Colors.white.withValues(alpha: 0.2)),
          SizedBox(height: r.scale(16).clamp(10.0, 22.0)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
            child: Text(
              AppLocalizations.of(context)
                  .translate('server_selection.no_servers_available'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: r.scale(15).clamp(12.0, 18.0)),
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
                AppLocalizations.of(context)
                    .translate('server_selection.refresh'),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: r.scale(14).clamp(12.0, 17.0),
                    fontWeight: FontWeight.w600),
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
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)
                    .translate('server_selector.connection_active'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)
              .translate('server_selector.disconnect_first'),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
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
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatusText = '';
        });
      }
      return;
    }

    // Fresh readings for a manual "test all" — drop the 30s ping cache first.
    provider.v2rayService.clearPingCache();

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
          _pingResults[config.id] = (delay >= 0 && delay < 10000) ? delay : -1;
          if (delay >= 0 && delay < 10000) successCount++;
          completed++;
          if (mounted) {
            setState(() => _testStatusText = '$completed / $_totalCount');
          }
        }
      }

      final workerCount = _batchSize.clamp(1, configs.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));

      if (!mounted) return;
      setState(() {});
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

  Future<int> _testSingleServer(
      V2RayConfig config, V2RayProvider provider) async {
    try {
      final delay = await provider.v2rayService.getServerDelay(config).timeout(
            const Duration(seconds: 6),
            onTimeout: () => -1,
          );
      return delay ?? -1;
    } catch (_) {
      return -1;
    }
  }

  String _cleanName(String remark) {
    String clean = remark;
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Za-z]{2}[\]\)]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^[A-Z]{2}[-\s]+'), '');
    return clean.trim().isEmpty ? remark : clean.trim();
  }
}

// ─── Row entry model ───────────────────────────────────────────────────────

enum _EntryType { smart, header, server }

class _Entry {
  final _EntryType type;
  final String? groupKey;
  final int? count;
  final V2RayConfig? config;

  _Entry._(this.type, {this.groupKey, this.count, this.config});
  factory _Entry.smart() => _Entry._(_EntryType.smart);
  factory _Entry.header(String key, int count) =>
      _Entry._(_EntryType.header, groupKey: key, count: count);
  factory _Entry.server(V2RayConfig c) =>
      _Entry._(_EntryType.server, config: c);
}

// ─── Group Header ────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String countryKey;
  final int count;
  final String otherLabel;

  const _GroupHeader({
    required this.countryKey,
    required this.count,
    required this.otherLabel,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final isOther = countryKey == 'OTHER';
    final title = isOther ? otherLabel : CountryFlags.getCountryName(countryKey);

    return Padding(
      padding: EdgeInsets.only(
        top: r.scale(14).clamp(10.0, 20.0),
        bottom: r.scale(8).clamp(5.0, 12.0),
        left: 2,
        right: 2,
      ),
      child: Row(
        children: [
          if (!isOther)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: CountryFlags.getFlagUrl(countryKey),
                width: r.scale(26).clamp(22.0, 34.0),
                height: r.scale(19).clamp(16.0, 25.0),
                fit: BoxFit.cover,
                memCacheWidth: 120,
                fadeInDuration: const Duration(milliseconds: 100),
                placeholder: (_, __) => Container(
                    color: Colors.white.withValues(alpha: 0.08)),
                errorWidget: (_, __, ___) => Icon(Icons.flag_rounded,
                    color: Colors.white38, size: r.scale(16).clamp(13.0, 20.0)),
              ),
            )
          else
            Icon(Icons.public_rounded,
                color: Colors.white38, size: r.scale(20).clamp(16.0, 26.0)),
          SizedBox(width: r.scale(10).clamp(7.0, 14.0)),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: r.scale(14).clamp(12.0, 18.0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(width: r.scale(8).clamp(6.0, 12.0)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: r.scale(11).clamp(9.5, 14.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                      AppLocalizations.of(context)
                          .translate('server_selection.smart_connect'),
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
                      AppLocalizations.of(context).translate(
                          'server_selection.smart_connect_description'),
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
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 14),
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
    final countryCode =
        config.countryCode ?? CountryFlags.extractCountryCode(config.remark);
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
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
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
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 13),
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
        child: Icon(Icons.public_rounded,
            color: Colors.white38, size: r.scale(16).clamp(12.0, 20.0)),
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
    clean = clean.replaceAll(RegExp(r'^[\[\(][A-Za-z]{2}[\]\)]\s*'), '');
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
      color = const Color(0xFFEF4444);
      label = '-1ms';
    } else if (ping >= 99999) {
      color = Colors.white24;
      label = '—';
    } else if (ping < 400) {
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
