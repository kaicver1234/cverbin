import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/per_app_proxy_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/app_background.dart';
import '../utils/responsive_helper.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF111111);
const _kBorder = Color(0xFF222222);

class PerAppProxyScreen extends StatefulWidget {
  const PerAppProxyScreen({super.key});

  @override
  State<PerAppProxyScreen> createState() => _PerAppProxyScreenState();
}

class _PerAppProxyScreenState extends State<PerAppProxyScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;
  bool _hasUnappliedChanges = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Per_App_Proxy');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<PerAppProxyProvider>(context, listen: false).loadInstalledApps();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isRtl {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return lang.currentLanguage.direction == 'rtl';
  }

  String _t(String fa, String en) => _isRtl ? fa : en;

  void _markDirty() {
    if (!_hasUnappliedChanges) {
      setState(() => _hasUnappliedChanges = true);
    }
  }

  Future<void> _save(PerAppProxyProvider provider) async {
    await provider.applyAndPersist();
    if (!mounted) return;
    setState(() => _hasUnappliedChanges = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t('تنظیمات ذخیره شد', 'Settings saved'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _iconForMode(PerAppProxyMode mode) {
    switch (mode) {
      case PerAppProxyMode.off:         return Icons.public_rounded;
      case PerAppProxyMode.excludeOnly: return Icons.block_rounded;
      case PerAppProxyMode.includeOnly: return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _t('پروکسی برنامه‌ها', 'Per-App Proxy'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            Consumer<PerAppProxyProvider>(
              builder: (context, provider, _) {
                final hasSelection = provider.selectedCount > 0;
                if (!hasSelection || provider.mode == PerAppProxyMode.off) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  tooltip: _t('پاک کردن انتخاب‌ها', 'Clear selection'),
                  icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
                  onPressed: () {
                    provider.clearSelection();
                    _markDirty();
                  },
                );
              },
            ),
          ],
        ),
        body: Consumer<PerAppProxyProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                Expanded(
                  child: ResponsivePageWrapper(
                    child: _buildBody(provider, isRtl),
                  ),
                ),
                if (_hasUnappliedChanges) _buildSaveBar(provider, isRtl),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(PerAppProxyProvider provider, bool isRtl) {
    final r = ResponsiveHelper(context);
    final padding = r.horizontalPadding;

    // Pre-filter once per build instead of inside _buildAppList — used by
    // both the SliverList builder and the empty-state fallback.
    final query = _query;
    final filtered = (provider.mode == PerAppProxyMode.off)
        ? const <InstalledAppInfo>[]
        : (query.isEmpty
            ? provider.installedApps
            : provider.installedApps
                .where((a) =>
                    a.name.toLowerCase().contains(query) ||
                    a.packageName.toLowerCase().contains(query))
                .toList(growable: false));

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _buildSectionLabel(_t('حالت', 'Mode')),
              const SizedBox(height: 12),
              _buildModeCard(
                provider: provider,
                mode: PerAppProxyMode.off,
                title: _t('همه برنامه‌ها', 'All apps'),
                subtitle: _t(
                  'تمام ترافیک از طریق VPN عبور می‌کند',
                  'All traffic goes through the VPN',
                ),
                badge: _t('پیش‌فرض', 'Default'),
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                provider: provider,
                mode: PerAppProxyMode.excludeOnly,
                title: _t('استثنا کردن برنامه‌ها', 'Exclude apps'),
                subtitle: _t(
                  'برنامه‌های انتخاب شده از VPN خارج می‌شوند',
                  'Selected apps bypass the VPN',
                ),
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                provider: provider,
                mode: PerAppProxyMode.includeOnly,
                title: _t('فقط برنامه‌های انتخابی', 'Only selected apps'),
                subtitle: _t(
                  'فقط برنامه‌های انتخاب شده از VPN استفاده می‌کنند',
                  'Only selected apps use the VPN',
                ),
              ),
              const SizedBox(height: 28),
              if (provider.mode != PerAppProxyMode.off) ...[
                _buildSectionLabel(_t('برنامه‌ها', 'Apps')),
                const SizedBox(height: 12),
                _buildSelectionSummary(provider, isRtl),
                const SizedBox(height: 14),
                _buildSearchField(isRtl),
                const SizedBox(height: 14),
              ],
            ]),
          ),
        ),

        if (provider.mode != PerAppProxyMode.off)
          ..._buildAppListSlivers(provider, filtered, padding, isRtl),

        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 80),
          sliver: SliverToBoxAdapter(child: _buildInfoBox(isRtl)),
        ),
      ],
    );
  }

  List<Widget> _buildAppListSlivers(
    PerAppProxyProvider provider,
    List<InstalledAppInfo> filtered,
    double padding,
    bool isRtl,
  ) {
    // Loading / error / empty states are simple BoxAdapters; the list itself
    // is a real SliverList so rows are built lazily as the user scrolls.
    if (provider.isLoadingApps && provider.installedApps.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverToBoxAdapter(child: _buildLoadingState()),
        ),
      ];
    }
    if (provider.loadError != null) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverToBoxAdapter(child: _buildErrorState(provider)),
        ),
      ];
    }
    if (filtered.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        sliver: DecoratedSliver(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final app = filtered[i];
              final isLast = i == filtered.length - 1;
              return Column(
                children: [
                  _buildAppRow(provider, app),
                  if (!isLast)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.05),
                      height: 1,
                      thickness: 1,
                      indent: 60,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _t('در حال بارگذاری برنامه‌ها...', 'Loading apps...'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(PerAppProxyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: const Color(0xFFEF4444).withValues(alpha: 0.7),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.loadError!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => provider.loadInstalledApps(force: true),
            child: Text(
              _t('تلاش دوباره', 'Retry'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text(
          _t('برنامه‌ای پیدا نشد', 'No apps found'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildModeCard({
    required PerAppProxyProvider provider,
    required PerAppProxyMode mode,
    required String title,
    required String subtitle,
    String? badge,
  }) {
    final isSelected = provider.mode == mode;

    return GestureDetector(
      onTap: () {
        if (provider.mode == mode) return;
        provider.setMode(mode);
        _markDirty();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF181818) : _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.4)
                : _kBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isSelected ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForMode(mode), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (badge != null && badge.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSummary(PerAppProxyProvider provider, bool isRtl) {
    final count = provider.selectedCount;
    final isInclude = provider.mode == PerAppProxyMode.includeOnly;
    String message;
    if (count == 0) {
      message = isInclude
          ? _t(
              'هیچ برنامه‌ای انتخاب نشده است. تا انتخاب نکنید همه ترافیک از VPN عبور می‌کند.',
              'No apps selected — all traffic will use the VPN until you pick at least one app.',
            )
          : _t(
              'هیچ برنامه‌ای استثنا نشده است.',
              'No apps excluded yet.',
            );
    } else {
      message = isInclude
          ? _t(
              '$count برنامه از طریق VPN عبور خواهند کرد.',
              '$count app(s) will go through the VPN.',
            )
          : _t(
              '$count برنامه از VPN خارج خواهند شد.',
              '$count app(s) will bypass the VPN.',
            );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isRtl) {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white,
      onChanged: (v) {
        final next = v.trim().toLowerCase();
        _searchDebounce?.cancel();
        // Short keys feel responsive; for longer typing we debounce so we
        // don't rebuild the whole sliver list on every keystroke.
        _searchDebounce = Timer(const Duration(milliseconds: 180), () {
          if (!mounted) return;
          if (_query == next) return;
          setState(() => _query = next);
        });
      },
      decoration: InputDecoration(
        hintText: _t('جستجو در برنامه‌ها...', 'Search apps...'),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: 20,
        ),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
                onPressed: () {
                  _searchDebounce?.cancel();
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              )
            : null,
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildAppRow(PerAppProxyProvider provider, InstalledAppInfo app) {
    final isSelected = provider.selectedPackages.contains(app.packageName);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          provider.togglePackage(app.packageName);
          _markDirty();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: app.icon != null
                    ? Image.memory(
                        app.icon!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.android_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      )
                    : Icon(
                        Icons.android_rounded,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.packageName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(bool isRtl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.35),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(
                'با این قابلیت می‌توانید مشخص کنید کدام برنامه‌ها از VPN استفاده کنند یا کدام برنامه‌ها از VPN خارج شوند. تغییرات پس از زدن «اعمال» ذخیره می‌شوند و در صورت اتصال فعال، VPN دوباره برقرار می‌شود.',
                'Choose which apps go through the VPN, or which apps should bypass it. Changes are saved when you tap Apply, and the VPN reconnects if it is currently active.',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(PerAppProxyProvider provider, bool isRtl) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _kBg,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _t('تغییرات ذخیره نشده‌اند', 'Unsaved changes'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _save(provider),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _t('اعمال', 'Apply'),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
