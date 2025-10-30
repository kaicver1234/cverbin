import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:flutter/services.dart';
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
  bool _isInitializing = true; // Track initialization state
  
  // Method channel for VPN control
  static const platform = MethodChannel('com.tiksarvpn.app/vpn_control');

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
  bool get isInitializing => _isInitializing;

  // Expose V2Ray status for real-time traffic monitoring
  V2RayStatus? get currentStatus => _v2rayService.currentStatus;

  V2RayProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Listen to V2RayService changes to update UI automatically
    _v2rayService.addListener(_onV2RayServiceChanged);
    _initialize();
    
    // Set up method channel handler for notification disconnect
    platform.setMethodCallHandler(_handleMethodCall);
  }
  
  // Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'disconnectFromNotification':
        await _handleNotificationDisconnect();
        break;
      default:
        throw MissingPluginException();
    }
  }
  
  void _onV2RayServiceChanged() {
    // When V2RayService state changes, notify our listeners
    notifyListeners();
  }

  Future<void> _initialize() async {
    _setLoading(true);
    _isInitializing = true;
    notifyListeners();
    
    try {
      // OPTIMISTIC UI: Load saved config immediately and show UI first
      await _loadSavedStateAndShowUI();
      
      // Initialize service
      await _v2rayService.initialize();

      // Set up callback for notification disconnects
      _v2rayService.setDisconnectedCallback(() {
        _handleNotificationDisconnect();
      });

      // Load configurations first
      await loadConfigs();

      // Load subscriptions
      await loadSubscriptions();
      
      // Load proxy mode setting from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _isProxyMode = prefs.getBool('proxy_mode_enabled') ?? false;

      // Update all subscriptions on app start (run in background)
      updateAllSubscriptions().catchError((e) {
        // Ignore errors in background update
      });

      // CRITICAL FIX: Enhanced synchronization with actual VPN service state
      await _enhancedSyncWithVpnServiceState();
      
      // Load saved selected server
      await _loadSelectedServer();
      
      if (_selectedConfig == null && _configs.isNotEmpty) {
        // If no active connection and no saved selection, select first server
        _selectedConfig = _configs.first;
        await _saveSelectedServer();
      }

      notifyListeners();
    } catch (e) {
      // Failed to initialize V2Ray
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
      _isInitializing = false;
      notifyListeners();
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
  
  // CRITICAL FIX: Enhanced method to synchronize with actual VPN service state
  Future<void> _enhancedSyncWithVpnServiceState() async {
    try {
      // Check if VPN is actually running using the improved method
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      
      // Reset all connection states first
      for (int i = 0; i < _configs.length; i++) {
        _configs[i].isConnected = false;
      }
      
      if (isActuallyConnected) {
        // VPN is actually running, synchronizing config states
        final activeConfigFromService = _v2rayService.activeConfig;
        
        if (activeConfigFromService != null) {
          bool configFound = false;
          
          // Try to find exact matching config
          for (var config in _configs) {
            if (config.fullConfig == activeConfigFromService.fullConfig) {
              config.isConnected = true;
              _selectedConfig = config;
              configFound = true;
              break;
            }
          }
          
          // If exact match not found, try matching by address and port
          if (!configFound) {
            for (var config in _configs) {
              if (config.address == activeConfigFromService.address &&
                  config.port == activeConfigFromService.port) {
                config.isConnected = true;
                _selectedConfig = config;
                configFound = true;
                break;
              }
            }
          }
          
          // If still no matching config found, add the active config temporarily
          if (!configFound) {
            _configs.add(activeConfigFromService);
            activeConfigFromService.isConnected = true;
            _selectedConfig = activeConfigFromService;
          }
        } else {
          // VPN is running but we don't have the config details
          // Mark the first config as connected if we have configs
          if (_configs.isNotEmpty) {
            _configs.first.isConnected = true;
            _selectedConfig = _configs.first;
          }
        }
      } else {
        // VPN is not actually connected, clearing connection states
        for (var config in _configs) {
          config.isConnected = false;
        }
        _selectedConfig = null;
        
        // Clear active config from service if it exists
        if (_v2rayService.activeConfig != null) {
          await _v2rayService.disconnect();
        }
      }
      
      // Save the synchronized state
      await _v2rayService.saveConfigs(_configs);
    } catch (e) {
      // Error in synchronization, ensure clean state
      for (var config in _configs) {
        config.isConnected = false;
      }
      _selectedConfig = null;
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

  Future<void> _handleNotificationDisconnect() async {
    // Actually disconnect the VPN service
    await _v2rayService.disconnect();
    
    // Update config status when disconnected from notification
    for (int i = 0; i < _configs.length; i++) {
      _configs[i].isConnected = false;
    }

    _selectedConfig = null;

    // Notify listeners immediately to update UI in real-time
    notifyListeners();

    // Persist the changes
    try {
      await _v2rayService.saveConfigs(_configs);
      notifyListeners();
    } catch (e) {
      // Error saving configs after notification disconnect
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // When app is resumed, check connection status after a delay
      // This allows the VPN connection time to stabilize
      Future.delayed(const Duration(milliseconds: 500), () async {
        // CRITICAL FIX: Enhanced synchronization with actual VPN service state when app resumes
        await _enhancedSyncWithVpnServiceState();
        notifyListeners();
      });
    } else if (state == AppLifecycleState.paused) {
      // App is paused, VPN status will be maintained in background
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
  
}
