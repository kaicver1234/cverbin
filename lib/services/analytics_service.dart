import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;
  bool _isSupported = false;

  FirebaseAnalytics? get analytics => _analytics;

  /// Check if analytics is supported on this platform
  bool get isSupported => _isSupported;

  /// Initialize Analytics with app info
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Skip analytics on desktop platforms
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      debugPrint('💻 Analytics: Skipped on desktop platform');
      _isSupported = false;
      _isInitialized = true;
      return;
    }
    
    try {
      _analytics = FirebaseAnalytics.instance;
      _isSupported = true;
      
      await _analytics!.setAnalyticsCollectionEnabled(true);
      
      // Set app version as user property
      final packageInfo = await PackageInfo.fromPlatform();
      await setUserProperty(
        name: 'app_version',
        value: packageInfo.version,
      );
      await setUserProperty(
        name: 'build_number',
        value: packageInfo.buildNumber,
      );
      
      _isInitialized = true;
      debugPrint('✅ Analytics initialized successfully');
    } catch (e) {
      debugPrint('❌ Analytics initialization failed: $e');
      _isSupported = false;
    }
  }

  /// Log VPN connection event
  Future<void> logVpnConnect({
    required String serverName,
    required String serverAddress,
    required int serverPort,
    String? country,
    String? protocol,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'vpn_connect',
        parameters: {
          'server_name': serverName,
          'server_address': serverAddress,
          'server_port': serverPort,
          'country': country ?? 'unknown',
          'protocol': protocol ?? 'vmess',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'connection_method': 'manual',
        },
      );
      debugPrint('📊 Analytics: VPN Connect - $serverName');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log auto-connect event
  Future<void> logAutoConnect({
    required String serverName,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'vpn_auto_connect',
        parameters: {
          'server_name': serverName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Auto Connect - $serverName');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log VPN disconnection event
  Future<void> logVpnDisconnect({
    required String serverName,
    required int durationSeconds,
    required int uploadBytes,
    required int downloadBytes,
    String? disconnectReason,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'vpn_disconnect',
        parameters: {
          'server_name': serverName,
          'duration_seconds': durationSeconds,
          'upload_bytes': uploadBytes,
          'download_bytes': downloadBytes,
          'total_bytes': uploadBytes + downloadBytes,
          'disconnect_reason': disconnectReason ?? 'user_action',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: VPN Disconnect - Duration: ${durationSeconds}s, Data: ${(uploadBytes + downloadBytes) / 1024 / 1024}MB');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log connection failure
  Future<void> logConnectionFailure({
    required String serverName,
    required String errorMessage,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'vpn_connection_failure',
        parameters: {
          'server_name': serverName,
          'error_message': errorMessage,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Connection Failure - $serverName');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log subscription addition
  Future<void> logSubscriptionAdded({
    required String subscriptionName,
    required int serverCount,
    required String subscriptionType,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'subscription_added',
        parameters: {
          'subscription_name': subscriptionName,
          'server_count': serverCount,
          'subscription_type': subscriptionType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Subscription Added - $serverCount servers');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log subscription update
  Future<void> logSubscriptionUpdated({
    required String subscriptionName,
    required int newServerCount,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'subscription_updated',
        parameters: {
          'subscription_name': subscriptionName,
          'new_server_count': newServerCount,
        },
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Log app update check
  Future<void> logUpdateCheck({
    required String currentVersion,
    required String latestVersion,
    required bool updateAvailable,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'update_check',
        parameters: {
          'current_version': currentVersion,
          'latest_version': latestVersion,
          'update_available': updateAvailable,
        },
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Log language change
  Future<void> logLanguageChange({
    required String fromLanguage,
    required String toLanguage,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'language_change',
        parameters: {
          'from_language': fromLanguage,
          'to_language': toLanguage,
        },
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Log connection error
  Future<void> logConnectionError({
    required String errorType,
    required String errorMessage,
    String? serverName,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'connection_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          if (serverName != null) 'server_name': serverName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Connection Error - $errorType');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log server ping test
  Future<void> logServerPing({
    required String serverName,
    required int pingMs,
    required bool success,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'server_ping_test',
        parameters: {
          'server_name': serverName,
          'ping_ms': pingMs,
          'success': success,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log server selection
  Future<void> logServerSelection({
    required String serverName,
    required String selectionMethod,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'server_selection',
        parameters: {
          'server_name': serverName,
          'selection_method': selectionMethod, // 'manual', 'auto', 'fastest'
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Server Selected - $serverName ($selectionMethod)');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log app feature usage
  Future<void> logFeatureUsage({
    required String featureName,
    Map<String, dynamic>? additionalParams,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'feature_usage',
        parameters: {
          'feature_name': featureName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          if (additionalParams != null) ...additionalParams,
        },
      );
      debugPrint('📊 Analytics: Feature Used - $featureName');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log user session
  Future<void> logAppOpen() async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logAppOpen();
      debugPrint('📊 Analytics: App Opened');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Log settings change
  Future<void> logSettingsChange({
    required String settingName,
    required String newValue,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.logEvent(
        name: 'settings_change',
        parameters: {
          'setting_name': settingName,
          'new_value': newValue,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Analytics: Setting Changed - $settingName: $newValue');
    } catch (e) {
      debugPrint('⚠️ Analytics error: $e');
    }
  }

  /// Set user property (e.g., preferred language, app version)
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.setUserProperty(
        name: name,
        value: value,
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Set user ID (optional, for tracking specific users)
  Future<void> setUserId(String userId) async {
    if (!_isSupported || _analytics == null) return;
    
    try {
      await _analytics!.setUserId(id: userId);
    } catch (e) {
      // Silently fail
    }
  }
}
