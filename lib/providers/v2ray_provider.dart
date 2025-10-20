import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/v2ray_config.dart';
import '../models/subscription.dart';
import '../services/v2ray_service.dart';
import '../services/server_service.dart';
import '../services/analytics_service.dart';

class V2RayProvider with ChangeNotifier, WidgetsBindingObserver {
  final V2RayService _v2rayService = V2RayService();
  final ServerService _serverService = ServerService();
  final AnalyticsService _analyticsService = AnalyticsService();
  bool statusPingOnly = false;
  List<V2RayConfig> _configs = [];
  List<Subscription> _subscriptions = [];
  V2RayConfig? _selectedConfig;
  bool _isConnecting = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLoadingServers = false;
  bool _isProxyMode = false;
  Timer? _connectionMonitorTimer;
  bool _isAppInForeground = true; // Track if app is active

  List<V2RayConfig> get configs => _configs;
  List<Subscription> get subscriptions => _subscriptions;
  V2RayConfig? get selectedConfig => _selectedConfig;
  V2RayConfig? get activeConfig => _v2rayService.activeConfig;
  bool get isConnecting => _isConnecting;
  bool get isLoading => _isLoading;
  bool get isLoadingServers => _isLoadingServers;
  String get errorMessage => _errorMessage;
  V2RayService get v2rayService => _v2rayService;
  bool get isProxyMode => _isProxyMode;

  // Expose V2Ray status for real-time traffic monitoring
  V2RayStatus? get currentStatus => _v2rayService.currentStatus;

  V2RayProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Listen to V2RayService changes to update UI automatically
    _v2rayService.addListener(_onV2RayServiceChanged);
    _initialize();
    // Timer will start when app becomes active (in didChangeAppLifecycleState)
    // Start it now for initial load
    _startConnectionMonitoring();
  }
  
  void _onV2RayServiceChanged() {
    // When V2RayService state changes, notify our listeners
    notifyListeners();
  }

  Future<void> _initialize() async {
    _setLoading(true);
    try {
      // OPTIMISTIC UI: Load saved config immediately and show UI first
      // Then verify in background
      await _loadSavedStateAndShowUI();
      
      // Initialize service in background
      await _v2rayService.initialize();

      // Set up callback for notification disconnects
      _v2rayService.setDisconnectedCallback(() {
        _handleNotificationDisconnect();
      });

      // Configs already loaded in _loadSavedStateAndShowUI, skip duplicate load

      // Load subscriptions
      await loadSubscriptions();

      // Update all subscriptions on app start (run in background, non-blocking)
      updateAllSubscriptions().catchError((e) {
        // Ignore errors in background update
      });

      // Load saved selected server
      await _loadSelectedServer();

      // IMPROVED: Check actual VPN status (optimistically, then verify)
      // Get immediate status from service (already restored in initialize)
      bool isActuallyConnected = false;
      V2RayConfig? activeConfig = _v2rayService.activeConfig;
      
      // Quick check without retry for immediate feedback
      try {
        isActuallyConnected = await _v2rayService.isActuallyConnected()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        // If quick check fails, assume config is valid if it exists
        isActuallyConnected = activeConfig != null;
      }
      
      // IMPROVED: Only mark as connected if actually connected
      if (activeConfig != null && isActuallyConnected) {
        // VPN is truly connected, update configs
        bool configFound = false;

        for (var config in _configs) {
          if (config.fullConfig == activeConfig.fullConfig) {
            config.isConnected = true;
            _selectedConfig = config;
            configFound = true;
            // Found exact matching config
            break;
          }
        }

        // If we couldn't find the exact active config in our list,
        // try to find a matching one by address and port
        if (!configFound) {
          for (var config in _configs) {
            if (config.address == activeConfig.address &&
                config.port == activeConfig.port) {
              config.isConnected = true;
              _selectedConfig = config;
              configFound = true;
              // Found matching config by address/port
              break;
            }
          }
        }

        if (!configFound) {
          // No matching config found in list for active VPN connection
          // The active config is not in our current list
          // This could happen if subscriptions were updated while VPN was connected
          // Add the active config to our list temporarily
          _configs.add(activeConfig);
          activeConfig.isConnected = true;
          _selectedConfig = activeConfig;
        }
      } else {
        // VPN not connected or config not found, ensure all are marked disconnected
        for (var config in _configs) {
          config.isConnected = false;
        }
      }
      
      // Start background verification to double-check status
      _verifyConnectionStatusInBackground();
      
      if (_selectedConfig == null && _configs.isNotEmpty) {
        // If no active connection and no saved selection, select first server
        _selectedConfig = _configs.first;
        await _saveSelectedServer();
      }

      // Sort configs with connected one first
      _configs.sort((a, b) {
        if (a.isConnected && !b.isConnected) return -1;
        if (!a.isConnected && b.isConnected) return 1;
        return 0;
      });
    } catch (e) {
      // Failed to initialize V2Ray
    } finally {
      _setLoading(false);
    }
  }
  
  // Load saved selected server
  Future<void> _loadSelectedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedServerId = prefs.getString('selected_server_id');
      if (savedServerId != null && _configs.isNotEmpty) {
        final savedServer = _configs.firstWhere(
          (config) => config.id == savedServerId,
          orElse: () => _configs.first,
        );
        _selectedConfig = savedServer;
      }
    } catch (e) {
      // Error loading selected server
    }
  }
  
  // Save selected server
  Future<void> _saveSelectedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedConfig != null) {
        await prefs.setString('selected_server_id', _selectedConfig!.id);
      } else {
        await prefs.remove('selected_server_id');
      }
    } catch (e) {
      // Error saving selected server
    }
  }

  Future<void> loadConfigs() async {
    _setLoading(true);
    try {
      _configs = await _v2rayService.loadConfigs();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load configurations: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchServers({required String customUrl}) async {
    _isLoadingServers = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Fetch servers from service using the provided custom URL
      final servers = await _serverService.fetchServers(customUrl: customUrl);

      if (servers.isNotEmpty) {
        // Get all subscription config IDs to preserve them
        final subscriptionConfigIds = <String>{};
        for (var subscription in _subscriptions) {
          subscriptionConfigIds.addAll(subscription.configIds);
        }

        // Clear ping cache for default servers (non-subscription servers)
        for (var config in _configs) {
          if (!subscriptionConfigIds.contains(config.id)) {
            _v2rayService.clearPingCache(configId: config.id);
          }
        }

        // Keep existing subscription configs
        final subscriptionConfigs = _configs
            .where((c) => subscriptionConfigIds.contains(c.id))
            .toList();

        // Add default servers to the configs list
        _configs = [...subscriptionConfigs, ...servers];

        // Save configs and update UI immediately to show servers
        await _v2rayService.saveConfigs(_configs);

        // Mark loading as complete
        _isLoadingServers = false;
        notifyListeners();

        // Server delay functionality removed as requested
      } else {
        // If no servers found online, try to load from local storage
        _configs = await _v2rayService.loadConfigs();
      }
    } catch (e) {
      _setError('Failed to fetch servers: $e');
      // Try to load from local storage as fallback
      _configs = await _v2rayService.loadConfigs();
      notifyListeners();
    } finally {
      _isLoadingServers = false;
      notifyListeners();
    }
  }

  Future<void> loadSubscriptions() async {
    _setLoading(true);
    try {
      _subscriptions = await _v2rayService.loadSubscriptions();

      // Create default subscription if no subscriptions exist
      if (_subscriptions.isEmpty) {
        final defaultSubscription = Subscription(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Default Subscription',
          url:
              'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub.txt',
          lastUpdated: DateTime.now(),
          configIds: [],
        );
        _subscriptions.add(defaultSubscription);
        await _v2rayService.saveSubscriptions(_subscriptions);
      }

      // Ensure configs are loaded and match subscription config IDs
      if (_configs.isEmpty) {
        _configs = await _v2rayService.loadConfigs();
      }

      // Verify that all subscription config IDs exist in the configs list
      // If not, it means the configs weren't properly saved or loaded
      for (var subscription in _subscriptions) {
        final configIds = subscription.configIds;
        final existingConfigIds = _configs.map((c) => c.id).toSet();

        // Check if any config IDs in the subscription are missing from the configs list
        final missingConfigIds = configIds
            .where((id) => !existingConfigIds.contains(id))
            .toList();

        if (missingConfigIds.isNotEmpty) {
          // Warning: Found missing configs for subscription
          // Update the subscription to remove missing config IDs
          final updatedConfigIds = configIds
              .where((id) => existingConfigIds.contains(id))
              .toList();
          final index = _subscriptions.indexWhere(
            (s) => s.id == subscription.id,
          );
          if (index != -1) {
            _subscriptions[index] = subscription.copyWith(
              configIds: updatedConfigIds,
            );
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load subscriptions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addConfig(V2RayConfig config) async {
    // Add config and display it immediately
    _configs.add(config);

    // Save the configuration immediately to display it
    await _v2rayService.saveConfigs(_configs);
    notifyListeners();
  }

  Future<void> removeConfig(V2RayConfig config) async {
    try {
      _configs.removeWhere((c) => c.id == config.id);

      // Also remove from subscriptions if the config is part of any subscription
      for (int i = 0; i < _subscriptions.length; i++) {
        final subscription = _subscriptions[i];
        if (subscription.configIds.contains(config.id)) {
          final updatedConfigIds = List<String>.from(subscription.configIds)
            ..remove(config.id);
          _subscriptions[i] = subscription.copyWith(
            configIds: updatedConfigIds,
          );
        }
      }

      // If the deleted config was selected, clear the selection
      if (_selectedConfig?.id == config.id) {
        _selectedConfig = null;
      }

      await _v2rayService.saveConfigs(_configs);
      await _v2rayService.saveSubscriptions(_subscriptions);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete configuration: $e');
    }
  }

  Future<V2RayConfig?> importConfigFromText(String configText) async {
    try {
      // Try to parse the configuration
      final config = await _v2rayService.parseSubscriptionConfig(configText);
      if (config == null) {
        throw Exception('Invalid configuration format');
      }

      // Add the config to the list
      await addConfig(config);

      return config;
    } catch (e) {
      _setError('Failed to import configuration: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    // Remove listener from V2RayService
    _v2rayService.removeListener(_onV2RayServiceChanged);
    // Dispose the service to stop monitoring
    _v2rayService.dispose();
    // Disconnect if connected when disposing
    if (_v2rayService.activeConfig != null) {
      _v2rayService.disconnect();
    }
    super.dispose();
  }

  Future<void> addSubscription(String name, String url) async {
    _setLoading(true);
    _errorMessage = '';
    try {
      final configs = await _v2rayService.parseSubscriptionUrl(url);
      if (configs.isEmpty) {
        _setError('No valid configurations found in subscription');
        return;
      }

      // Add configs and display them immediately
      _configs.addAll(configs);

      final newConfigIds = configs.map((c) => c.id).toList();

      // Create subscription
      final subscription = Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        lastUpdated: DateTime.now(),
        configIds: newConfigIds,
      );

      _subscriptions.add(subscription);

      // Save both configs and subscription
      await _v2rayService.saveConfigs(_configs);
      await _v2rayService.saveSubscriptions(_subscriptions);

      // Update UI after everything is saved
      notifyListeners();
    } catch (e) {
      String errorMsg = 'Failed to add subscription';

      // Provide more specific error messages
      if (e.toString().contains('Network error') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        errorMsg = 'Network error: Check your internet connection';
      } else if (e.toString().contains('Invalid URL')) {
        errorMsg = 'Invalid subscription URL format';
      } else if (e.toString().contains('No valid servers')) {
        errorMsg = 'No valid servers found in subscription';
      } else if (e.toString().contains('HTTP')) {
        errorMsg = 'Server error: ${e.toString()}';
      } else {
        errorMsg = 'Failed to add subscription: ${e.toString()}';
      }

      _setError(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    _setLoading(true);
    _isLoadingServers = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final configs = await _v2rayService.parseSubscriptionUrl(
        subscription.url,
      );
      if (configs.isEmpty) {
        _setError('No valid configurations found in subscription');
        _isLoadingServers = false;
        notifyListeners();
        return;
      }

      // Clear ping cache for old configs before removing them
      for (var configId in subscription.configIds) {
        _v2rayService.clearPingCache(configId: configId);
      }

      // Remove old configs
      _configs.removeWhere((c) => subscription.configIds.contains(c.id));

      // Add new configs and display them immediately
      _configs.addAll(configs);

      final newConfigIds = configs.map((c) => c.id).toList();

      // Update subscription
      final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _subscriptions[index] = subscription.copyWith(
          lastUpdated: DateTime.now(),
          configIds: newConfigIds,
        );

        // Save both configs and subscriptions to ensure persistence
        await _v2rayService.saveConfigs(_configs);
        await _v2rayService.saveSubscriptions(_subscriptions);
      }

      // Mark loading as complete
      _isLoadingServers = false;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      String errorMsg = 'Failed to update subscription';

      // Provide more specific error messages
      if (e.toString().contains('Network error') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        errorMsg = 'Network error: Check your internet connection';
      } else if (e.toString().contains('Invalid URL')) {
        errorMsg = 'Invalid subscription URL format';
      } else if (e.toString().contains('No valid servers')) {
        errorMsg = 'No valid servers found in subscription';
      } else if (e.toString().contains('HTTP')) {
        errorMsg = 'Server error: ${e.toString()}';
      } else {
        errorMsg = 'Failed to update subscription: ${e.toString()}';
      }

      _setError(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  // Update subscription info without refreshing servers
  Future<void> updateSubscriptionInfo(Subscription subscription) async {
    _setLoading(true);
    _errorMessage = '';

    try {
      // Find and update the subscription
      final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _subscriptions[index] = subscription;
        await _v2rayService.saveSubscriptions(_subscriptions);
        notifyListeners();
      } else {
        _setError('Subscription not found');
      }
    } catch (e) {
      String errorMsg = 'Failed to update subscription info';

      // Provide more specific error messages
      if (e.toString().contains('Network error') ||
          e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        errorMsg = 'Network error: Check your internet connection';
      } else if (e.toString().contains('Invalid URL')) {
        errorMsg = 'Invalid subscription URL format';
      } else if (e.toString().contains('Permission')) {
        errorMsg = 'Permission error: Unable to save subscription';
      } else {
        errorMsg = 'Failed to update subscription info: ${e.toString()}';
      }

      _setError(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  // Update all subscriptions
  Future<void> updateAllSubscriptions() async {
    _setLoading(true);
    _errorMessage = '';
    _isLoadingServers = true;
    notifyListeners();

    // Clear all ping cache before updating subscriptions
    _v2rayService.clearPingCache();

    try {
      // Make a copy to avoid modification during iteration
      final subscriptionsCopy = List<Subscription>.from(_subscriptions);
      bool anyUpdated = false;
      List<String> failedSubscriptions = [];

      for (final subscription in subscriptionsCopy) {
        try {
          // Skip empty or invalid subscriptions
          if (subscription.url.isEmpty) continue;

          final configs = await _v2rayService.parseSubscriptionUrl(
            subscription.url,
          );

          // Remove old configs for this subscription
          _configs.removeWhere((c) => subscription.configIds.contains(c.id));

          // Add new configs
          _configs.addAll(configs);

          final newConfigIds = configs.map((c) => c.id).toList();

          // Update subscription
          final index = _subscriptions.indexWhere(
            (s) => s.id == subscription.id,
          );
          if (index != -1) {
            _subscriptions[index] = subscription.copyWith(
              lastUpdated: DateTime.now(),
              configIds: newConfigIds,
            );
            anyUpdated = true;
          }
        } catch (e) {
          // Record failed subscription
          failedSubscriptions.add(subscription.name);
          // Error updating subscription
        }
      }

      // Save all changes at once to reduce disk operations
      if (anyUpdated) {
        await _v2rayService.saveConfigs(_configs);
        await _v2rayService.saveSubscriptions(_subscriptions);
      }

      // Set error message if any subscriptions failed
      if (failedSubscriptions.isNotEmpty) {
        if (failedSubscriptions.length == _subscriptions.length) {
          // All subscriptions failed - likely a network issue
          _setError(
            'Failed to update subscriptions: Network error or invalid URLs',
          );
        } else {
          // Some subscriptions failed
          _setError('Failed to update: ${failedSubscriptions.join(', ')}');
        }
      }

      _isLoadingServers = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update all subscriptions: $e');
    } finally {
      _setLoading(false);
      _isLoadingServers = false;
    }
  }

  Future<void> removeSubscription(Subscription subscription) async {
    // Remove configs associated with this subscription
    _configs.removeWhere((c) => subscription.configIds.contains(c.id));

    // Remove subscription
    _subscriptions.removeWhere((s) => s.id == subscription.id);

    await _v2rayService.saveConfigs(_configs);
    await _v2rayService.saveSubscriptions(_subscriptions);
    notifyListeners();
  }

  Future<void> connectToServer(V2RayConfig config, bool _isProxyMode) async {
    _isConnecting = true;
    _errorMessage = '';
    notifyListeners();

    // Maximum number of connection attempts
    const int maxAttempts = 3;
    // Delay between attempts in seconds
    const int retryDelaySeconds = 1;

    try {
      // Disconnect from current server if connected
      if (_v2rayService.activeConfig != null) {
        try {
          await _v2rayService.disconnect();
        } catch (e) {
          // Error disconnecting from current server
          // Continue with connection attempt even if disconnect failed
        }
      }

      // Try to connect with automatic retry
      bool success = false;
      String lastError = '';

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          // Connection attempt

          // Connect to server with timeout
          success = await _v2rayService
              .connect(config, _isProxyMode)
              .timeout(
                const Duration(seconds: 30), // Timeout for connection
                onTimeout: () {
                  // Connection timeout
                  return false;
                },
              );

          if (success) {
            // Connection successful
            break;
          } else {
            // Connection failed but no exception was thrown
            lastError =
                'Failed to connect to ${config.remark} on attempt $attempt';
            // Failed to connect

            // If this is not the last attempt, wait before retrying
            if (attempt < maxAttempts) {
              await Future.delayed(Duration(seconds: retryDelaySeconds));
            }
          }
        } catch (e) {
          // Check if this is a timeout-related error
          if (e.toString().contains('timeout')) {
            lastError = 'Connection timeout on attempt $attempt: $e';
            // Connection timeout
          } else {
            lastError = 'Error on connection attempt $attempt: $e';
            // Error on connection attempt
          }

          // If this is not the last attempt, wait before retrying
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: retryDelaySeconds));
          }
        }
      }

      if (success) {
        try {
          // Wait for connection to stabilize
          await Future.delayed(
            const Duration(seconds: 2),
          ); // Reduced from 3 to 2 seconds

          // Update config status safely
          for (int i = 0; i < _configs.length; i++) {
            if (_configs[i].id == config.id) {
              _configs[i].isConnected = true;
            } else {
              _configs[i].isConnected = false;
            }
          }
          _selectedConfig = config;

          // Persist the changes with error handling
          try {
            await _v2rayService.saveConfigs(_configs);
          } catch (e) {
            // Error saving configs after connection
            // Don't fail the connection for this
          }

          // Reset usage statistics when connecting to a new server
          try {
            await _v2rayService.resetUsageStats();
          } catch (e) {
            // Error resetting usage stats
            // Don't fail the connection for this
          }

          // Log analytics event for successful connection
          try {
            await _analyticsService.logVpnConnect(
              serverName: config.remark,
              country: config.address,
              protocol: config.configType,
            );
          } catch (e) {
            // Analytics logging failed, ignore
          }
          
          // Verify connection status after a short delay (only if app is in foreground)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isAppInForeground) checkConnectionStatus();
          });
          
          // Successfully connected
        } catch (e) {
          // Error in post-connection setup
          // Connection succeeded but post-setup failed
          _setError('Connected but failed to update settings: $e');
        }
      } else {
        _setError(
          'Failed to connect to ${config.remark} after $maxAttempts attempts: $lastError',
        );
      }
    } catch (e) {
      // Unexpected error in connection process
      _setError('Unexpected error connecting to ${config.remark}: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _isConnecting = true;
    notifyListeners();

    try {
      // Log analytics event for disconnection
      final activeConfig = _v2rayService.activeConfig;
      if (activeConfig != null) {
        try {
          await _analyticsService.logVpnDisconnect(
            serverName: activeConfig.remark,
            durationSeconds: _v2rayService.connectedSeconds,
          );
        } catch (e) {
          // Analytics logging failed, ignore
        }
      }
      
      await _v2rayService.disconnect();
      statusPingOnly = false;
      // Update config status
      for (int i = 0; i < _configs.length; i++) {
        _configs[i].isConnected = false;
      }

      // Keep the selected config when disconnecting
      // Don't set _selectedConfig to null

      // Persist the changes
      await _v2rayService.saveConfigs(_configs);
      
      // Verify disconnection status after a short delay (only if app is in foreground)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isAppInForeground) checkConnectionStatus();
      });
    } catch (e) {
      _setError('Error disconnecting: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // Removed testServerDelay method as requested

  // Removed pingServer and pingAllServers methods as requested

  Future<void> selectConfig(V2RayConfig config) async {
    _selectedConfig = config;
    // Save the selected config for persistence
    await _v2rayService.saveSelectedConfig(config);
    // Also save to SharedPreferences for persistence across app restarts
    await _saveSelectedServer();
    notifyListeners();
  }

  // تغییر وضعیت بین حالت پروکسی و تونل
  void toggleProxyMode(bool isProxy) {
    _isProxyMode = isProxy;
    // اینجا می‌توانیم منطق اضافی برای تغییر حالت اضافه کنیم
    // مثلاً ارسال دستور به سرویس برای تغییر حالت
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _isLoadingServers = loading; // Update server loading state as well
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void _handleNotificationDisconnect() {
    // Update config status when disconnected from notification
    for (int i = 0; i < _configs.length; i++) {
      _configs[i].isConnected = false;
    }

    // Keep the selected config when disconnecting
    // Don't set _selectedConfig to null

    // Notify listeners immediately to update UI in real-time
    notifyListeners();

    // Persist the changes and check status multiple times
    _v2rayService
        .saveConfigs(_configs)
        .then((_) {
          notifyListeners();
          // Immediate check
          checkConnectionStatus();
          // Check again after 300ms (only if app is in foreground)
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isAppInForeground) checkConnectionStatus();
          });
          // Final check after 800ms (only if app is in foreground)
          Future.delayed(const Duration(milliseconds: 800), () {
            if (_isAppInForeground) checkConnectionStatus();
          });
        })
        .catchError((e) {
          // Error saving configs after notification disconnect
          notifyListeners();
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App lifecycle state changed

    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // Mark app as in foreground
      _isAppInForeground = true;
      
      // App is now active - start monitoring to save battery
      _startConnectionMonitoring();
      
      // OPTIMIZED: When app is resumed, check immediately then verify in background
      // This gives instant feedback while ensuring accuracy
      
      // Triple immediate checks (no delay)
      checkConnectionStatus();
      fetchNotificationStatus();
      
      // Very quick follow-up (100ms)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isAppInForeground) checkConnectionStatus();
      });
      
      // Quick follow-up checks for reliability
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isAppInForeground) fetchNotificationStatus();
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isAppInForeground) checkConnectionStatus();
      });
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isAppInForeground) checkConnectionStatus();
      });
      
      // Background verification for long background periods
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isAppInForeground) fetchNotificationStatus();
      });
      
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_isAppInForeground) checkConnectionStatus();
      });
    } else if (state == AppLifecycleState.paused) {
      // Mark app as in background
      _isAppInForeground = false;
      
      // App is paused - stop monitoring to save battery
      // VPN service continues running in background
      _stopConnectionMonitoring();
    } else if (state == AppLifecycleState.inactive) {
      // App is inactive (e.g., notification pulled down), check status
      checkConnectionStatus();
    }
  }

  // Method to fetch connection status from the notification
  Future<void> fetchNotificationStatus() async {
    try {
      // Get the actual connection status from the service
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;

      // Fetching notification status

      // Update all configs based on the actual status
      bool statusChanged = false;

      if (activeConfig != null && isActuallyConnected) {
        // VPN is connected, update the matching config
        bool foundMatch = false;
        for (int i = 0; i < _configs.length; i++) {
          bool shouldBeConnected = false;

          // Find the matching config by comparing the server details
          shouldBeConnected =
              _configs[i].fullConfig == activeConfig.fullConfig ||
              (_configs[i].address == activeConfig.address &&
                  _configs[i].port == activeConfig.port);

          if (_configs[i].isConnected != shouldBeConnected) {
            _configs[i].isConnected = shouldBeConnected;
            statusChanged = true;

            if (shouldBeConnected) {
              _selectedConfig = _configs[i];
              foundMatch = true;
              // Updated config to connected
            }
          } else if (shouldBeConnected) {
            // Already connected to this config
            _selectedConfig = _configs[i];
            foundMatch = true;
          }
        }
        
        // If no matching config found, add the active config temporarily
        if (!foundMatch && activeConfig != null) {
          // Check if this config already exists in list
          bool exists = _configs.any((c) => c.id == activeConfig.id);
          if (!exists) {
            activeConfig.isConnected = true;
            _configs.insert(0, activeConfig);
            _selectedConfig = activeConfig;
            statusChanged = true;
          }
        }
      } else {
        // VPN is not connected, clear all connected states
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
            // Updated config to disconnected
          }
        }
        if (statusChanged) {
          // Keep the selected config even when disconnected
          // _selectedConfig = null;
        }
      }

      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
        notifyListeners();
        // Connection status updated from notification check
      } else {
        // Even if status didn't change, notify to ensure UI is updated
        notifyListeners();
      }
    } catch (e) {
      // Error fetching notification status
      // Don't change connection state on errors
    }
  }

  // OPTIMISTIC UI: Load saved state immediately for instant UI display
  Future<void> _loadSavedStateAndShowUI() async {
    try {
      // Load configs from storage immediately (very fast, no network)
      final savedConfigs = await _v2rayService.loadConfigs();
      if (savedConfigs.isNotEmpty) {
        _configs = savedConfigs;
        
        // Check if any config is marked as connected
        final connectedConfig = _configs.firstWhere(
          (c) => c.isConnected,
          orElse: () => _configs.first,
        );
        
        if (connectedConfig.isConnected) {
          _selectedConfig = connectedConfig;
        }
        
        // Notify UI immediately with saved state
        notifyListeners();
      }
    } catch (e) {
      // Error loading saved state, continue with empty list
    }
  }
  
  // Background verification of connection status (non-blocking)
  void _verifyConnectionStatusInBackground() {
    // Run verification in background after a short delay
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!_isAppInForeground) return; // Skip if app in background
      try {
        await checkConnectionStatus();
      } catch (e) {
        // Ignore errors in background verification
      }
    });
    
    // Double-check after 2 seconds
    Future.delayed(const Duration(seconds: 2), () async {
      if (!_isAppInForeground) return; // Skip if app in background
      try {
        await checkConnectionStatus();
      } catch (e) {
        // Ignore errors in background verification
      }
    });
  }

  // Method to manually check connection status
  Future<void> checkConnectionStatus() async {
    try {
      // Always check the actual VPN connection status
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;
      
      bool statusChanged = false;
      
      if (isActuallyConnected && activeConfig != null) {
        // VPN is actually connected - ensure UI shows this
        bool foundMatch = false;
        
        for (int i = 0; i < _configs.length; i++) {
          bool shouldBeConnected = _configs[i].fullConfig == activeConfig.fullConfig ||
              (_configs[i].address == activeConfig.address &&
               _configs[i].port == activeConfig.port);
          
          if (_configs[i].isConnected != shouldBeConnected) {
            _configs[i].isConnected = shouldBeConnected;
            statusChanged = true;
            if (shouldBeConnected) {
              _selectedConfig = _configs[i];
              foundMatch = true;
            }
          } else if (shouldBeConnected) {
            foundMatch = true;
            _selectedConfig = _configs[i];
          }
        }
        
        // If no match found in existing configs, add the active config temporarily
        if (!foundMatch) {
          bool exists = _configs.any((c) => c.id == activeConfig.id);
          if (!exists) {
            activeConfig.isConnected = true;
            _configs.insert(0, activeConfig);
            _selectedConfig = activeConfig;
            statusChanged = true;
          }
        }
      } else {
        // VPN is NOT connected - ensure all configs show disconnected
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
          }
        }
      }
      
      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
        notifyListeners();
      } else {
        // Even if no status changed, notify to refresh UI
        notifyListeners();
      }
    } catch (e) {
      // Error checking connection status
      // Don't change connection state on errors, but still notify UI
      notifyListeners();
    }
  }
  
  // Start periodic connection monitoring to keep UI in sync
  void _startConnectionMonitoring() {
    // Check connection status every 1 second for faster detection
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        await checkConnectionStatus();
      },
    );
  }
  
  // Stop periodic connection monitoring to save battery
  void _stopConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }
}
