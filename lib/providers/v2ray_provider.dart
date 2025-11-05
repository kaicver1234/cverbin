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
  
  // Event channel for receiving VPN status updates from native side
  static const EventChannel _vpnStatusEventChannel = EventChannel('com.tiksarvpn.app/vpn_status_events');
  StreamSubscription? _vpnStatusSubscription;

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
    
    // Set up VPN status event listener (inspired by defyxVPN)
    _setupVpnStatusListener();
    
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
  
  /// Setup VPN status event listener (inspired by defyxVPN)
  /// This listens to real-time VPN status changes from native side
  void _setupVpnStatusListener() {
    try {
      debugPrint('📡 Setting up VPN status event listener...');
      
      _vpnStatusSubscription = _vpnStatusEventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final Map<String, dynamic> statusEvent = Map<String, dynamic>.from(event);
            
            if (statusEvent.containsKey('status')) {
              final String vpnStatus = statusEvent['status'] as String;
              debugPrint('📡 VPN status event received: $vpnStatus');
              
              // Handle VPN status changes from native side
              _handleNativeVpnStatusChange(vpnStatus);
            }
          }
        },
        onError: (dynamic error) {
          debugPrint('❌ Error from VPN status event channel: $error');
        },
      );
      
      debugPrint('✅ VPN status listener setup complete');
    } catch (e) {
      debugPrint('⚠️ Could not setup VPN status listener: $e');
      // Continue without event listener - not critical
    }
  }
  
  /// Handle VPN status changes from native side
  void _handleNativeVpnStatusChange(String status) {
    debugPrint('🔄 Handling native VPN status change: $status');
    
    switch (status.toLowerCase()) {
      case 'connected':
        // VPN connected from native side
        debugPrint('✅ Native reports VPN connected');
        
        // If we're already in connection process, skip sync to avoid UI reset
        if (_isConnecting) {
          debugPrint('⏭️ Skipping sync - already in connection process');
          break;
        }
        
        // Only sync if we think we're disconnected but native says connected
        // This handles cases where app was backgrounded during connection
        if (_v2rayService.activeConfig == null) {
          debugPrint('🔄 Syncing state - native connected but we think disconnected');
          Future.delayed(const Duration(milliseconds: 500), () async {
            await _enhancedSyncWithVpnServiceState();
            notifyListeners();
          });
        }
        break;
        
      case 'disconnected':
      case 'stopped':
        // VPN disconnected from native side
        debugPrint('❌ Native reports VPN disconnected');
        
        // IMPORTANT: Ignore native disconnect events during connection process
        // to prevent UI from resetting while we're connecting
        if (_isConnecting) {
          debugPrint('⏭️ Ignoring native disconnect event during connection process');
          break;
        }
        
        // Only update if we think we're connected
        if (_configs.any((c) => c.isConnected)) {
          // Run async operation properly with error handling
          Future(() async {
            try {
              for (var config in _configs) {
                config.isConnected = false;
              }
              await _v2rayService.saveConfigs(_configs);
              notifyListeners();
              debugPrint('✅ Configs updated after native disconnect event');
            } catch (e) {
              debugPrint('❌ Error updating configs after native disconnect: $e');
              // Still notify to update UI
              notifyListeners();
            }
          });
        }
        break;
        
      default:
        debugPrint('ℹ️ Unknown VPN status from native: $status');
        break;
    }
  }

  Future<void> _initialize() async {
    _setLoading(true);
    _isInitializing = true;
    notifyListeners();
    
    try {
      debugPrint('🚀 Starting app initialization...');
      
      // OPTIMISTIC UI: Load saved config immediately and show UI first
      await _loadSavedStateAndShowUI();
      debugPrint('✅ Saved state loaded and UI displayed');
      
      // Initialize service
      await _v2rayService.initialize();
      debugPrint('✅ V2Ray service initialized');

      // Set up callback for notification disconnects
      _v2rayService.setDisconnectedCallback(() {
        _handleNotificationDisconnect();
      });

      // Load configurations first
      await loadConfigs();
      debugPrint('✅ Configs loaded: ${_configs.length} servers');

      // Load subscriptions
      await loadSubscriptions();
      debugPrint('✅ Subscriptions loaded: ${_subscriptions.length} subscriptions');
      
      // Load proxy mode setting from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _isProxyMode = prefs.getBool('proxy_mode_enabled') ?? false;

      // Update all subscriptions on app start - await to ensure configs are loaded
      try {
        await updateAllSubscriptions();
        debugPrint('✅ Subscriptions updated');
      } catch (e) {
        debugPrint('⚠️ Subscription update failed: $e');
        // Ignore subscription update errors but continue initialization
      }

      // Load saved selected server first
      await _loadSelectedServer();
      debugPrint('✅ Selected server loaded: ${_selectedConfig?.remark ?? "none"}');
      
      // CRITICAL FIX: Enhanced synchronization with actual VPN service state
      // This method checks VPN status and updates all configs accordingly
      await _enhancedSyncWithVpnServiceState();
      
      // After sync, check if we need to auto-select first server
      // Only if nothing is selected AND not connected
      if (_selectedConfig == null && _configs.isNotEmpty) {
        // Check if any config is connected after sync
        final hasConnectedConfig = _configs.any((c) => c.isConnected);
        
        if (!hasConnectedConfig) {
          // No connection and no selection, auto-select first server
          _selectedConfig = _configs.first;
          await _saveSelectedServer();
          debugPrint('✅ Auto-selected first server: ${_selectedConfig?.remark}');
          notifyListeners();
        }
      }

      debugPrint('✅ Initialization complete');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize: $e');
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
      debugPrint('🔄 Starting VPN state synchronization...');
      
      // Check if VPN is actually running using the improved method
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      debugPrint('🔍 VPN actually connected: $isActuallyConnected');
      
      // IMPORTANT: Don't reset states before checking!
      // This prevents UI flicker when VPN is actually connected
      
      if (isActuallyConnected) {
        debugPrint('✅ VPN is running, synchronizing config states...');
        
        // VPN is actually running, synchronizing config states
        final activeConfigFromService = _v2rayService.activeConfig;
        debugPrint('🔍 Active config from service: ${activeConfigFromService?.remark}');
        
        if (activeConfigFromService != null) {
          bool configFound = false;
          String? matchedConfigId;
          
          // Try to find exact matching config
          for (var config in _configs) {
            if (config.fullConfig == activeConfigFromService.fullConfig) {
              matchedConfigId = config.id;
              configFound = true;
              debugPrint('✅ Found exact matching config: ${config.remark}');
              break;
            }
          }
          
          // If exact match not found, try matching by address and port
          if (!configFound) {
            debugPrint('⚠️ Exact match not found, trying address/port match...');
            for (var config in _configs) {
              if (config.address == activeConfigFromService.address &&
                  config.port == activeConfigFromService.port) {
                matchedConfigId = config.id;
                configFound = true;
                debugPrint('✅ Found matching config by address/port: ${config.remark}');
                break;
              }
            }
          }
          
          // Now update all configs: only matched one should be connected
          for (var config in _configs) {
            bool shouldBeConnected = (config.id == matchedConfigId);
            if (config.isConnected != shouldBeConnected) {
              config.isConnected = shouldBeConnected;
              if (shouldBeConnected) {
                _selectedConfig = config;
              }
            } else if (shouldBeConnected) {
              _selectedConfig = config;
            }
          }
          
          // If still no matching config found, add the active config temporarily
          if (!configFound) {
            debugPrint('⚠️ No matching config found, adding active config temporarily');
            _configs.add(activeConfigFromService);
            activeConfigFromService.isConnected = true;
            _selectedConfig = activeConfigFromService;
            debugPrint('✅ Added and selected: ${activeConfigFromService.remark}');
          }
        } else {
          debugPrint('⚠️ VPN is running but no active config details from service');
          
          // VPN is running but we don't have the config details
          // Use the selected config from SharedPreferences if available
          String? selectedId;
          
          if (_selectedConfig != null) {
            // We have a selected config
            final selectedIndex = _configs.indexWhere((c) => c.id == _selectedConfig!.id);
            if (selectedIndex != -1) {
              selectedId = _selectedConfig!.id;
              debugPrint('✅ Will mark selected config as connected: ${_configs[selectedIndex].remark}');
            } else {
              // Selected config not in list, use first as fallback
              if (_configs.isNotEmpty) {
                selectedId = _configs.first.id;
                _selectedConfig = _configs.first;
                debugPrint('⚠️ Selected config not found, will use first: ${_configs.first.remark}');
              }
            }
          } else {
            // No selected config, use first as fallback
            if (_configs.isNotEmpty) {
              selectedId = _configs.first.id;
              _selectedConfig = _configs.first;
              debugPrint('⚠️ No selected config, will use first: ${_configs.first.remark}');
            }
          }
          
          // Now sync all configs: only selected one should be connected
          for (var config in _configs) {
            bool shouldBeConnected = (config.id == selectedId);
            if (config.isConnected != shouldBeConnected) {
              config.isConnected = shouldBeConnected;
            }
          }
        }
      } else {
        debugPrint('❌ VPN is NOT connected, clearing all connection states');
        
        // VPN is not actually connected, clearing connection states
        // Only update configs that are currently marked as connected
        bool anyWasConnected = false;
        for (var config in _configs) {
          if (config.isConnected) {
            config.isConnected = false;
            anyWasConnected = true;
          }
        }
        
        if (anyWasConnected) {
          debugPrint('✅ Cleared connection states (were connected, now disconnected)');
        } else {
          debugPrint('ℹ️ All configs already disconnected, no changes needed');
        }
        debugPrint('💾 Keeping selected config: ${_selectedConfig?.remark ?? "none"}');
        
        // Keep _selectedConfig so user can reconnect to the same server
        // Only clear isConnected flag, not the selection itself
        
        // Don't call disconnect if not connected - prevents errors
        // Just clear the state
      }
      
      // Save the synchronized state
      try {
        await _v2rayService.saveConfigs(_configs);
        debugPrint('💾 Synchronized state saved successfully');
      } catch (saveError) {
        debugPrint('⚠️ Error saving configs during sync: $saveError');
      }
      
      // Log final state
      debugPrint('📊 Final sync state:');
      debugPrint('   - Selected config: ${_selectedConfig?.remark ?? "none"}');
      debugPrint('   - Connected configs: ${_configs.where((c) => c.isConnected).map((c) => c.remark).join(", ")}');
      
    } catch (e) {
      debugPrint('❌ Error in synchronization: $e');
      // Error in synchronization, ensure clean state
      for (var config in _configs) {
        config.isConnected = false;
      }
      debugPrint('🔄 Cleared all connection states due to error');
      // Keep _selectedConfig even on error so user can try reconnecting
      // Don't set _selectedConfig = null
      debugPrint('💾 Keeping selected config: ${_selectedConfig?.remark ?? "none"}');
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
    // Cancel VPN status event subscription
    _vpnStatusSubscription?.cancel();
    // Dispose the service to stop monitoring
    _v2rayService.dispose();
    // Disconnect if connected when disposing (fire and forget - no await in dispose)
    if (_v2rayService.activeConfig != null) {
      // Fire and forget - dispose can't be async
      _v2rayService.disconnect().catchError((e) {
        debugPrint('Error disconnecting in dispose: $e');
      });
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

  Future<void> connectToServer(V2RayConfig config, bool isProxyMode) async {
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
              .connect(config, isProxyMode)
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
          debugPrint('✅ VPN connection successful, updating UI state...');
          
          // Clear any previous error messages IMMEDIATELY
          _errorMessage = '';
          
          // Update config status IMMEDIATELY
          for (int i = 0; i < _configs.length; i++) {
            if (_configs[i].id == config.id) {
              _configs[i].isConnected = true;
            } else {
              _configs[i].isConnected = false;
            }
          }
          _selectedConfig = config;
          
          // Notify UI FIRST to show connected state immediately
          notifyListeners();
          debugPrint('✅ UI updated immediately - Connected: true, Error: empty');
          
          // Small delay to ensure UI updates before background tasks
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Persist the changes in background (don't wait)
          _v2rayService.saveConfigs(_configs).catchError((e) {
            debugPrint('⚠️ Error saving configs after connection: $e');
          });

          // Reset usage statistics in background
          _v2rayService.resetUsageStats().catchError((e) {
            debugPrint('⚠️ Error resetting usage stats: $e');
          });
          
          debugPrint('✅ Connection established - activeConfig: ${_v2rayService.activeConfig?.remark}');
          
          // Log analytics event in background
          _analyticsService.logVpnConnect(
            serverName: config.remark,
            serverAddress: config.address,
            serverPort: config.port,
            country: config.remark.split('-').first.trim(),
            protocol: config.configType,
          ).catchError((e) {
            debugPrint('⚠️ Analytics logging failed: $e');
          });
        } catch (e) {
          debugPrint('❌ Error in post-connection setup: $e');
          // Don't set error - connection succeeded, just logging failed
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
      debugPrint('🔄 Connection attempt finished, updating UI...');
      
      // Always notify UI at the end
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
            uploadBytes: _v2rayService.uploadBytes,
            downloadBytes: _v2rayService.downloadBytes,
            disconnectReason: 'user_action',
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
    
    // Log server selection analytics
    try {
      await _analyticsService.logServerSelection(
        serverName: config.remark,
        selectionMethod: 'manual',
      );
    } catch (e) {
      // Analytics logging failed, ignore
    }
    
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
    debugPrint('🔔 Notification disconnect triggered');
    
    // Actually disconnect the VPN service
    await _v2rayService.disconnect();
    
    // Update config status when disconnected from notification
    for (int i = 0; i < _configs.length; i++) {
      _configs[i].isConnected = false;
    }

    // IMPORTANT: Keep _selectedConfig so user can easily reconnect
    // Don't set _selectedConfig = null
    debugPrint('💾 Keeping selected config: ${_selectedConfig?.remark}');

    // Notify listeners immediately to update UI in real-time
    notifyListeners();

    // Persist the changes
    try {
      await _v2rayService.saveConfigs(_configs);
      notifyListeners();
      debugPrint('✅ Configs saved after notification disconnect');
    } catch (e) {
      debugPrint('❌ Error saving configs after notification disconnect: $e');
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, checking VPN status...');
      
      // When app is resumed, force check VPN status after a delay
      // Using longer delay (1.5s) to ensure VPN service is fully ready
      // This is especially important after app has been in background for a long time
      Future.delayed(const Duration(milliseconds: 1500), () async {
        debugPrint('📱 Starting VPN status verification...');
        await forceCheckVpnStatus();
        
        // Double check after another second to ensure state is synced
        Future.delayed(const Duration(milliseconds: 1000), () async {
          debugPrint('📱 Double-checking VPN status...');
          await forceCheckVpnStatus();
        });
      });
    } else if (state == AppLifecycleState.paused) {
      // App is paused, VPN status will be maintained in background
      debugPrint('📱 App paused, VPN will continue in background');
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('📱 App inactive');
    } else if (state == AppLifecycleState.detached) {
      debugPrint('📱 App detached');
    }
  }
  
  // Method to fetch connection status from the notification
  Future<void> fetchNotificationStatus() async {
    try {
      // Get the actual connection status from the service
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;

      debugPrint(
        'Fetching notification status - Connected: $isActuallyConnected, Active config: ${activeConfig?.remark}',
      );

      // Update all configs based on the actual status
      bool statusChanged = false;

      if (activeConfig != null && isActuallyConnected) {
        // VPN is connected, update the matching config
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
              debugPrint('Updated config ${_configs[i].remark} to connected');
            }
          }
        }
      } else {
        // VPN is not connected, clear all connected states
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
            debugPrint('Updated config ${_configs[i].remark} to disconnected');
          }
        }
        if (statusChanged) {
          // Keep selected config for easy reconnection
          // Don't set _selectedConfig to null
        }
      }

      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
        notifyListeners();
        debugPrint('Connection status updated from notification check');
      }
    } catch (e) {
      debugPrint('Error fetching notification status: $e');
      // Don't change connection state on errors
    }
  }


  // OPTIMISTIC UI: Load saved state immediately for instant UI display
  Future<void> _loadSavedStateAndShowUI() async {
    try {
      debugPrint('📂 Loading saved state for optimistic UI...');
      
      // Load configs from storage immediately (very fast, no network)
      final savedConfigs = await _v2rayService.loadConfigs();
      if (savedConfigs.isNotEmpty) {
        _configs = savedConfigs;
        debugPrint('📂 Loaded ${_configs.length} saved configs');
        
        // Try to load saved selected server first
        final prefs = await SharedPreferences.getInstance();
        final savedServerId = prefs.getString('selected_server_id');
        
        if (savedServerId != null) {
          // Try to find the saved selected server
          try {
            final savedServerIndex = _configs.indexWhere(
              (config) => config.id == savedServerId,
            );
            if (savedServerIndex != -1) {
              _selectedConfig = _configs[savedServerIndex];
              debugPrint('📂 Restored selected server: ${_selectedConfig?.remark}');
            } else {
              debugPrint('⚠️ Saved server not found in configs');
            }
          } catch (e) {
            debugPrint('⚠️ Could not restore saved server: $e');
          }
        }
        
        // Check if any config is marked as connected
        final connectedConfigIndex = _configs.indexWhere((c) => c.isConnected);
        if (connectedConfigIndex != -1) {
          _selectedConfig = _configs[connectedConfigIndex];
          debugPrint('📂 Found connected config: ${_selectedConfig?.remark}');
        }
        
        // Notify UI immediately with saved state
        notifyListeners();
        debugPrint('✅ Optimistic UI loaded and displayed');
      } else {
        debugPrint('📂 No saved configs found');
      }
    } catch (e) {
      debugPrint('❌ Error loading saved state: $e');
      // Error loading saved state, continue with empty list
    }
  }

  /// Force check VPN status (inspired by defyxVPN's getVPNStatus)
  /// This method directly queries the VPN service for actual status
  /// Use this after app resume or when you need to verify connection state
  Future<void> forceCheckVpnStatus() async {
    try {
      debugPrint('🔎 Force checking VPN status from service...');
      
      // Get actual connection status from service
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      
      debugPrint('🔎 VPN actually connected: $isActuallyConnected');
      
      if (isActuallyConnected) {
        // VPN is running, sync state
        await _enhancedSyncWithVpnServiceState();
        
        // Clear any error messages when VPN is actually connected
        if (_errorMessage.isNotEmpty) {
          _errorMessage = '';
          debugPrint('✅ Cleared error message (VPN is connected)');
        }
        
        debugPrint('✅ VPN status confirmed: CONNECTED');
        debugPrint('✅ Active server: ${_v2rayService.activeConfig?.remark ?? "Unknown"}');
      } else {
        // VPN is not running, clear all connection states
        bool stateChanged = false;
        for (var config in _configs) {
          if (config.isConnected) {
            config.isConnected = false;
            stateChanged = true;
          }
        }
        
        if (stateChanged) {
          await _v2rayService.saveConfigs(_configs);
          debugPrint('✅ VPN status confirmed: DISCONNECTED');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error force checking VPN status: $e');
    }
  }
  
  // Method to manually check connection status
  Future<void> checkConnectionStatus() async {
    try {
      debugPrint('🔍 Checking connection status...');
      
      // Always check the actual VPN connection status
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;
      
      debugPrint('🔍 VPN is actually connected: $isActuallyConnected');
      debugPrint('🔍 Active config: ${activeConfig?.remark}');
      
      bool statusChanged = false;
      
      if (isActuallyConnected && activeConfig != null) {
        // VPN is actually connected - ensure UI shows this
        debugPrint('✅ VPN is connected, syncing UI...');
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
              debugPrint('✅ Found matching config: ${_configs[i].remark}');
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
            debugPrint('⚠️ Active config not in list, adding it');
            activeConfig.isConnected = true;
            _configs.insert(0, activeConfig);
            _selectedConfig = activeConfig;
            statusChanged = true;
          }
        }
      } else {
        // VPN is NOT connected - ensure all configs show disconnected
        debugPrint('❌ VPN is not connected, clearing all connection states');
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
          }
        }
        // Keep selected config for easy reconnection
      }
      
      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
        debugPrint('💾 Connection status saved');
      }
      
      // Always notify to refresh UI
      notifyListeners();
      debugPrint('🔄 UI updated with connection status');
    } catch (e) {
      debugPrint('❌ Error checking connection status: $e');
      // Don't change connection state on errors, but still notify UI
      notifyListeners();
    }
  }
  
}
