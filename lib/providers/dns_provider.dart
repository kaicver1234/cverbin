import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DnsPreset { google, cloudflare, openDns, quad9, custom }

class DnsOption {
  final DnsPreset preset;
  final String name;
  final String description;
  final List<String> servers;
  final String? badge;

  const DnsOption({
    required this.preset,
    required this.name,
    required this.description,
    required this.servers,
    this.badge,
  });
}

class DnsProvider with ChangeNotifier {
  static const String _presetKey = 'dns_preset_id';
  static const String _customPrimaryKey = 'dns_custom_primary';
  static const String _customSecondaryKey = 'dns_custom_secondary';

  static const List<DnsOption> presets = [
    DnsOption(
      preset: DnsPreset.google,
      name: 'Google DNS',
      description: '8.8.8.8 · 8.8.4.4',
      servers: ['8.8.8.8', '8.8.4.4'],
      badge: 'Default',
    ),
    DnsOption(
      preset: DnsPreset.cloudflare,
      name: 'Cloudflare',
      description: '1.1.1.1 · 1.0.0.1',
      servers: ['1.1.1.1', '1.0.0.1'],
    ),
    DnsOption(
      preset: DnsPreset.openDns,
      name: 'OpenDNS',
      description: '208.67.222.222 · 208.67.220.220',
      servers: ['208.67.222.222', '208.67.220.220'],
    ),
    DnsOption(
      preset: DnsPreset.quad9,
      name: 'Quad9',
      description: '9.9.9.9 · 149.112.112.112',
      servers: ['9.9.9.9', '149.112.112.112'],
      badge: 'Secure',
    ),
  ];

  DnsPreset _selectedPreset = DnsPreset.google;
  String _customPrimary = '';
  String _customSecondary = '';

  DnsPreset get selectedPreset => _selectedPreset;
  String get customPrimary => _customPrimary;
  String get customSecondary => _customSecondary;

  DnsOption get selectedOption {
    if (_selectedPreset == DnsPreset.custom) {
      return DnsOption(
        preset: DnsPreset.custom,
        name: 'Custom',
        description: _customPrimary.isNotEmpty
            ? '$_customPrimary${_customSecondary.isNotEmpty ? ' · $_customSecondary' : ''}'
            : 'Not configured',
        servers: [
          if (_customPrimary.isNotEmpty) _customPrimary,
          if (_customSecondary.isNotEmpty) _customSecondary,
        ],
      );
    }
    return presets.firstWhere((o) => o.preset == _selectedPreset);
  }

  List<String> get activeServers {
    final servers = selectedOption.servers;
    if (servers.isEmpty) return ['8.8.8.8', '8.8.4.4'];
    return servers;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_presetKey);
    if (saved != null) {
      try {
        _selectedPreset = DnsPreset.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => DnsPreset.google,
        );
      } catch (_) {
        _selectedPreset = DnsPreset.google;
      }
    }
    _customPrimary = prefs.getString(_customPrimaryKey) ?? '';
    _customSecondary = prefs.getString(_customSecondaryKey) ?? '';
    notifyListeners();
  }

  Future<void> selectPreset(DnsPreset preset) async {
    _selectedPreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, preset.name);
    notifyListeners();
  }

  Future<void> setCustomDns(String primary, String secondary) async {
    _customPrimary = primary.trim();
    _customSecondary = secondary.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPrimaryKey, _customPrimary);
    await prefs.setString(_customSecondaryKey, _customSecondary);
    notifyListeners();
  }
}
