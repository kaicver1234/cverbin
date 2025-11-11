import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiksarvpn/models/v2ray_config.dart';
import 'package:tiksarvpn/models/subscription.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tiksarvpn/services/ping_service.dart';

class IpInfo {
  final String ip;
  final String country;
  final String city;
  final String countryCode;
  final bool success;
  final String? errorMessage;

  IpInfo({
    required this.ip,
    required this.country,
    required this.city,
    required this.countryCode,
    required this.success,
    this.errorMessage,
  });

  factory IpInfo.fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['ip'] ?? '',
      country: json['country_name'] ?? '',
      city: json['city_name'] ?? '',
      countryCode: json['country_code'] ?? '',
      success: true,
      errorMessage: null,
    );
  }

  factory IpInfo.error(String message) {
    return IpInfo(
      ip: '',
      country: '',
      city: '',
      countryCode: '',
      success: false,
      errorMessage: message,
    );
  }

  String get locationString => '$country - $city';
}

class V2RayService extends ChangeNotifier {
  Function()? _onDisconnected;
  bool _isInitialized = false;
  V2RayConfig? _activeConfig;
  Timer? _statusCheckTimer;
  DateTime? _lastConnectionTime;

  // IP Information
  IpInfo? _ipInfo;
  IpInfo? get ipInfo => _ipInfo;

  bool _isLoadingIpInfo = false;
  bool get isLoadingIpInfo => _isLoadingIpInfo;

  // Usage statistics
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  int _connectedSeconds = 0;
  Timer? _usageStatsTimer;

  // Ping cache with timestamp
  final Map<String, ({int? delay, DateTime timestamp})> _pingCache = {};
  final Map<String, bool> _pingInProgress = {};

  // Get list of installed apps (Android only)
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      // On Android, use the method channel to get installed apps
      if (defaultTargetPlatform == TargetPlatform.android) {
        const platform = MethodChannel('com.tiksarvpn.app/app_list');
        final List<dynamic> result = await platform.invokeMethod(
          'getInstalledApps',
        );

        // Convert the result to a List<Map<String, dynamic>>
        final List<Map<String, dynamic>> appList = result
            .map(
              (app) => {
                'packageName': app['packageName'] as String,
                'name': app['name'] as String,
                'isSystemApp': app['isSystemApp'] as bool,
              },
            )
            .toList();

        return appList;
      } else {
        // Return empty list on non-Android platforms
        return [];
      }
    } catch (e) {
      // Error getting installed apps
      return [];
    }
  }

  // Clear ping cache for all configs or a specific config
  void clearPingCache({String? configId}) {
    if (configId != null) {
      _pingCache.remove(configId);
    } else {
      _pingCache.clear();
    }
    // Also clear native ping service cache
    NativePingService.clearCache();
  }

  // Singleton pattern
  static final V2RayService _instance = V2RayService._internal();
  factory V2RayService() => _instance;

  late final FlutterV2ray _flutterV2ray;

  // Current V2Ray status from the callback
  V2RayStatus? _currentStatus;
  V2RayStatus? get currentStatus => _currentStatus;

  V2RayService._internal() {
    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        _currentStatus = status;
        _handleStatusChange(status);
        notifyListeners(); // Notify listeners when status changes
      },
    );

    // Load saved usage statistics
    _loadUsageStats();
  }


  void _handleStatusChange(V2RayStatus status) {
    // Handle disconnection from notification
    // Check for common disconnected status values using string matching
    String statusString = status.toString().toLowerCase();
    String stateString = status.state.toLowerCase();
    
    // Check if disconnected by multiple indicators
    bool isDisconnected = statusString.contains('disconnect') ||
        statusString.contains('stop') ||
        statusString.contains('idle') ||
        stateString.contains('disconnect') ||
        stateString.contains('stopped') ||
        stateString.contains('idle') ||
        stateString == 'disconnected' ||
        stateString.isEmpty; // Empty state also means disconnected
    
    if (isDisconnected && _activeConfig != null) {
      // Detected disconnection from notification
      _activeConfig = null;
      _onDisconnected?.call();

      // Save the disconnected state immediately
      _clearActiveConfig();
      notifyListeners();
    }
    
    // Also check if we're now connected when we weren't before
    bool isConnected = stateString.contains('connect') ||
        stateString == 'connected' ||
        statusString.contains('connected');
    
    if (isConnected && _activeConfig == null) {
      // VPN connected but we don't have active config
      // Try to restore from saved config
      _tryRestoreActiveConfig().then((_) {
        notifyListeners();
      });
    }
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _flutterV2ray.initializeV2Ray(
        notificationIconResourceType: "drawable",
        notificationIconResourceName: "ic_notification",
      );
      _isInitialized = true;

      // Try to restore active config if VPN is still running
      await _tryRestoreActiveConfig();
    }
  }

  Future<bool> connect(V2RayConfig config) async {
    try {
      await initialize();

      // Parse the configuration
      V2RayURL parser = FlutterV2ray.parseFromURL(config.fullConfig);

      // Request permission if needed (for VPN mode)
      bool hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission) {
        return false;
      }

      // Start V2Ray in VPN mode - simplified without extra features
      await _flutterV2ray.startV2Ray(
        remark: config.remark,
        config: parser.getFullConfiguration(),
        proxyOnly: false, // Always use VPN mode (not proxy mode)
        notificationDisconnectButtonName: "DISCONNECT",
      );

      _activeConfig = config;
      _lastConnectionTime = DateTime.now();
      
      // Notify listeners immediately for UI update
      notifyListeners();

      // Save active config to persistent storage
      await _saveActiveConfig(config);

      // Start monitoring usage statistics
      _startUsageMonitoring();

      // Fetch IP information after a 2-second delay to ensure connection is stable
      Future.delayed(const Duration(seconds: 2), () {
        fetchIpInfo()
            .then((ipInfo) {
              // IP Info fetched after connection
            })
            .catchError((e) {
              // Error fetching IP info after connection
            });
      });

      return true;
    } catch (e) {
      // Error connecting to V2Ray
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      // Stop usage monitoring
      _stopUsageMonitoring();

      // Save current usage statistics before clearing active config
      await _saveUsageStats();

      await _flutterV2ray.stopV2Ray();

      // Clear active config and last connection time
      _activeConfig = null;
      _lastConnectionTime = null;
      
      // Notify listeners immediately for UI update
      notifyListeners();

      // Clear active config from storage but keep the usage statistics
      await _clearActiveConfig();

      // Update the last connection time in storage to null
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_connection_time');
    } catch (e) {
      // Error disconnecting from V2Ray
    }
  }

  Future<void> _saveActiveConfig(V2RayConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_config', jsonEncode(config.toJson()));
    // Also save as selected config for UI state persistence
    await _saveSelectedConfig(config);
  }

  Future<void> _saveSelectedConfig(V2RayConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_config', jsonEncode(config.toJson()));
  }

  // Public method to save selected config
  Future<void> saveSelectedConfig(V2RayConfig config) async {
    await _saveSelectedConfig(config);
  }

  Future<void> _clearActiveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_config');
  }

  Future<V2RayConfig?> _loadActiveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? configJson = prefs.getString('active_config');
    if (configJson == null) return null;
    return V2RayConfig.fromJson(jsonDecode(configJson));
  }

  Future<V2RayConfig?> loadSelectedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? configJson = prefs.getString('selected_config');
    if (configJson == null) return null;
    return V2RayConfig.fromJson(jsonDecode(configJson));
  }

  Future<void> _tryRestoreActiveConfig() async {
    try {
      // First, try to load saved config
      final savedConfig = await _loadActiveConfig();
      
      if (savedConfig == null) {
        // No saved config, nothing to restore
        debugPrint('ℹ️ No saved active config found');
        return;
      }
      
      // OPTIMISTIC RESTORE: If we have a saved config, restore it immediately
      // This ensures UI shows connected state right away
      debugPrint('✅ Found saved config: ${savedConfig.remark}');
      _activeConfig = savedConfig;
      
      // Restore connection time and start monitoring immediately
      await _restoreConnectionTime();
      _startUsageMonitoring();
      
      // Notify listeners immediately so UI updates right away
      notifyListeners();
      debugPrint('✅ Active config restored optimistically for UI');
      
      // Now verify in background (non-blocking)
      // This happens asynchronously and won't delay UI display
      _verifyConnectionInBackground();
      
    } catch (e) {
      debugPrint('❌ Error restoring active config: $e');
      // Try to restore from saved config as fallback
      try {
        final savedConfig = await _loadActiveConfig();
        if (savedConfig != null) {
          _activeConfig = savedConfig;
          await _restoreConnectionTime();
          _startUsageMonitoring();
          notifyListeners();
          debugPrint('✅ Restored config from fallback despite error');
        } else {
          await _clearActiveConfig();
          _activeConfig = null;
          notifyListeners();
        }
      } catch (fallbackError) {
        debugPrint('❌ Complete failure restoring config: $fallbackError');
        // Complete failure - clear everything
        await _clearActiveConfig();
        _activeConfig = null;
        notifyListeners();
      }
    }
  }
  
  // Verify connection in background without blocking UI
  void _verifyConnectionInBackground() async {
    try {
      debugPrint('🔎 Verifying connection in background...');
      
      // Try multiple times to check if VPN is actually running
      bool? isConnected;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          // Check if VPN is actually running with timeout
          final delay = await _flutterV2ray.getConnectedServerDelay()
              .timeout(const Duration(seconds: 8));
          isConnected = delay >= 0 && delay < 10000;
          debugPrint('🔎 Delay check result: ${delay}ms, connected: $isConnected');
          break; // Success, exit retry loop
        } catch (e) {
          debugPrint('⚠️ Delay check attempt ${attempt + 1} failed: $e');
          // Timeout or error - retry
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      if (isConnected == false) {
        // VPN is definitely not running, clear active config
        debugPrint('❌ Background verification: VPN is NOT running');
        _activeConfig = null;
        await _clearActiveConfig();
        notifyListeners();
      } else {
        // Either verified as connected or couldn't verify (keep optimistic state)
        debugPrint('✅ Background verification: VPN appears to be running');
      }
    } catch (e) {
      debugPrint('⚠️ Error during background verification: $e');
      // Keep optimistic state on verification error
    }
  }

  Future<void> _restoreConnectionTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastConnectionTimeStr = prefs.getString('last_connection_time');

    if (lastConnectionTimeStr != null) {
      try {
        final lastConnectionTime = DateTime.parse(lastConnectionTimeStr);
        final now = DateTime.now();
        final elapsedSeconds = now.difference(lastConnectionTime).inSeconds;

        // Load existing connected seconds
        _connectedSeconds = prefs.getInt('connected_seconds') ?? 0;

        // If the app was closed recently (less than 1 hour), add the elapsed time
        if (elapsedSeconds > 0 && elapsedSeconds < 60 * 60) {
          _connectedSeconds += elapsedSeconds;
          // Restored connection time
        } else {
          // Restored connection time
        }

        // Update last connection time to now for future tracking
        _lastConnectionTime = now;
        await _saveUsageStats();
      } catch (e) {
        // Error parsing last connection time
        _lastConnectionTime = DateTime.now();
        _connectedSeconds = prefs.getInt('connected_seconds') ?? 0;
      }
    } else {
      // No saved connection time, start fresh but keep existing connected seconds
      _lastConnectionTime = DateTime.now();
      _connectedSeconds = prefs.getInt('connected_seconds') ?? 0;
      // No previous connection time found
      await _saveUsageStats();
    }
  }

  // Get server delay/ping for a specific config using V2Ray's built-in method
  Future<int?> getServerDelay(V2RayConfig config) async {
    final configId = config.id;
    final hostKey = '${config.address}:${config.port}';

    try {
      // Return cached ping if available and not expired (30 seconds)
      if (_pingCache.containsKey(hostKey)) {
        final cached = _pingCache[hostKey];
        final ageSeconds = DateTime.now().difference(cached!.timestamp).inSeconds;
        if (ageSeconds < 30) {
          return cached.delay;
        }
      } else if (_pingCache.containsKey(configId)) {
        final cached = _pingCache[configId];
        final ageSeconds = DateTime.now().difference(cached!.timestamp).inSeconds;
        if (ageSeconds < 30) {
          return cached.delay;
        }
      }

      // Check if ping is already in progress for this host or config
      if (_pingInProgress[hostKey] == true ||
          _pingInProgress[configId] == true) {
        // Return cached result immediately if exists, don't wait
        return _pingCache[hostKey]?.delay ?? _pingCache[configId]?.delay;
      }

      // Mark this host and config as having ping in progress
      _pingInProgress[hostKey] = true;
      _pingInProgress[configId] = true;

      try {
        // Use V2Ray's built-in ping method for better accuracy
        await initialize();

        final parser = FlutterV2ray.parseFromURL(config.fullConfig);
        final delay = await _flutterV2ray
            .getServerDelay(config: parser.getFullConfiguration())
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⚠️ Ping timeout for ${config.remark}');
                throw Exception('V2Ray ping timeout');
              },
            );

        // Cache the result by both host and config ID with timestamp
        if (delay >= -1 && delay < 10000) {
          final now = DateTime.now();
          _pingCache[hostKey] = (delay: delay, timestamp: now);
          _pingCache[configId] = (delay: delay, timestamp: now);

          _pingInProgress[hostKey] = false;
          _pingInProgress[configId] = false;

          return delay;
        } else {
          _pingInProgress[hostKey] = false;
          _pingInProgress[configId] = false;
          _pingCache.remove(hostKey);
          _pingCache.remove(configId);
          return null;
        }
      } catch (e) {
        debugPrint('❌ Error testing ${config.remark}: $e');
        _pingInProgress[hostKey] = false;
        _pingInProgress[configId] = false;
        _pingCache.remove(hostKey);
        _pingCache.remove(configId);
        return null;
      } finally {
        // Always cleanup progress flags
        _pingInProgress[hostKey] = false;
        _pingInProgress[configId] = false;
      }
    } catch (e) {
      // Unexpected error in getServerDelay
      debugPrint('❌ Unexpected error in getServerDelay: $e');
      // Ensure cleanup even in unexpected errors
      _pingInProgress[hostKey] = false;
      _pingInProgress[configId] = false;
      return null;
    }
  }

  Future<List<V2RayConfig>> parseSubscriptionUrl(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Network timeout: Check your internet connection',
              );
            },
          );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load subscription: HTTP ${response.statusCode}',
        );
      }

      final List<V2RayConfig> configs = [];
      String content = response.body;

      // Try to decode as base64 first
      try {
        // Check if the content looks like base64
        if (_isBase64(content)) {
          final decoded = utf8.decode(base64.decode(content.trim()));
          // If decoding succeeds, use the decoded content
          content = decoded;
          // Successfully decoded base64 content
        }
      } catch (e) {
        // If base64 decoding fails, use the original content
        // Not a valid base64 content, using original
      }

      final List<String> lines = content.split('\n');

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        try {
          if (line.startsWith('vmess://') ||
              line.startsWith('vless://') ||
              line.startsWith('ss://')) {
            V2RayURL parser = FlutterV2ray.parseFromURL(line);
            String configType = '';

            if (line.startsWith('vmess://')) {
              configType = 'vmess';
            } else if (line.startsWith('vless://')) {
              configType = 'vless';
            } else if (line.startsWith('ss://')) {
              configType = 'shadowsocks';
            }

            // Use the parsed address and port from the V2RayURL parser
            String address = parser.address;
            int port = parser.port;

            configs.add(
              V2RayConfig(
                id:
                    DateTime.now().millisecondsSinceEpoch.toString() +
                    configs.length.toString(),
                remark: parser.remark,
                address: address,
                port: port,
                configType: configType,
                fullConfig: line,
              ),
            );
          }
        } catch (e) {
          // Error parsing config
        }
      }

      if (configs.isEmpty) {
        throw Exception('No valid configurations found in subscription');
      }

      return configs;
    } catch (e) {
      // Error parsing subscription

      // Provide more specific error messages based on exception type
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception('Network error: Check your internet connection');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Connection timeout: Server is not responding');
      } else if (e.toString().contains('Invalid URL')) {
        throw Exception('Invalid subscription URL format');
      } else if (e.toString().contains('No valid configurations')) {
        throw Exception('No valid servers found in subscription');
      } else {
        throw Exception('Failed to update subscription: ${e.toString()}');
      }
    }
  }

  // Save and load configurations
  Future<void> saveConfigs(List<V2RayConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configsJson = configs
        .map((config) => jsonEncode(config.toJson()))
        .toList();
    await prefs.setStringList('v2ray_configs', configsJson);
  }

  Future<List<V2RayConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? configsJson = prefs.getStringList('v2ray_configs');
    if (configsJson == null) return [];

    return configsJson
        .map((json) => V2RayConfig.fromJson(jsonDecode(json)))
        .toList();
  }

  // Save and load subscriptions
  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> subscriptionsJson = subscriptions
        .map((sub) => jsonEncode(sub.toJson()))
        .toList();
    await prefs.setStringList('v2ray_subscriptions', subscriptionsJson);
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? subscriptionsJson = prefs.getStringList(
      'v2ray_subscriptions',
    );
    if (subscriptionsJson == null) return [];

    return subscriptionsJson
        .map((json) => Subscription.fromJson(jsonDecode(json)))
        .toList();
  }

  void setDisconnectedCallback(Function() callback) {
    _onDisconnected = callback;
    // Disable automatic monitoring to prevent false disconnects
    // _startStatusMonitoring();
  }

  void _stopStatusMonitoring() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  // Helper method to check if a string is valid base64
  bool _isBase64(String str) {
    // Remove any whitespace
    str = str.trim();
    // Check if the length is valid for base64 (multiple of 4)
    if (str.length % 4 != 0) {
      return false;
    }
    // Check if the string contains only valid base64 characters
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(str);
  }

  // Removed getConnectedServerDelay method as requested

  // Fetch IP information from ipleak.net API
  Future<IpInfo> fetchIpInfo() async {
    // Set loading state
    _isLoadingIpInfo = true;
    notifyListeners();

    const String apiUrl = 'https://ipleak.net/json/';
    int retryCount = 0;
    const int maxRetries = 5;

    try {
      while (retryCount < maxRetries) {
        try {
          // Fetching IP info attempt
          final response = await http.get(Uri.parse(apiUrl));

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            final ipInfo = IpInfo.fromJson(data);

            _ipInfo = ipInfo;
            _isLoadingIpInfo = false;
            notifyListeners();
            // IP info fetched successfully
            return ipInfo;
          } else {
            // HTTP error
            retryCount++;
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          // Error fetching IP info
          retryCount++;
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // After max retries, return error
      final errorInfo = IpInfo.error('Cannot get IP information');
      _ipInfo = errorInfo;
      _isLoadingIpInfo = false;
      notifyListeners();
      // Failed to fetch IP info after max retries
      return errorInfo;
    } catch (e) {
      // Handle any unexpected errors
      // Unexpected error fetching IP info
      final errorInfo = IpInfo.error('Error: $e');
      _ipInfo = errorInfo;
      _isLoadingIpInfo = false;
      notifyListeners();
      return errorInfo;
    }
  }

  // Getter to check if connected to a server
  bool get isConnected => _activeConfig != null;

  // Getter to access the active config
  V2RayConfig? get activeConfig => _activeConfig;

  // Public method to force check connection status
  Future<bool> isActuallyConnected() async {
    try {
      debugPrint('🔎 Checking if VPN is actually connected...');
      
      // Method 1: Check V2Ray core status
      final currentState = _currentStatus?.state.toLowerCase() ?? '';
      debugPrint('🔎 Current V2Ray state: $currentState');
      
      // If status explicitly says connected, verify it
      if (currentState.contains('connect') || currentState == 'connected') {
        debugPrint('✅ V2Ray reports connected');
        
        // Double-check with delay test
        try {
          final delay = await _flutterV2ray.getConnectedServerDelay()
              .timeout(const Duration(seconds: 3));
          final hasValidConnection = delay >= 0 && delay < 10000;
          
          if (hasValidConnection) {
            debugPrint('✅ Connection verified with delay: ${delay}ms');
            // Update active config if needed
            if (_activeConfig == null) {
              await _tryRestoreActiveConfig();
            }
            return true;
          } else {
            debugPrint('⚠️ Delay check failed: ${delay}ms');
          }
        } catch (delayError) {
          debugPrint('⚠️ Delay check error: $delayError');
          // Status says connected but delay check failed
          // Check saved config as fallback
          final savedConfig = await _loadActiveConfig();
          if (savedConfig != null) {
            _activeConfig = savedConfig;
            debugPrint('✅ Connected (verified via saved config)');
            return true;
          }
        }
      }
      
      // If status explicitly says disconnected
      if (currentState.contains('disconnect') || 
          currentState.contains('stop') || 
          currentState.contains('idle') ||
          currentState == 'disconnected' ||
          currentState.isEmpty) {
        debugPrint('❌ V2Ray reports disconnected');
        
        // Triple-check with saved config and delay
        final savedConfig = await _loadActiveConfig();
        if (savedConfig != null) {
          debugPrint('🔎 Found saved config, verifying with delay test...');
          
          try {
            final delay = await _flutterV2ray.getConnectedServerDelay()
                .timeout(const Duration(seconds: 3));
            final hasValidConnection = delay >= 0 && delay < 10000;
            
            if (hasValidConnection) {
              _activeConfig = savedConfig;
              debugPrint('✅ Connected (state wrong but delay test passed)');
              return true;
            }
          } catch (delayError) {
            debugPrint('❌ Delay test failed, truly disconnected');
          }
        }
        
        // Truly disconnected
        if (_activeConfig != null) {
          _activeConfig = null;
          await _clearActiveConfig();
          notifyListeners();
        }
        return false;
      }

      // Method 2: Status is unknown/unclear, use delay test
      debugPrint('🔎 Status unclear, using delay test...');
      try {
        final delay = await _flutterV2ray.getConnectedServerDelay()
            .timeout(const Duration(seconds: 5));
        final isConnected = delay >= 0 && delay < 10000;
        
        debugPrint('🔎 Delay test result: ${delay}ms, connected: $isConnected');
        
        if (isConnected && _activeConfig == null) {
          // Connected but no active config, try to restore
          await _tryRestoreActiveConfig();
        } else if (!isConnected && _activeConfig != null) {
          // Not connected but we have active config, clear it
          _activeConfig = null;
          await _clearActiveConfig();
          notifyListeners();
        }
        
        return isConnected;
      } catch (timeoutError) {
        debugPrint('⚠️ Delay test timeout: $timeoutError');
        
        // Method 3: Fallback to saved config check
        final savedConfig = await _loadActiveConfig();
        if (savedConfig != null) {
          _activeConfig = savedConfig;
          debugPrint('✅ Connected (based on saved config)');
          return true;
        }
        
        if (_activeConfig != null) {
          // Assume still connected if we have active config in memory
          debugPrint('✅ Connected (based on active config in memory)');
          return true;
        }
        
        debugPrint('❌ All checks failed, disconnected');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking connection: $e');
      
      // Final fallback - check saved config
      try {
        final savedConfig = await _loadActiveConfig();
        if (savedConfig != null) {
          _activeConfig = savedConfig;
          debugPrint('✅ Connected (fallback to saved config)');
          return true;
        }
      } catch (restoreError) {
        debugPrint('❌ Failed to restore config: $restoreError');
      }
      
      return false;
    }
  }

  /// Get real-time ping monitoring for the currently connected server
  /// Returns a stream of ping results that updates at the specified interval
  Stream<PingResult>? startConnectedServerPingMonitoring({
    Duration interval = const Duration(seconds: 5),
  }) {
    if (_activeConfig == null) {
      // No active config for ping monitoring
      return null;
    }

    try {
      return NativePingService.startContinuousPing(
        host: _activeConfig!.address,
        port: _activeConfig!.port,
        interval: interval,
      );
    } catch (e) {
      // Error starting connected server ping monitoring
      return null;
    }
  }

  /// Get network type information
  Future<String> getNetworkType() async {
    try {
      return await NativePingService.getNetworkType();
    } catch (e) {
      // Error getting network type
      return 'Unknown';
    }
  }

  /// Test connectivity using native ping service
  Future<Map<String, PingResult>> testConnectivity() async {
    try {
      return await NativePingService.testConnectivity();
    } catch (e) {
      // Error testing connectivity
      return {};
    }
  }

  /// Get enhanced server delay with detailed ping information
  Future<PingResult> getServerPingDetails(V2RayConfig config) async {
    try {
      return await NativePingService.pingHost(
        host: config.address,
        port: config.port,
        timeoutMs: 8000,
        useIcmp: true,
        useTcp: true,
        useCache: false,
      );
    } catch (e) {
      // Error getting server ping details
      return PingResult.error('Failed to ping server: $e');
    }
  }

  /// Get fastest server from a list of configs using V2Ray ping
  Future<V2RayConfig?> getFastestServer(List<V2RayConfig> configs) async {
    if (configs.isEmpty) return null;

    try {
      V2RayConfig? fastestConfig;
      int? lowestLatency;

      // Ping each config sequentially using V2Ray's built-in method
      for (final config in configs) {
        final latency = await getServerDelay(config);
        if (latency != null &&
            latency > 0 &&
            (lowestLatency == null || latency < lowestLatency)) {
          lowestLatency = latency;
          fastestConfig = config;
        }
      }

      return fastestConfig;
    } catch (e) {
      // Error getting fastest server
      return null;
    }
  }

  Future<V2RayConfig?> parseSubscriptionConfig(String configText) async {
    try {
      // Try to parse as a V2Ray URL
      final parser = FlutterV2ray.parseFromURL(configText);

      // Determine the protocol type from the URL prefix
      String configType = '';
      if (configText.startsWith('vmess://')) {
        configType = 'vmess';
      } else if (configText.startsWith('vless://')) {
        configType = 'vless';
      } else if (configText.startsWith('ss://')) {
        configType = 'shadowsocks';
      } else {
        throw Exception('Unsupported protocol');
      }

      // Use the parsed address and port from the V2RayURL parser
      String address = parser.address;
      int port = parser.port;

      // Create a new V2RayConfig object with a generated ID
      return V2RayConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        remark: parser.remark,
        address: address,
        port: port,
        configType: configType,
        fullConfig: configText,
        isConnected: false,
      );
    } catch (e) {
      // Error parsing config
      return null;
    }
  }

  @override
  void dispose() {
    // IMPROVED: Ensure all timers are properly cancelled
    _stopStatusMonitoring();
    _stopUsageMonitoring();
    _statusCheckTimer?.cancel();
    _usageStatsTimer?.cancel();
    _statusCheckTimer = null;
    _usageStatsTimer = null;
    // Cleanup native ping service
    NativePingService.cleanup();
    super.dispose();
  }

  // Usage statistics methods
  void _startUsageMonitoring() {
    // Stop existing timer if any
    _usageStatsTimer?.cancel();

    // Start periodic usage monitoring every second
    _usageStatsTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_activeConfig != null) {
        // Increment connected time
        _connectedSeconds++;

        try {
          // IMPORTANT: Only use real V2Ray status data (no fake data)
          if (_currentStatus != null) {
            // Get real-time traffic data from V2Ray status
            final status = _currentStatus!;

            // Update cumulative statistics with REAL data only
            // Note: V2Ray status provides cumulative data, so we store the latest values
            _uploadBytes = status.upload;
            _downloadBytes = status.download;
            
            // Notify UI to update with real data
            notifyListeners();
          }
          // If no V2Ray status available, we keep the previous values
          // No fake/simulated data generation

          // Save statistics every minute to avoid excessive writes
          if (_connectedSeconds % 60 == 0) {
            await _saveUsageStats();
          }
        } catch (e) {
          // Error updating usage statistics
          // Keep previous values, don't generate fake data
        }
      }
    });
  }

  void _stopUsageMonitoring() {
    _usageStatsTimer?.cancel();
    _usageStatsTimer = null;
  }

  // Save usage stats and connection time to storage
  Future<void> _saveUsageStats() async {
    final prefs = await SharedPreferences.getInstance();

    // Save current usage statistics
    await prefs.setInt('upload_bytes', _uploadBytes);
    await prefs.setInt('download_bytes', _downloadBytes);
    await prefs.setInt('connected_seconds', _connectedSeconds);

    // Save last connection time if connected
    if (_lastConnectionTime != null) {
      await prefs.setString(
        'last_connection_time',
        _lastConnectionTime!.toIso8601String(),
      );
    }
  }

  Future<void> _loadUsageStats() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved usage statistics
    _uploadBytes = prefs.getInt('upload_bytes') ?? 0;
    _downloadBytes = prefs.getInt('download_bytes') ?? 0;
    _connectedSeconds = prefs.getInt('connected_seconds') ?? 0;

    // Load last connection time (but don't calculate elapsed time here)
    // This will be handled by _restoreConnectionTime when needed
    final lastConnectionTimeStr = prefs.getString('last_connection_time');
    if (lastConnectionTimeStr != null) {
      try {
        _lastConnectionTime = DateTime.parse(lastConnectionTimeStr);
      } catch (e) {
        // Error parsing last connection time
        _lastConnectionTime = null;
      }
    } else {
      _lastConnectionTime = null;
    }

    // Loaded usage stats
  }

  Future<void> resetUsageStats() async {
    _uploadBytes = 0;
    _downloadBytes = 0;
    _connectedSeconds = 0;

    // Reset last connection time to now if connected
    if (_activeConfig != null) {
      _lastConnectionTime = DateTime.now();
    } else {
      _lastConnectionTime = null;
    }

    // Save the reset values
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('upload_bytes', 0);
    await prefs.setInt('download_bytes', 0);
    await prefs.setInt('connected_seconds', 0);

    if (_lastConnectionTime != null) {
      await prefs.setString(
        'last_connection_time',
        _lastConnectionTime!.toIso8601String(),
      );
    } else {
      await prefs.remove('last_connection_time');
    }
  }

  // Getters for usage statistics
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  int get connectedSeconds => _connectedSeconds;

  // Get current speeds from V2Ray status (for internal use)
  int get currentUploadSpeed => _currentStatus?.uploadSpeed ?? 0;
  int get currentDownloadSpeed => _currentStatus?.downloadSpeed ?? 0;
  
  // Get current ping for the active server
  Future<int?> getCurrentPing() async {
    if (_activeConfig == null) return null;
    
    try {
      // Try to get ping from V2Ray
      final delay = await _flutterV2ray.getServerDelay(config: _activeConfig!.fullConfig);
      return delay;
    } catch (e) {
      // If V2Ray ping fails, try regular TCP ping
      try {
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          _activeConfig!.address,
          _activeConfig!.port,
          timeout: const Duration(seconds: 3),
        );
        stopwatch.stop();
        await socket.close();
        return stopwatch.elapsedMilliseconds;
      } catch (e) {
        return null;
      }
    }
  }

  // Format usage statistics for display
  String getFormattedUpload() {
    return _formatBytes(_uploadBytes);
  }

  String getFormattedDownload() {
    return _formatBytes(_downloadBytes);
  }

  String getFormattedTotalTraffic() {
    return _formatBytes(_uploadBytes + _downloadBytes);
  }

  String getFormattedConnectedTime() {
    final hours = _connectedSeconds ~/ 3600;
    final minutes = (_connectedSeconds % 3600) ~/ 60;
    final seconds = _connectedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
