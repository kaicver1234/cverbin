import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/dns_provider.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF111111);
const _kBorder = Color(0xFF222222);

class DnsSettingsScreen extends StatefulWidget {
  const DnsSettingsScreen({super.key});

  @override
  State<DnsSettingsScreen> createState() => _DnsSettingsScreenState();
}

class _DnsSettingsScreenState extends State<DnsSettingsScreen> {
  final _primaryCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(screenName: 'Safheh_Tanzimate_DNS');
    final dns = Provider.of<DnsProvider>(context, listen: false);
    _primaryCtrl.text = dns.customPrimary;
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    super.dispose();
  }

  bool _isValidIp(String value) {
    if (value.isEmpty) return true;
    final parts = value.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }

  Future<void> _saveCustomDns() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dns = Provider.of<DnsProvider>(context, listen: false);
    await dns.setCustomDns(_primaryCtrl.text);
    await dns.selectPreset(DnsPreset.custom);
    AnalyticsService().logDnsChange(dnsType: 'custom', dnsValue: _primaryCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRtl ? 'DNS سفارشی ذخیره شد' : 'Custom DNS saved',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  bool get _isRtl {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return lang.currentLanguage.direction == 'rtl';
  }

  IconData _iconForPreset(DnsPreset preset) {
    switch (preset) {
      case DnsPreset.google:     return Icons.dns_rounded;
      case DnsPreset.cloudflare: return Icons.cloud_rounded;
      case DnsPreset.openDns:    return Icons.lock_open_rounded;
      case DnsPreset.quad9:      return Icons.security_rounded;
      case DnsPreset.custom:     return Icons.tune_rounded;
    }
  }

  String _badgeLabel(String? raw, bool isRtl) {
    if (raw == null) return '';
    if (raw == 'Default') return isRtl ? 'پیش‌فرض' : 'Default';
    return raw;
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
            isRtl ? 'سرور DNS' : 'DNS Server',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Consumer<DnsProvider>(
          builder: (context, dns, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(isRtl ? 'انتخاب DNS' : 'Select DNS'),
                  const SizedBox(height: 12),

                  ...DnsProvider.presets.asMap().entries.map((entry) {
                    final i   = entry.key;
                    final opt = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < DnsProvider.presets.length - 1 ? 10 : 0),
                      child: _buildPresetCard(
                        dns: dns,
                        option: opt,
                        isRtl: isRtl,
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  _buildPresetCard(
                    dns: dns,
                    option: DnsOption(
                      preset: DnsPreset.custom,
                      name: isRtl ? 'DNS سفارشی' : 'Custom DNS',
                      description: isRtl ? 'تنظیم دستی آدرس DNS' : 'Set DNS address manually',
                      servers: [],
                    ),
                    isRtl: isRtl,
                  ),

                  const SizedBox(height: 28),

                  if (dns.selectedPreset == DnsPreset.custom) ...[
                    _buildSectionLabel(isRtl ? 'آدرس DNS سفارشی' : 'Custom DNS Address'),
                    const SizedBox(height: 12),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildDnsField(
                            controller: _primaryCtrl,
                            label: isRtl ? 'آدرس DNS' : 'DNS Address',
                            hint: '8.8.8.8',
                            isRtl: isRtl,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _saveCustomDns,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isRtl ? 'ذخیره' : 'Save',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  _buildInfoBox(isRtl),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
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

  Widget _buildPresetCard({
    required DnsProvider dns,
    required DnsOption option,
    required bool isRtl,
  }) {
    final isSelected = dns.selectedPreset == option.preset;
    final badge = _badgeLabel(option.badge, isRtl);

    return GestureDetector(
      onTap: () {
        dns.selectPreset(option.preset);
        AnalyticsService().logDnsChange(
          dnsType: option.preset.name,
          dnsValue: option.name,
        );
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
              child: Icon(_iconForPreset(option.preset), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (badge.isNotEmpty) ...[
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
                    option.description,
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

  Widget _buildDnsField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRtl,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          textDirection: TextDirection.ltr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\.]')),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 14,
            ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) {
              return isRtl ? 'این فیلد الزامی است' : 'This field is required';
            }
            if (v != null && v.trim().isNotEmpty && !_isValidIp(v.trim())) {
              return isRtl ? 'آدرس IP معتبر نیست' : 'Invalid IP address';
            }
            return null;
          },
        ),
      ],
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
          Icon(Icons.info_outline_rounded, color: Colors.white.withValues(alpha: 0.35), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRtl
                  ? 'DNS انتخاب شده هنگام اتصال به VPN اعمال می‌شود. برای DNS سفارشی، آدرس IP مورد نظر خود را وارد کنید.'
                  : 'The selected DNS will be applied when connecting to VPN. For custom DNS, enter any DNS server IP address.',
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
}
