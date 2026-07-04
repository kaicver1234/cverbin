import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/routing_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/app_background.dart';
import '../widgets/modern_glass_card.dart';
import '../widgets/wave_loading.dart';
import '../utils/responsive_helper.dart';

// Match the home screen language: pure-black canvas with translucent
// white surfaces. No bespoke palette here — anything tinted comes from
// per-section accent colors (the same ones used for the tool cards).
const Color _kPrimary = Color(0xFF00D9FF);
const Color _kIranAccent = Color(0xFF00FFA3);
const Color _kAdBlockAccent = Color(0xFFFF5C7A);
const Color _kLanAccent = Color(0xFFA78BFA);
const Color _kSubnetAccent = Color(0xFFFFB347);
const Color _kDomainAccent = Color(0xFFFF6B9D);
const Color _kDanger = Color(0xFFFF6B6B);

class RoutingSettingsScreen extends StatefulWidget {
  const RoutingSettingsScreen({super.key});

  @override
  State<RoutingSettingsScreen> createState() => _RoutingSettingsScreenState();
}

class _RoutingSettingsScreenState extends State<RoutingSettingsScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Routing');
  }

  bool get _isRtl =>
      Provider.of<LanguageProvider>(context, listen: false)
          .currentLanguage
          .direction ==
      'rtl';

  String _t({required String fa, required String en}) => _isRtl ? fa : en;

  @override
  Widget build(BuildContext context) {
    final isRtl = _isRtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                isRtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _t(fa: 'مسیریابی و دور زدن', en: 'Routing & Bypass'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: Consumer<RoutingProvider>(
            builder: (context, routing, _) {
              if (!routing.isInitialized) {
                return const Center(
                  child: WaveLoading(color: _kPrimary),
                );
              }
              final r = ResponsiveHelper(context);
              return ResponsivePageWrapper(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    r.horizontalPadding,
                    8,
                    r.horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(routing),
                      const SizedBox(height: 22),
                      _buildSectionLabel(
                        _t(fa: 'دور زدن سریع', en: 'Quick Bypass'),
                      ),
                      const SizedBox(height: 12),
                      _buildIranToggle(routing),
                      const SizedBox(height: 10),
                      _buildPrivateToggle(routing),
                      const SizedBox(height: 24),
                      _buildSectionLabel(
                        _t(fa: 'حریم خصوصی', en: 'Privacy'),
                      ),
                      const SizedBox(height: 12),
                      _buildAdBlockToggle(routing),
                      const SizedBox(height: 24),
                      _buildSectionLabel(
                        _t(fa: 'سابنت‌های دلخواه', en: 'Custom Subnets'),
                      ),
                      const SizedBox(height: 8),
                      _buildSubnetHint(),
                      const SizedBox(height: 12),
                      _buildSubnetEditor(routing),
                      const SizedBox(height: 24),
                      _buildSectionLabel(
                        _t(fa: 'دامنه‌های دلخواه', en: 'Custom Domains'),
                      ),
                      const SizedBox(height: 8),
                      _buildDomainHint(),
                      const SizedBox(height: 12),
                      _buildDomainEditor(routing),
                      const SizedBox(height: 28),
                      _buildInfoCard(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(RoutingProvider routing) {
    final activeCount = (routing.bypassIran ? 1 : 0) +
        (routing.bypassPrivate ? 1 : 0) +
        (routing.blockAds ? 1 : 0) +
        (routing.customSubnets.isNotEmpty ? 1 : 0) +
        (routing.customDomains.isNotEmpty ? 1 : 0);
    final isActive = activeCount > 0;
    return ModernGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(fa: 'مسیریابی هوشمند', en: 'Smart Routing'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t(
                    fa: 'ترافیک انتخابی از خارج تونل عبور می‌کند',
                    en: 'Selected traffic skips the VPN tunnel',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                '$activeCount',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIranToggle(RoutingProvider routing) {
    return _buildToggleTile(
      icon: Icons.flag_rounded,
      iconAccent: _kIranAccent,
      title: _t(fa: 'دور زدن ترافیک ایران', en: 'Bypass Iran traffic'),
      subtitle: _t(
        fa: 'سایت‌ها و سرویس‌های ایرانی بدون VPN باز شوند',
        en: 'Iranian sites and services connect without VPN',
      ),
      value: routing.bypassIran,
      onChanged: routing.setBypassIran,
    );
  }

  Widget _buildPrivateToggle(RoutingProvider routing) {
    return _buildToggleTile(
      icon: Icons.lan_rounded,
      iconAccent: _kLanAccent,
      title: _t(fa: 'دور زدن شبکه محلی', en: 'Bypass LAN / Private'),
      subtitle: _t(
        fa: 'پرینتر، روتر و دستگاه‌های شبکه در دسترس باقی بمانند',
        en: 'Keep printers, router, and local devices reachable',
      ),
      value: routing.bypassPrivate,
      onChanged: routing.setBypassPrivate,
    );
  }

  Widget _buildAdBlockToggle(RoutingProvider routing) {
    return _buildToggleTile(
      icon: Icons.block_rounded,
      iconAccent: _kAdBlockAccent,
      title: _t(fa: 'مسدودسازی تبلیغات', en: 'Block ads'),
      subtitle: _t(
        fa: 'تبلیغات و ردیاب‌ها در سطح شبکه مسدود می‌شوند',
        en: 'Ads and trackers are blocked at the network level',
      ),
      value: routing.blockAds,
      onChanged: routing.setBlockAds,
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconAccent,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return ModernGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            // ignore: deprecated_member_use
            activeColor: iconAccent,
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _buildSubnetHint() {
    return Text(
      _t(
        fa: 'سابنت‌های اضافی به‌صورت CIDR وارد کنید (مثال: 192.0.2.0/24)',
        en: 'Add extra subnets in CIDR form (example: 192.0.2.0/24)',
      ),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11.5,
        height: 1.5,
      ),
    );
  }

  Widget _buildSubnetEditor(RoutingProvider routing) {
    return _ListEditor(
      hint: '10.0.0.0/8',
      accent: _kSubnetAccent,
      addLabel: _t(fa: 'افزودن', en: 'Add'),
      emptyLabel: _t(fa: 'موردی اضافه نشده', en: 'Nothing added yet'),
      invalidLabel: _t(
        fa: 'فرمت CIDR نامعتبر است',
        en: 'Invalid CIDR format',
      ),
      duplicateLabel: _t(fa: 'قبلاً اضافه شده', en: 'Already in the list'),
      items: routing.customSubnets,
      validate: RoutingProvider.isValidCidr,
      onAdd: routing.addCustomSubnet,
      onRemove: routing.removeCustomSubnet,
      // CIDR needs '/' (and ':' for IPv6); a numeric keypad exposes neither,
      // so the user could never type a valid subnet. visiblePassword gives a
      // full keyboard while suppressing autocorrect/suggestions.
      keyboardType: TextInputType.visiblePassword,
    );
  }

  Widget _buildDomainHint() {
    return Text(
      _t(
        fa: 'دامنه‌ها (example.com)، پیشوندها: domain: full: regexp: geosite:',
        en: 'Plain domains (example.com) or prefixes: domain: full: regexp: geosite:',
      ),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11.5,
        height: 1.5,
      ),
    );
  }

  Widget _buildDomainEditor(RoutingProvider routing) {
    return _ListEditor(
      hint: _t(fa: 'example.ir', en: 'example.com'),
      accent: _kDomainAccent,
      addLabel: _t(fa: 'افزودن', en: 'Add'),
      emptyLabel: _t(fa: 'موردی اضافه نشده', en: 'Nothing added yet'),
      invalidLabel: _t(
        fa: 'دامنه نامعتبر است',
        en: 'Invalid domain rule',
      ),
      duplicateLabel: _t(fa: 'قبلاً اضافه شده', en: 'Already in the list'),
      items: routing.customDomains,
      validate: RoutingProvider.isValidDomain,
      onAdd: routing.addCustomDomain,
      onRemove: routing.removeCustomDomain,
      keyboardType: TextInputType.url,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                fa: 'تغییر این تنظیمات در حین اتصال، اتصال را بازسازی می‌کند تا قوانین جدید اعمال شوند.',
                en: 'Changing these while connected will reconnect the VPN to apply the new rules.',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListEditor extends StatefulWidget {
  final String hint;
  final Color accent;
  final String addLabel;
  final String emptyLabel;
  final String invalidLabel;
  final String duplicateLabel;
  final List<String> items;
  final bool Function(String) validate;
  final Future<bool> Function(String) onAdd;
  final Future<void> Function(String) onRemove;
  final TextInputType keyboardType;

  const _ListEditor({
    required this.hint,
    required this.accent,
    required this.addLabel,
    required this.emptyLabel,
    required this.invalidLabel,
    required this.duplicateLabel,
    required this.items,
    required this.validate,
    required this.onAdd,
    required this.onRemove,
    required this.keyboardType,
  });

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (_busy) return;
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    if (!widget.validate(raw)) {
      setState(() => _error = widget.invalidLabel);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await widget.onAdd(raw);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = widget.duplicateLabel);
      return;
    }
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ModernGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: widget.keyboardType,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAdd(),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(253),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: widget.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: widget.accent.withValues(alpha: 0.6),
                          width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _busy ? null : _handleAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: _busy
                      ? const WaveLoading.small(color: Colors.white)
                      : Text(
                          widget.addLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(color: _kDanger, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                widget.emptyLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            )
          else
            Column(
              children: widget.items
                  .map((value) => _buildChip(value))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => widget.onRemove(value),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
