import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class AnnouncementBanner {
  final bool enabled;
  final String message;
  final String? actionUrl;
  final String? actionText;
  final String type; // info, warning, success, error

  AnnouncementBanner({
    required this.enabled,
    required this.message,
    this.actionUrl,
    this.actionText,
    this.type = 'info',
  });
}

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;
  bool _isSupported = false;

  bool get isSupported => _isSupported;

  // Default values
  static const Map<String, dynamic> _defaults = {
    'announcement_enabled': false,
    'announcement_message': '',
    'announcement_action_url': '',
    'announcement_action_text': '',
    'announcement_type': 'info',
    // Social links
    'telegram_id': '@tiksar_vpn',
    'telegram_url': 'https://t.me/tiksar_vpn',
    'instagram_id': '@aboljahany',
    'instagram_url': 'https://instagram.com/aboljahany',
    'tiksar_page_id': '@tiksar_village',
    'tiksar_page_url': 'https://instagram.com/tiksar_village',
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Skip on desktop platforms
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      debugPrint('💻 Remote Config: Skipped on desktop');
      _isSupported = false;
      _isInitialized = true;
      return;
    }

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ));

      await _remoteConfig!.setDefaults(_defaults.map(
        (key, value) => MapEntry(key, value.toString()),
      ));

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();

      _isSupported = true;
      _isInitialized = true;
      debugPrint('✅ Remote Config initialized');
    } catch (e) {
      debugPrint('⚠️ Remote Config error: $e');
      _isSupported = false;
      _isInitialized = true;
    }
  }

  /// Refresh config from server
  Future<void> refresh() async {
    if (!_isSupported || _remoteConfig == null) return;

    try {
      await _remoteConfig!.fetchAndActivate();
      debugPrint('🔄 Remote Config refreshed');
    } catch (e) {
      debugPrint('⚠️ Remote Config refresh error: $e');
    }
  }

  /// Get announcement banner config
  AnnouncementBanner getAnnouncementBanner() {
    if (!_isSupported || _remoteConfig == null) {
      return AnnouncementBanner(enabled: false, message: '');
    }

    return AnnouncementBanner(
      enabled: _remoteConfig!.getBool('announcement_enabled'),
      message: _remoteConfig!.getString('announcement_message'),
      actionUrl: _remoteConfig!.getString('announcement_action_url'),
      actionText: _remoteConfig!.getString('announcement_action_text'),
      type: _remoteConfig!.getString('announcement_type'),
    );
  }

  /// Get social links
  String get telegramId {
    if (!_isSupported || _remoteConfig == null) return '@tiksar_vpn';
    final value = _remoteConfig!.getString('telegram_id');
    return value.isNotEmpty ? value : '@tiksar_vpn';
  }

  String get telegramUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://t.me/tiksar_vpn';
    final value = _remoteConfig!.getString('telegram_url');
    return value.isNotEmpty ? value : 'https://t.me/tiksar_vpn';
  }

  String get instagramId {
    if (!_isSupported || _remoteConfig == null) return '@aboljahany';
    final value = _remoteConfig!.getString('instagram_id');
    return value.isNotEmpty ? value : '@aboljahany';
  }

  String get instagramUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://instagram.com/aboljahany';
    final value = _remoteConfig!.getString('instagram_url');
    return value.isNotEmpty ? value : 'https://instagram.com/aboljahany';
  }

  String get tiksarPageId {
    if (!_isSupported || _remoteConfig == null) return '@tiksar_village';
    final value = _remoteConfig!.getString('tiksar_page_id');
    return value.isNotEmpty ? value : '@tiksar_village';
  }

  String get tiksarPageUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://instagram.com/tiksar_village';
    final value = _remoteConfig!.getString('tiksar_page_url');
    return value.isNotEmpty ? value : 'https://instagram.com/tiksar_village';
  }
}
