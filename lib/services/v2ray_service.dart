import 'dart:convert';
import 'dart:async';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiksarvpn/models/v2ray_config.dart';
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

}

class V2RayService extends ChangeNotifier {
  Function()? _onDisconnected;
  bool _isInitialized = false;
  V2RayConfig? _activeConfig;
  Timer? _statusCheckTimer;
  DateTime? _lastConnectionTime;

  /// Set only in-memory (never restored from prefs) when connect() succeeds.
  /// Used to enforce a brief grace period inside _handleStatusChange to ignore
  /// spurious "disconnected" callbacks that arrive right after connecting.
  DateTime? _lastSuccessfulConnectTime;


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
                'packageName': app['packageName']?.toString() ?? '',
                'name': app['name']?.toString() ?? '',
                'isSystemApp': app['isSystemApp'] == true,
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
      _pingInProgress.remove(configId);
    } else {
      _pingCache.clear();
      _pingInProgress.clear();
    }
    // Also clear native ping service cache
    NativePingService.clearCache();
  }

  // Singleton pattern
  static final V2RayService _instance = V2RayService._internal();
  factory V2RayService() => _instance;

  late final V2ray _flutterV2ray;

  // Current V2Ray status from the callback
  V2RayStatus? _currentStatus;
  V2RayStatus? get currentStatus => _currentStatus;

  V2RayService._internal() {
    _flutterV2ray = V2ray(
      onStatusChanged: (status) {
        _currentStatus = status;
        _handleStatusChange(status);
        notifyListeners();
      },
    );

    // Load saved usage statistics
    _loadUsageStats();
  }

  /// Get current VPN connection state from native
  /// Returns: "V2RAY_CONNECTED", "V2RAY_DISCONNECTED", "V2RAY_CONNECTING"
  Future<String> getConnectionState() async {
    try {
      return await _flutterV2ray.getConnectionState();
    } catch (e) {
      debugPrint('❌ Error getting connection state: $e');
      return 'V2RAY_DISCONNECTED';
    }
  }


  void _handleStatusChange(V2RayStatus status) {
    final String stateString = status.state.toLowerCase().trim();

    // Only treat EXPLICIT disconnect states as disconnection.
    // Empty state and "idle" are normal during traffic-stat updates while connected
    // and must NOT trigger a disconnect.
    final bool isExplicitDisconnect =
        stateString == 'disconnected' ||
        stateString == 'stopped' ||
        stateString == 'stop';

    if (isExplicitDisconnect && _activeConfig != null) {
      // Grace period: ignore spurious disconnect callbacks that arrive within
      // 120 seconds of THIS PROCESS's successful connect() call.
      // _lastSuccessfulConnectTime is in-memory only (not persisted), so on cold
      // start it is always null — legitimate disconnects are always processed.
      if (_lastSuccessfulConnectTime != null) {
        final msSinceConnect =
            DateTime.now().difference(_lastSuccessfulConnectTime!).inMilliseconds;
        if (msSinceConnect < 120000) {
          debugPrint(
              '⏭️ Ignoring disconnect event – within 120 s grace period '
              '(${msSinceConnect}ms since last in-process connect)');
          return;
        }
      }
      _activeConfig = null;
      _onDisconnected?.call();
      _clearActiveConfig();
    }
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _flutterV2ray.initialize(
        notificationIconResourceType: "drawable",
        notificationIconResourceName: "ic_notification",
      );
      _isInitialized = true;
    }
    // Config restoration is intentionally NOT done here.
    // The provider calls restoreActiveConfig() ONLY after confirming the VPN is
    // actually running via native status + delay check. This prevents the UI from
    // showing "connected" when the VPN was disconnected from the notification bar
    // while the app was killed.
  }

  Future<bool> connect(
    V2RayConfig config, {
    List<String>? dnsServers,
    List<String>? blockedApps,
    List<String>? allowedApps,
    List<String>? bypassSubnets,
    List<Map<String, dynamic>>? routingRules,
  }) async {
    try {
      await initialize();

      // Parse the configuration
      V2RayURL parser = V2ray.parseFromURL(config.fullConfig);

      // Inject DNS servers. If the user picked custom DNS we honour it;
      // otherwise we fall back to a fast, reliable public resolver pair
      // (Cloudflare + Google) so domain lookups — which gate how quickly
      // pages start loading — aren't left to a slow/ISP resolver.
      final effectiveDns = (dnsServers != null && dnsServers.isNotEmpty)
          ? dnsServers
          : const ['1.1.1.1', '8.8.8.8'];
      parser.dns = {
        'servers': effectiveDns,
        'queryStrategy': 'UseIPv4',
        'disableCache': false,
        'disableFallback': false,
        'disableFallbackIfMatch': false,
      };
      debugPrint('🌐 DNS set: ${effectiveDns.join(', ')}'
          '${(dnsServers == null || dnsServers.isEmpty) ? ' (default fallback)' : ''}');

      // Inject routing rules (geo-bypass). The default outbound is `proxy`
      // (the actual server), `direct` is the freedom outbound already in
      // outbound2, and rules with outboundTag=direct send matched traffic
      // out without going through the VPN server.
      if (routingRules != null && routingRules.isNotEmpty) {
        // Preserve any existing rules the URL parser added (rare), but our
        // bypass rules come FIRST so they take precedence over any wildcard.
        final existing = (parser.routing['rules'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const [];
        parser.routing = {
          ...parser.routing,
          'domainStrategy': 'IPIfNonMatch',
          'rules': [...routingRules, ...existing],
        };
        debugPrint('🧭 Routing rules injected: ${routingRules.length}');
      }

      // Request permission if needed (for VPN mode)
      bool hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission) {
        return false;
      }

      // Clean server name for notification (remove country code prefix like [DE])
      final cleanRemark = config.remark.replaceAll(RegExp(r'^\[[A-Z]{2}\]\s*'), '').trim();

      if (blockedApps != null && blockedApps.isNotEmpty) {
        debugPrint('🛡️ Per-App Proxy: excluding ${blockedApps.length} app(s) from VPN');
      }
      if (allowedApps != null && allowedApps.isNotEmpty) {
        debugPrint('🛡️ Per-App Proxy: routing only ${allowedApps.length} app(s) through VPN');
      }
      if (bypassSubnets != null && bypassSubnets.isNotEmpty) {
        debugPrint('🧭 Bypass subnets: ${bypassSubnets.length} entries');
      }

      // Start V2Ray in VPN mode - simplified without extra features
      await _flutterV2ray.startV2Ray(
        remark: cleanRemark,
        config: parser.getFullConfiguration(),
        proxyOnly: false, // Always use VPN mode (not proxy mode)
        blockedApps: blockedApps,
        allowedApps: allowedApps,
        bypassSubnets: bypassSubnets,
        notificationDisconnectButtonName: "DISCONNECT",
      );

      _activeConfig = config;
      _lastConnectionTime = DateTime.now();
      // Mark this as the most recent successful in-process connection so the
      // grace period in _handleStatusChange can suppress spurious disconnects.
      _lastSuccessfulConnectTime = DateTime.now();
      
      // Notify listeners immediately for UI update
      notifyListeners();

      // Save active config to persistent storage
      await _saveActiveConfig(config);

      // Start monitoring usage statistics
      _startUsageMonitoring();

      Future.delayed(const Duration(seconds: 2), () {
        if (activeConfig != null) {
          fetchIpInfo().catchError((_) => IpInfo(ip: '', country: '', city: '', countryCode: '', success: false));
        }
      });

      return true;
    } catch (e) {
      debugPrint('❌ Connect error: $e');
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

      // Clear active config and all related state
      _activeConfig = null;
      _lastConnectionTime = null;
      _lastSuccessfulConnectTime = null;
      // Clear the cached native status too. Otherwise isActuallyConnected()
      // (PRIORITY 2) still sees a stale "connected" state and resurrects the
      // connection we just dropped, before the native callback catches up.
      _currentStatus = null;

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
        // Wait for the ongoing ping to complete (max 6 seconds)
        int attempts = 0;
        while ((_pingInProgress[hostKey] == true || _pingInProgress[configId] == true) && attempts < 60) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
          
          // Check if result is now available in cache
          if (_pingCache.containsKey(hostKey)) {
            return _pingCache[hostKey]!.delay;
          } else if (_pingCache.containsKey(configId)) {
            return _pingCache[configId]!.delay;
          }
        }
        
        // If still in progress after waiting, return cached or null
        return _pingCache[hostKey]?.delay ?? _pingCache[configId]?.delay;
      }

      // Mark this host and config as having ping in progress
      _pingInProgress[hostKey] = true;
      _pingInProgress[configId] = true;

      try {
        // Use V2Ray's built-in ping method for better accuracy
        await initialize();

        // Safely parse the config
        V2RayURL parser;
        try {
          parser = V2ray.parseFromURL(config.fullConfig);
        } catch (parseError) {
          debugPrint('❌ Failed to parse config ${config.remark}: $parseError');
          _pingInProgress[hostKey] = false;
          _pingInProgress[configId] = false;
          return null;
        }

        final delay = await _flutterV2ray
            .getServerDelay(config: parser.getFullConfiguration())
            .timeout(
              const Duration(seconds: 7),
              onTimeout: () {
                debugPrint('⚠️ Ping timeout for ${config.remark}');
                return -1; // Return -1 instead of throwing
              },
            );

        // Cache the result by both host and config ID with timestamp
        if (delay >= 0 && delay < 10000) {
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

  // Direct ping using V2Ray core - Inspired by v2rayNG's RealPingWorkerService
  // This uses the native V2Ray core's measureOutboundDelay method for accurate results
  Future<int?> getServerDelayDirect(V2RayConfig config) async {
    try {
      await initialize();

      // Safely parse the config with retry mechanism
      V2RayURL? parser;
      int parseAttempts = 0;
      while (parser == null && parseAttempts < 2) {
        try {
          parser = V2ray.parseFromURL(config.fullConfig);
        } catch (parseError) {
          parseAttempts++;
          if (parseAttempts >= 2) {
            debugPrint('❌ Parse failed ${config.remark}: $parseError');
            return null;
          }
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      if (parser == null) return null;

      // Use V2Ray core's native ping method (similar to v2rayNG's measureOutboundDelay)
      // This is more accurate than TCP/ICMP ping as it tests the actual proxy connection
      final delay = await _flutterV2ray
          .getServerDelay(config: parser.getFullConfiguration())
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ Timeout ${config.remark}');
              return -1;
            },
          );

      // Valid delay range: 0-10000ms (same as v2rayNG)
      if (delay >= 0 && delay < 10000) {
        debugPrint('✓ ${config.remark}: ${delay}ms');
        return delay;
      } else {
        debugPrint('✗ ${config.remark}: invalid');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ${config.remark}: $e');
      return null;
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

  void setDisconnectedCallback(Function() callback) {
    _onDisconnected = callback;
    // Disable automatic monitoring to prevent false disconnects
    // _startStatusMonitoring();
  }

  /// Called by the provider after native VPN status + delay check confirm the
  /// VPN is actually running. Loads the saved config, restores the timer, and
  /// starts the usage-monitoring ticker.
  Future<void> restoreActiveConfig() async {
    try {
      final savedConfig = await _loadActiveConfig();
      if (savedConfig == null) {
        debugPrint('⚠️ restoreActiveConfig: no saved config found');
        return;
      }
      _activeConfig = savedConfig;
      await _restoreConnectionTime();
      _startUsageMonitoring();
      notifyListeners();
      debugPrint('✅ Active config restored after VPN confirmation: ${savedConfig.remark}');

      // Fetch IP info in background (non-blocking)
      Future.delayed(const Duration(seconds: 1), () {
        if (_activeConfig != null) {
          fetchIpInfo().catchError((_) =>
              IpInfo(ip: '', country: '', city: '', countryCode: '', success: false));
        }
      });
    } catch (e) {
      debugPrint('❌ restoreActiveConfig error: $e');
    }
  }

  /// Clears the active config and all related state when VPN is confirmed disconnected.
  /// Call this whenever we are certain the VPN is NOT running.
  void forceDisconnectedState() {
    if (_activeConfig == null && _lastSuccessfulConnectTime == null) return;
    debugPrint('🔄 forceDisconnectedState: clearing activeConfig');
    _stopUsageMonitoring();
    _activeConfig = null;
    _lastConnectionTime = null;
    _lastSuccessfulConnectTime = null;
    _currentStatus = null;
    _clearActiveConfig();
    notifyListeners();
  }

  void _stopStatusMonitoring() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  // Removed getConnectedServerDelay method as requested

  // Fetch IP information from ipleak.net API
  Future<IpInfo> fetchIpInfo() async {
    // Set loading state
    notifyListeners();

    const String apiUrl = 'https://ipleak.net/json/';
    int retryCount = 0;
    const int maxRetries = 5;

    try {
      while (retryCount < maxRetries) {
        try {
          // Fetching IP info attempt
          final response = await http.get(Uri.parse(apiUrl))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            final ipInfo = IpInfo.fromJson(data);

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
      notifyListeners();
      // Failed to fetch IP info after max retries
      return errorInfo;
    } catch (e) {
      // Handle any unexpected errors
      // Unexpected error fetching IP info
      final errorInfo = IpInfo.error('Error: $e');
      notifyListeners();
      return errorInfo;
    }
  }

  // Getter to check if connected to a server
  bool get isConnected => _activeConfig != null;

  // Getter to access the active config
  V2RayConfig? get activeConfig => _activeConfig;

  // Public method to force check connection status
  // Works WITHOUT internet - checks VPN service state directly
  // IMPROVED: Better detection - prioritize delay check over status string
  // Status string can be stale after app restart, but delay check is real-time
  Future<bool> isActuallyConnected() async {
    try {
      debugPrint('🔎 Checking if VPN is actually connected...');
      
      // PRIORITY 1: Try delay check FIRST - this is the most reliable method
      // It actually tests if V2Ray core is running and can reach the server
      try {
        final delay = await _flutterV2ray.getConnectedServerDelay()
            .timeout(const Duration(seconds: 5));
        
        if (delay >= 0 && delay < 10000) {
          debugPrint('✅ VPN connected (delay check: ${delay}ms)');
          
          // Restore active config if needed
          if (_activeConfig == null) {
            final savedConfig = await _loadActiveConfig();
            if (savedConfig != null) {
              _activeConfig = savedConfig;
              await _restoreConnectionTime();
              _startUsageMonitoring();
              notifyListeners();
              debugPrint('✅ Restored activeConfig from saved');
            }
          }
          return true;
        }
        debugPrint('🔎 Delay check returned invalid: $delay');
      } catch (e) {
        debugPrint('🔎 Delay check failed: $e');
        // Continue to other checks
      }
      
      // PRIORITY 2: Check V2Ray status string
      final currentState = _currentStatus?.state.toLowerCase() ?? '';
      debugPrint('🔎 Current V2Ray state: "$currentState"');
      
      // If V2Ray says connected, trust it (do NOT use .contains — "disconnecting" also contains "connect")
      if (currentState == 'connected' || currentState == 'running') {
        
        if (_activeConfig != null) {
          debugPrint('✅ VPN connected (V2Ray status + activeConfig)');
          return true;
        }
        
        // V2Ray says connected but no activeConfig - try to restore
        final savedConfig = await _loadActiveConfig();
        if (savedConfig != null) {
          _activeConfig = savedConfig;
          await _restoreConnectionTime();
          _startUsageMonitoring();
          notifyListeners();
          debugPrint('✅ VPN connected (restored from saved config)');
          return true;
        }
      }
      
      // PRIORITY 3: If status hasn't been received yet (cold start) and we have
      // a saved/active config, wait briefly for the native status callback to arrive.
      final hasConfig = _activeConfig != null || (await _loadActiveConfig()) != null;
      if (hasConfig && (_currentStatus == null || _currentStatus!.state.isEmpty)) {
        debugPrint('⏳ Status not yet received, waiting for native callback...');
        await Future.delayed(const Duration(milliseconds: 1200));
        final lateState = _currentStatus?.state.toLowerCase().trim() ?? '';
        debugPrint('📡 Late native state: "$lateState"');
        if (lateState == 'connected' || lateState == 'running') {
          if (_activeConfig == null) {
            final saved = await _loadActiveConfig();
            if (saved != null) {
              _activeConfig = saved;
              await _restoreConnectionTime();
              _startUsageMonitoring();
              notifyListeners();
            }
          }
          return _activeConfig != null;
        }
        if (lateState == 'disconnected' || lateState == 'stopped' || lateState == 'stop') {
          debugPrint('❌ Late native state confirms VPN disconnected');
          return false;
        }
      }

      // PRIORITY 4: activeConfig exists but all checks failed — ambiguous, don't force disconnect
      if (_activeConfig != null) {
        debugPrint('⚠️ activeConfig exists but all checks ambiguous - caller decides');
        return false;
      }
      
      // PRIORITY 5: Check saved config (VPN might be running but app was killed)
      final savedConfig = await _loadActiveConfig();
      if (savedConfig != null) {
        debugPrint('🔎 Found saved config but delay check failed');
        return false;
      }
      
      debugPrint('❌ VPN disconnected (no active config)');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking connection: $e');
      return false;
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
  
  /// Ensure monitoring is active for long-running connections
  /// This is called when app resumes to restart monitoring if needed
  void ensureMonitoringActive() {
    if (_activeConfig != null && _usageStatsTimer == null) {
      debugPrint('🔄 Restarting usage monitoring after app resume');
      _startUsageMonitoring();
    } else if (_activeConfig != null && _usageStatsTimer != null) {
      debugPrint('✅ Usage monitoring already active');
    } else {
      debugPrint('ℹ️ No active config, monitoring not needed');
    }
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

  // Format usage statistics for display
  String getFormattedUpload() {
    return _formatBytes(_uploadBytes);
  }

  String getFormattedDownload() {
    return _formatBytes(_downloadBytes);
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
