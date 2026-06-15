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
    'maintenance_mode': false,
    'maintenance_message': 'سرویس در حال بروزرسانی است',
    // About description
    'about_description_en': 'TiksarVPN is a powerful tool for accessing the free internet. Break through restrictions and enjoy unlimited access to the global internet with complete privacy and security.',
    'about_description_fa': 'تیکسر وی پی ان ابزاری قدرتمند برای دسترسی به اینترنت آزاد است. محدودیت‌ها را بشکنید و با حفظ کامل حریم خصوصی و امنیت، از دسترسی نامحدود به اینترنت جهانی لذت ببرید.',
    // Social links
    'telegram_id': '@tiksar_vpn',
    'telegram_url': 'https://t.me/tiksar_vpn',
    'instagram_id': '@aboljahany',
    'instagram_url': 'https://instagram.com/aboljahany',
    'tiksar_page_id': '@tiksaar_leyl_gilan',
    'tiksar_page_url': 'https://instagram.com/tiksaar_leyl_gilan',
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
        minimumFetchInterval: const Duration(seconds: 30), // Faster refresh for testing
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
    final id = _remoteConfig!.getString('telegram_id');
    return id.isNotEmpty ? id : '@tiksar_vpn';
  }

  String get telegramUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://t.me/tiksar_vpn';
    final url = _remoteConfig!.getString('telegram_url');
    return url.isNotEmpty ? url : 'https://t.me/tiksar_vpn';
  }

  String get instagramId {
    if (!_isSupported || _remoteConfig == null) return '@aboljahany';
    final id = _remoteConfig!.getString('instagram_id');
    return id.isNotEmpty ? id : '@aboljahany';
  }

  String get instagramUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://instagram.com/aboljahany';
    final url = _remoteConfig!.getString('instagram_url');
    return url.isNotEmpty ? url : 'https://instagram.com/aboljahany';
  }

  String get tiksarPageId {
    if (!_isSupported || _remoteConfig == null) return '@tiksaar_leyl_gilan';
    final id = _remoteConfig!.getString('tiksar_page_id');
    return id.isNotEmpty ? id : '@tiksaar_leyl_gilan';
  }

  String get tiksarPageUrl {
    if (!_isSupported || _remoteConfig == null) return 'https://instagram.com/tiksaar_leyl_gilan';
    final url = _remoteConfig!.getString('tiksar_page_url');
    return url.isNotEmpty ? url : 'https://instagram.com/tiksaar_leyl_gilan';
  }

  /// Get about description based on language
  String getAboutDescription(String languageCode) {
    if (!_isSupported || _remoteConfig == null) {
      return languageCode == 'fa'
          ? 'تیکسر وی پی ان ابزاری قدرتمند برای دسترسی به اینترنت آزاد است. محدودیت‌ها را بشکنید و با حفظ کامل حریم خصوصی و امنیت، از دسترسی نامحدود به اینترنت جهانی لذت ببرید.'
          : 'TiksarVPN is a powerful tool for accessing the free internet. Break through restrictions and enjoy unlimited access to the global internet with complete privacy and security.';
    }
    
    final key = 'about_description_$languageCode';
    final description = _remoteConfig!.getString(key);
    
    if (description.isNotEmpty) {
      return description;
    }
    
    // Fallback to default
    return languageCode == 'fa'
        ? 'تیکسر وی پی ان ابزاری قدرتمند برای دسترسی به اینترنت آزاد است. محدودیت‌ها را بشکنید و با حفظ کامل حریم خصوصی و امنیت، از دسترسی نامحدود به اینترنت جهانی لذت ببرید.'
        : 'TiksarVPN is a powerful tool for accessing the free internet. Break through restrictions and enjoy unlimited access to the global internet with complete privacy and security.';
  }
}
