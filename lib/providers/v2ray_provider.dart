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
  V2RayConfig? _selectedConfig;
  final List<Subscription> _subscriptions = [];
  
  // Subscriptions removed - using GitHub servers only
  bool _isConnecting = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLoadingServers = false;
  bool _isInitializing = true;
  DateTime? _lastSuccessfulConnection;
  bool _wasUsingSmartConnect = false;
  DateTime? _lastStatusCheck;
  
  // Method channel for VPN control
  static const platform = MethodChannel('com.tiksarvpn.app/vpn_control');
  
  // Event channel for receiving VPN status updates from native side
  static const EventChannel _vpnStatusEventChannel = EventChannel('com.tiksarvpn.app/vpn_status_events');
  StreamSubscription? _vpnStatusSubscription;

  // Return configs with Smart Connect at the top
  List<V2RayConfig> get configs {
    final smartConnect = V2RayConfig.smartConnect();
    return [smartConnect, ..._configs];
  }
  
  // Get actual server configs (without Smart Connect)
  List<V2RayConfig> get serverConfigs => _configs;
  V2RayConfig? get selectedConfig => _selectedConfig;
  V2RayConfig? get activeConfig => _v2rayService.activeConfig;
  bool get isConnecting => _isConnecting;
  bool get isLoading => _isLoading;
  bool get isLoadingServers => _isLoadingServers;
  String get errorMessage => _errorMessage;
  V2RayService get v2rayService => _v2rayService;
  bool get isInitializing => _isInitializing;

  // Expose V2Ray status for real-time traffic monitoring
  V2RayStatus? get currentStatus => _v2rayService.currentStatus;

  V2RayProvider() {
    WidgetsBinding.instance.addObserver(this);
    _v2rayService.addListener(_onV2RayServiceChanged);
    _setupVpnStatusListener();
    _initialize();
    platform.setMethodCallHandler(_handleMethodCall);
    _startPersistentConnectionMonitoring();
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
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking VPN connection status...');
      
      // CRITICAL: When app comes back from background, immediately check VPN status
      // This ensures UI shows correct connection state even if app was killed/restarted
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          debugPrint('🔄 Starting VPN status check after app resume...');
          
          // Force check actual VPN connection status
          await forceCheckVpnStatus();
          
          debugPrint('✅ VPN status check completed after app resume');
        } catch (e) {
          debugPrint('❌ Error checking VPN status after resume: $e');
          // Still notify to show last known state
          notifyListeners();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      debugPrint('📱 App paused');
    }
  }
  
  /// سیستم مانیتورینگ هوشمند - بدون مصرف باتری
  /// فقط روی event-driven و lifecycle تکیه می‌کنه
  void _startPersistentConnectionMonitoring() {
    debugPrint('🔄 Starting smart connection monitoring (event-driven)...');
    
    // به جای تایمر دوره‌ای، فقط در مواقع خاص چک می‌کنیم:
    // 1. وقتی برنامه resume می‌شه (در didChangeAppLifecycleState)
    // 2. وقتی native event می‌فرسته (در _setupVpnStatusListener)
    // 3. وقتی کاربر دستی چک می‌کنه (در forceCheckVpnStatus)
    
    // این رویکرد:
    // ✅ صفر مصرف باتری در background
    // ✅ بلافاصله وقتی برنامه باز می‌شه چک می‌کنه
    // ✅ از native events برای تغییرات real-time استفاده می‌کنه
    
    debugPrint('✅ Smart monitoring active (zero battery drain)');
  }
  
  /// Setup VPN status event listener (inspired by defyxVPN)
  /// This listens to real-time VPN status changes from native side
  void _setupVpnStatusListener() {
    try {
      debugPrint('?? Setting up VPN status event listener...');
      
      _vpnStatusSubscription = _vpnStatusEventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final Map<String, dynamic> statusEvent = Map<String, dynamic>.from(event);
            
            if (statusEvent.containsKey('status')) {
              final String vpnStatus = statusEvent['status'] as String;
              debugPrint('?? VPN status event received: $vpnStatus');
              
              // Handle VPN status changes from native side
              _handleNativeVpnStatusChange(vpnStatus);
            }
          }
        },
        onError: (dynamic error) {
          debugPrint('? Error from VPN status event channel: $error');
        },
      );
      
      debugPrint('? VPN status listener setup complete');
    } catch (e) {
      debugPrint('?? Could not setup VPN status listener: $e');
      // Continue without event listener - not critical
    }
  }
  
  /// Handle VPN status changes from native side
  void _handleNativeVpnStatusChange(String status) {
    debugPrint('?? Handling native VPN status change: $status');
    
    // CRITICAL FIX: Ignore ALL native events for 8 seconds after successful connection
    // This prevents race conditions where native sends stale events that reset UI
    // Using milliseconds to catch events that arrive within first second
    if (_lastSuccessfulConnection != null) {
      final timeSinceConnection = DateTime.now().difference(_lastSuccessfulConnection!);
      if (timeSinceConnection.inMilliseconds < 8000) {
        debugPrint('?? Ignoring ALL native events (within 8s grace period after connection)');
        debugPrint('?? Time since connection: ${timeSinceConnection.inMilliseconds}ms');
        return;
      }
    }
    
    switch (status.toLowerCase()) {
      case 'connected':
        // VPN connected from native side
        debugPrint('? Native reports VPN connected');
        
        // If we're already in connection process, skip sync to avoid UI reset
        if (_isConnecting) {
          debugPrint('?? Skipping sync - already in connection process');
          break;
        }
        
        // Only sync if we think we're disconnected but native says connected
        // This handles cases where app was backgrounded during connection
        if (_v2rayService.activeConfig == null) {
          debugPrint('?? Syncing state - native connected but we think disconnected');
          Future.delayed(const Duration(milliseconds: 500), () async {
            await _enhancedSyncWithVpnServiceState();
            notifyListeners();
          });
        }
        break;
        
      case 'disconnected':
      case 'stopped':
        // VPN disconnected from native side
        debugPrint('? Native reports VPN disconnected');
        
        // CRITICAL: Ignore native disconnect events during connection process
        // to prevent UI from resetting while we're connecting
        if (_isConnecting) {
          debugPrint('?? Ignoring native disconnect event during connection process');
          break;
        }
        
        // EXTRA SAFETY: If we just successfully connected (within last 10 seconds),
        // be extremely cautious about disconnect events
        if (_lastSuccessfulConnection != null) {
          final timeSinceConnection = DateTime.now().difference(_lastSuccessfulConnection!);
          if (timeSinceConnection.inMilliseconds < 10000) {
            debugPrint('?? SAFETY: Ignoring disconnect within 10s of successful connection');
            debugPrint('?? Time since connection: ${timeSinceConnection.inMilliseconds}ms');
            break;
          }
        }
        
        // ADDITIONAL FIX: Double-check that we actually have a connected config
        // and that we're not in the process of establishing a connection
        final hasConnectedConfig = _configs.any((c) => c.isConnected);
        final hasActiveConfig = _v2rayService.activeConfig != null;
        
        // If native says disconnected but we just connected, ignore this stale event
        if (hasActiveConfig && !hasConnectedConfig) {
          debugPrint('?? Ignoring stale disconnect event - activeConfig exists but configs not yet updated');
          break;
        }
        
        // Only update if we think we're connected and have an active config
        if (hasConnectedConfig || hasActiveConfig) {
          debugPrint('?? Processing native disconnect event...');
          // Run async operation properly with error handling
          Future(() async {
            try {
              for (var config in _configs) {
                config.isConnected = false;
              }
              await _v2rayService.saveConfigs(_configs);
              notifyListeners();
              debugPrint('? Configs updated after native disconnect event');
            } catch (e) {
              debugPrint('? Error updating configs after native disconnect: $e');
              // Still notify to update UI
              notifyListeners();
            }
          });
        } else {
          debugPrint('?? Ignoring disconnect event - already disconnected');
        }
        break;
        
      default:
        debugPrint('?? Unknown VPN status from native: $status');
        break;
    }
  }

  Future<void> _initialize() async {
    _setLoading(true);
    _isInitializing = true;
    notifyListeners();
    
    try {
      debugPrint('?? Starting app initialization...');
      
      // STEP 1: INSTANT UI - Load saved state and show immediately (0-50ms)
      await _loadSavedStateAndShowUI();
      debugPrint('? Saved state loaded and UI displayed');
      
      // STEP 2: QUICK SYNC - Check VPN status IMMEDIATELY (50-200ms)
      // This is the most critical step for showing connection state
      final quickSyncFuture = _enhancedSyncWithVpnServiceState();
      
      // STEP 3: Initialize service in parallel
      final serviceInitFuture = _v2rayService.initialize();
      
      // Wait for both quick sync and service init
      await Future.wait([quickSyncFuture, serviceInitFuture]);
      debugPrint('? Quick sync and service init complete');
      
      // STEP 2.5: RETRY SYNC - If VPN was connected but sync failed, retry after delay
      // This handles cases where device was restarted and VPN needs time to restore
      if (_configs.any((c) => c.isConnected) && _v2rayService.activeConfig == null) {
        debugPrint('?? Config marked as connected but no activeConfig, retrying sync...');
        await Future.delayed(const Duration(seconds: 2));
        await _enhancedSyncWithVpnServiceState();
        debugPrint('? Retry sync complete');
      }

      // Set up callback for notification disconnects
      _v2rayService.setDisconnectedCallback(() {
        _handleNotificationDisconnect();
      });

      // STEP 4: Load configurations from storage (already loaded in STEP 1)
      // Skip if already loaded in _loadSavedStateAndShowUI
      if (_configs.isEmpty) {
        await loadConfigs();
        debugPrint('? Configs loaded from storage: ${_configs.length} servers');
      } else {
        debugPrint('? Configs already loaded: ${_configs.length} servers');
      }

      // STEP 5: Fetch fresh servers from GitHub
      // Strategy: ALWAYS fetch in background to keep servers updated
      //           Show cached servers immediately if available
      if (_configs.isEmpty) {
        debugPrint('?? No cached servers, fetching from GitHub (blocking)...');
        _isLoadingServers = true;
        notifyListeners();
        
        await fetchServers(customUrl: 'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub2.txt');
        debugPrint('? Fresh servers fetched: ${_configs.length} servers');
        
        _isLoadingServers = false;
        notifyListeners();
      } else {
        debugPrint('? Using cached servers (${_configs.length} servers)');
        debugPrint('?? Updating servers from GitHub in background...');
        
        // Fetch in background to update servers without blocking UI
        fetchServers(customUrl: 'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub2.txt')
          .then((_) {
            debugPrint('? Background server update complete: ${_configs.length} servers');
          })
          .catchError((e) {
            debugPrint('?? Background server update failed: $e');
            // Keep using cached servers on error
          });
      }
      
      // STEP 6: Final sync to ensure everything is correct
      await _enhancedSyncWithVpnServiceState();
      
      // STEP 7: Smart server selection logic
      if (_configs.isNotEmpty) {
        final hasConnectedConfig = _configs.any((c) => c.isConnected);
        
        if (hasConnectedConfig) {
          // Priority 1: Keep connected server
          _selectedConfig = _configs.firstWhere((c) => c.isConnected);
          debugPrint('? Keeping connected server: ${_selectedConfig?.remark}');
        } else {
          // Priority 2: Load previously selected server
          final savedServer = await _loadSelectedServer();
          if (savedServer != null) {
            _selectedConfig = savedServer;
            debugPrint('? Restored saved server: ${_selectedConfig?.remark}');
          } else if (_selectedConfig == null) {
            // Priority 3: Default to Smart Connect (first time only)
            _selectedConfig = V2RayConfig.smartConnect();
            // Save Smart Connect as default
            await _saveSelectedServer(_selectedConfig!);
            debugPrint('? Auto-selected Smart Connect as default');
          }
        }
        notifyListeners();
      }

      // STEP 8: چک کردن برای auto-reconnect
      // اگه قبلاً متصل بودیم ولی الان نیستیم (مثلاً نت قطع شده بود)
      await checkAndAutoReconnect();
      
      debugPrint('? Initialization complete');
      notifyListeners();
    } catch (e) {
      debugPrint('? Failed to initialize: $e');
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
      _isInitializing = false;
      notifyListeners();
    }
  }
  
  // Note: Removed _loadSelectedServer and _saveSelectedServer methods
  // We always auto-select the first server on app start (unless already connected)
  // User selection is temporary and resets after disconnect
  
  // CRITICAL FIX: Enhanced method to synchronize with actual VPN service state
  Future<void> _enhancedSyncWithVpnServiceState() async {
    try {
      debugPrint('?? Starting VPN state synchronization...');
      
      // Check if VPN is actually running using the improved method
      // Use longer timeout for initial check (handles device restart scenarios)
      final isActuallyConnected = await _v2rayService.isActuallyConnected()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('?? VPN status check timeout, checking saved state...');
              // If timeout, check if we have a saved connected config
              return _configs.any((c) => c.isConnected);
            },
          );
      debugPrint('?? VPN actually connected: $isActuallyConnected');
      
      // IMPORTANT: Don't reset states before checking!
      // This prevents UI flicker when VPN is actually connected
      
      if (isActuallyConnected) {
        debugPrint('? VPN is running, synchronizing config states...');
        
        // VPN is actually running, synchronizing config states
        final activeConfigFromService = _v2rayService.activeConfig;
        debugPrint('?? Active config from service: ${activeConfigFromService?.remark}');
        
        if (activeConfigFromService != null) {
          bool configFound = false;
          String? matchedConfigId;
          
          // Try to find exact matching config
          for (var config in _configs) {
            if (config.fullConfig == activeConfigFromService.fullConfig) {
              matchedConfigId = config.id;
              configFound = true;
              debugPrint('? Found exact matching config: ${config.remark}');
              break;
            }
          }
          
          // If exact match not found, try matching by address and port
          if (!configFound) {
            debugPrint('?? Exact match not found, trying address/port match...');
            for (var config in _configs) {
              if (config.address == activeConfigFromService.address &&
                  config.port == activeConfigFromService.port) {
                matchedConfigId = config.id;
                configFound = true;
                debugPrint('? Found matching config by address/port: ${config.remark}');
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
            debugPrint('?? No matching config found, adding active config temporarily');
            // Check if not already in list to avoid duplicates
            if (!_configs.any((c) => c.id == activeConfigFromService.id)) {
              _configs.add(activeConfigFromService);
            }
            activeConfigFromService.isConnected = true;
            _selectedConfig = activeConfigFromService;
            debugPrint('? Added and selected: ${activeConfigFromService.remark}');
          }
        } else {
          debugPrint('?? VPN is running but no active config details from service');
          
          // VPN is running but we don't have the config details
          // Use the selected config from SharedPreferences if available
          String? selectedId;
          
          if (_selectedConfig != null) {
            // We have a selected config
            final selectedIndex = _configs.indexWhere((c) => c.id == _selectedConfig!.id);
            if (selectedIndex != -1) {
              selectedId = _selectedConfig!.id;
              debugPrint('? Will mark selected config as connected: ${_configs[selectedIndex].remark}');
            } else {
              // Selected config not in list, use first as fallback
              if (_configs.isNotEmpty) {
                selectedId = _configs.first.id;
                _selectedConfig = _configs.first;
                debugPrint('?? Selected config not found, will use first: ${_configs.first.remark}');
              }
            }
          } else {
            // No selected config, use first as fallback
            if (_configs.isNotEmpty) {
              selectedId = _configs.first.id;
              _selectedConfig = _configs.first;
              debugPrint('?? No selected config, will use first: ${_configs.first.remark}');
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
        debugPrint('? VPN is NOT connected, clearing all connection states');
        
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
          debugPrint('? Cleared connection states (were connected, now disconnected)');
        } else {
          debugPrint('?? All configs already disconnected, no changes needed');
        }
        debugPrint('?? Keeping selected config: ${_selectedConfig?.remark ?? "none"}');
        
        // Keep _selectedConfig so user can reconnect to the same server
        // Only clear isConnected flag, not the selection itself
        
        // Don't call disconnect if not connected - prevents errors
        // Just clear the state
      }
      
      // Save the synchronized state
      try {
        await _v2rayService.saveConfigs(_configs);
        debugPrint('?? Synchronized state saved successfully');
      } catch (saveError) {
        debugPrint('?? Error saving configs during sync: $saveError');
      }
      
      // Log final state
      debugPrint('?? Final sync state:');
      debugPrint('   - Selected config: ${_selectedConfig?.remark ?? "none"}');
      debugPrint('   - Connected configs: ${_configs.where((c) => c.isConnected).map((c) => c.remark).join(", ")}');
      
    } catch (e) {
      debugPrint('? Error in synchronization: $e');
      // Error in synchronization, ensure clean state
      for (var config in _configs) {
        config.isConnected = false;
      }
      debugPrint('?? Cleared all connection states due to error');
      // Keep _selectedConfig even on error so user can try reconnecting
      // Don't set _selectedConfig = null
      debugPrint('?? Keeping selected config: ${_selectedConfig?.remark ?? "none"}');
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

  // Subscription feature disabled - using GitHub servers only
  Future<void> loadSubscriptions() async {
    // No-op: Subscriptions disabled
  }

  Future<void> addConfig(V2RayConfig config) async {
    // Add config and display it immediately (avoid duplicates)
    if (!_configs.any((c) => c.id == config.id)) {
      _configs.add(config);
    }

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
    // Disabled: Subscriptions not supported
    _setError('Subscription feature is disabled');
  }

  Future<void> updateSubscription(Subscription subscription) async {
    // Disabled: Subscriptions not supported
    _setError('Subscription feature is disabled');
  }
  
  // Update subscription info without refreshing servers
  Future<void> updateSubscriptionInfo(Subscription subscription) async {
    // Disabled: Subscriptions not supported
    _setError('Subscription feature is disabled');
  }
  
  // Update all subscriptions
  Future<void> updateAllSubscriptions() async {
    // Disabled: Subscriptions not supported
    return;
    /*
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

          // Add new configs (avoid duplicates by checking ID)
          for (var config in configs) {
            if (!_configs.any((c) => c.id == config.id)) {
              _configs.add(config);
            }
          }

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
    */
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

  Future<bool> connectToServer(V2RayConfig config) async {
    debugPrint('?? Starting connection to: ${config.remark}');
    
    // VALIDATION: Check if config is valid
    if (config.address.isEmpty || config.port <= 0) {
      _setError('Invalid server configuration: ${config.remark}');
      return false;
    }
    
    // SAFETY: Prevent multiple simultaneous connections
    if (_isConnecting) {
      debugPrint('?? Connection already in progress, ignoring duplicate request');
      return false;
    }
    
    _isConnecting = true;
    _errorMessage = '';
    notifyListeners();

    // Connection configuration
    const int maxAttempts = 3;
    const int retryDelaySeconds = 1;
    const int connectionTimeout = 30;
    
    // Track connection success for finally block
    bool success = false;
    String lastError = '';

    try {
      debugPrint('?? Connection parameters:');
      debugPrint('   - Server: ${config.remark}');
      debugPrint('   - Address: ${config.address}:${config.port}');
      debugPrint('   - Protocol: ${config.configType}');
      debugPrint('   - Max attempts: $maxAttempts');
      
      // STEP 1: Disconnect from current server if connected
      if (_v2rayService.activeConfig != null) {
        debugPrint('?? Disconnecting from current server: ${_v2rayService.activeConfig?.remark}');
        try {
          await _v2rayService.disconnect()
              .timeout(const Duration(seconds: 5));
          debugPrint('? Disconnected from previous server');
          
          // Small delay to ensure clean disconnect
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('?? Error disconnecting from current server: $e');
          // Continue with connection attempt even if disconnect failed
        }
      }

      // STEP 2: Try to connect with automatic retry
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        debugPrint('?? Connection attempt $attempt/$maxAttempts...');
        
        try {
          // Attempt connection with timeout
          success = await _v2rayService
              .connect(config)
              .timeout(
                Duration(seconds: connectionTimeout),
                onTimeout: () {
                  debugPrint('?? Connection timeout after ${connectionTimeout}s');
                  return false;
                },
              );

          if (success) {
            debugPrint('?? Connection attempt $attempt succeeded!');
            break;
          } else {
            lastError = 'Failed to connect to ${config.remark} on attempt $attempt';
            debugPrint('? $lastError');

            // If this is not the last attempt, wait before retrying
            if (attempt < maxAttempts) {
              debugPrint('? Waiting ${retryDelaySeconds}s before retry...');
              await Future.delayed(Duration(seconds: retryDelaySeconds));
            }
          }
        } catch (e) {
          // Handle different types of errors
          if (e.toString().contains('timeout')) {
            lastError = 'Connection timeout on attempt $attempt';
            debugPrint('?? $lastError: $e');
          } else if (e.toString().contains('permission')) {
            lastError = 'VPN permission denied';
            debugPrint('?? $lastError: $e');
            // Don't retry on permission errors
            break;
          } else {
            lastError = 'Error on connection attempt $attempt';
            debugPrint('? $lastError: $e');
          }

          // If this is not the last attempt, wait before retrying
          if (attempt < maxAttempts && !e.toString().contains('permission')) {
            debugPrint('? Waiting ${retryDelaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: retryDelaySeconds));
          }
        }
      }

      // STEP 3: Handle connection result
      if (success) {
        try {
          debugPrint('? VPN connection successful, updating UI state...');
          
          // CRITICAL PHASE 1: Establish grace period FIRST
          // This MUST be the very first thing to prevent race conditions
          _lastSuccessfulConnection = DateTime.now();
          debugPrint('??? Grace period activated for 8 seconds');
          debugPrint('??? Start time: ${_lastSuccessfulConnection!.toIso8601String()}');
          
          // CRITICAL PHASE 2: Update internal state IMMEDIATELY
          _errorMessage = '';
          
          // Update all configs: only connected one should be marked
          bool configUpdated = false;
          for (int i = 0; i < _configs.length; i++) {
            if (_configs[i].id == config.id) {
              _configs[i].isConnected = true;
              configUpdated = true;
              debugPrint('? Marked ${_configs[i].remark} as connected');
            } else if (_configs[i].isConnected) {
              _configs[i].isConnected = false;
              debugPrint('?? Unmarked ${_configs[i].remark}');
            }
          }
          
          if (!configUpdated) {
            debugPrint('?? Warning: Config ${config.id} not found in list, adding it');
            config.isConnected = true;
            // Check if not already in list to avoid duplicates
            if (!_configs.any((c) => c.id == config.id)) {
              _configs.add(config);
            }
          }
          
          _selectedConfig = config;
          debugPrint('? Selected config updated: ${config.remark}');
          
          // CRITICAL PHASE 3: Verify activeConfig from service
          if (_v2rayService.activeConfig == null) {
            debugPrint('?? WARNING: activeConfig is null after connection!');
            debugPrint('?? This should not happen - connection may be unstable');
          } else {
            final activeRemark = _v2rayService.activeConfig?.remark ?? 'Unknown';
            debugPrint('? Service activeConfig verified: $activeRemark');
            
            // Double-check it matches our config
            if (_v2rayService.activeConfig?.id != config.id) {
              debugPrint('?? Warning: activeConfig mismatch!');
              debugPrint('   Expected: ${config.id}');
              debugPrint('   Got: ${_v2rayService.activeConfig?.id}');
            }
          }
          
          // CRITICAL PHASE 4: Notify UI IMMEDIATELY
          notifyListeners();
          debugPrint('? UI notified - Connected: true, Error: cleared');
          
          // PHASE 5: Small delay to ensure UI renders
          await Future.delayed(const Duration(milliseconds: 150));
          
          // PHASE 6: Background tasks (non-blocking)
          debugPrint('?? Starting background tasks...');
          
          _v2rayService.saveConfigs(_configs).catchError((e) {
            debugPrint('?? Error saving configs: $e');
          });
          
          // ذخیره وضعیت اتصال به‌صورت جداگانه برای بازیابی سریع‌تر
          _saveConnectionState(config).catchError((e) {
            debugPrint('?? Error saving connection state: $e');
          });

          _v2rayService.resetUsageStats().catchError((e) {
            debugPrint('?? Error resetting stats: $e');
          });
          
          _analyticsService.logVpnConnect(
            serverName: config.remark,
            serverAddress: config.address,
            serverPort: config.port,
            country: config.remark.isNotEmpty 
                ? (config.remark.contains('-') 
                    ? config.remark.split('-').first.trim() 
                    : config.remark.trim())
                : 'Unknown',
            protocol: config.configType,
          ).catchError((e) {
            debugPrint('?? Analytics error: $e');
          });
          
          debugPrint('?? Connection fully established to ${config.remark}!');
          
        } catch (e) {
          debugPrint('? CRITICAL: Error in post-connection setup: $e');
          debugPrint('? Stack trace: ${StackTrace.current}');
          // Don't set error - connection succeeded, just setup failed
          // Still notify UI to show connected state
          notifyListeners();
        }
      } else {
        // Connection failed after all attempts
        debugPrint('?? Connection failed after $maxAttempts attempts');
        debugPrint('?? Last error: $lastError');
        _setError(
          'Failed to connect to ${config.remark} after $maxAttempts attempts: $lastError',
        );
      }
    } catch (e) {
      // Unexpected error in connection process
      debugPrint('? FATAL: Unexpected error in connection process');
      debugPrint('? Error: $e');
      debugPrint('? Stack trace: ${StackTrace.current}');
      _setError('Unexpected error connecting to ${config.remark}: $e');
    } finally {
      debugPrint('?? Entering finally block...');
      debugPrint('?? Success: $success');
      debugPrint('?? _isConnecting: $_isConnecting');
      
      _isConnecting = false;
      
      // CRITICAL SAFETY CHECK: Verify connection state integrity
      if (success && _v2rayService.activeConfig != null) {
        debugPrint('?? Final state verification...');
        
        // Find the config that should be connected
        V2RayConfig? connectedConfig;
        try {
          connectedConfig = _configs.firstWhere(
            (c) => c.id == config.id,
            orElse: () {
              debugPrint('?? Config not found in list, using provided config');
              return config;
            },
          );
        } catch (e) {
          debugPrint('? Error finding config: $e');
          connectedConfig = config;
        }
        
        // Verify and restore if needed
        if (!connectedConfig.isConnected) {
          debugPrint('?? CRITICAL: Connected state was corrupted! Restoring...');
          debugPrint('   Config: ${connectedConfig.remark}');
          debugPrint('   Should be connected: true');
          debugPrint('   Current state: ${connectedConfig.isConnected}');
          
          // Restore the correct state
          connectedConfig.isConnected = true;
          for (var c in _configs) {
            if (c.id != config.id && c.isConnected) {
              debugPrint('   Disconnecting: ${c.remark}');
              c.isConnected = false;
            }
          }
          
          debugPrint('? State restored successfully');
        } else {
          debugPrint('? State integrity verified - all good!');
        }
        
        // Final verification
        final activeRemark = _v2rayService.activeConfig?.remark ?? 'Unknown';
        final connectedCount = _configs.where((c) => c.isConnected).length;
        debugPrint('?? Final state summary:');
        debugPrint('   Active config: $activeRemark');
        debugPrint('   Connected configs count: $connectedCount');
        debugPrint('   Selected config: ${_selectedConfig?.remark ?? 'None'}');
        
        if (connectedCount != 1) {
          debugPrint('?? WARNING: Expected 1 connected config, got $connectedCount');
        }
      } else if (success && _v2rayService.activeConfig == null) {
        debugPrint('?? WARNING: Success but no activeConfig!');
        debugPrint('   This indicates a serious problem');
      }
      
      // Always notify UI at the end to ensure latest state
      notifyListeners();
      debugPrint('?? Connection process completed - UI notified');
      debugPrint('????????????????????????????????????????');
    }
    
    return success;
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
      
      // Clear the grace period timer
      _lastSuccessfulConnection = null;
      
      // پاک کردن وضعیت اتصال ذخیره شده
      await _clearConnectionState();
      
      // Update config status
      for (int i = 0; i < _configs.length; i++) {
        _configs[i].isConnected = false;
      }

      // IMPORTANT: If user was using Smart Connect, reset to Smart Connect after disconnect
      // Otherwise keep the manually selected server
      if (_wasUsingSmartConnect) {
        _selectedConfig = V2RayConfig.smartConnect();
        await _saveSelectedServer(_selectedConfig!);
        debugPrint('? Reset to Smart Connect after disconnect');
      } else {
        debugPrint('? Keeping selected server after disconnect: ${_selectedConfig?.remark}');
      }

      // Persist the changes
      await _v2rayService.saveConfigs(_configs);
    } catch (e) {
      _setError('Error disconnecting: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // Smart Connect: Test top servers and connect to fastest one
  Future<bool> smartConnect({int maxServersToTest = 5}) async {
    if (_configs.isEmpty) {
      _setError('No servers available');
      return false;
    }

    // Mark that user is using Smart Connect
    _wasUsingSmartConnect = true;

    _isConnecting = true;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('?? Smart Connect: Testing top $maxServersToTest servers...');
      
      // Get top servers to test (max 5 for speed)
      final serversToTest = _configs.take(maxServersToTest).toList();
      
      // Test all servers in parallel using batch method
      final pingResults = await _v2rayService.batchTestServerDelays(
        serversToTest,
        batchSize: 5,
        useCache: false,
      );
      
      // Find fastest responding server
      V2RayConfig? fastestServer;
      int lowestPing = 999999;
      
      for (final server in serversToTest) {
        final ping = pingResults[server.id];
        if (ping != null && ping < lowestPing && ping < 9999) {
          lowestPing = ping;
          fastestServer = server;
        }
      }
      
      if (fastestServer == null) {
        // No server responded, try connecting to selected/first server anyway
<<<<<<< HEAD
        debugPrint('⚠️ No server responded to ping, trying selected server...');
        if (_selectedConfig != null) {
          fastestServer = _selectedConfig;
        } else if (_configs.isNotEmpty) {
          fastestServer = _configs.first;
        } else {
          _setError('No servers available');
          return;
        }
=======
        debugPrint('?? No server responded to ping, trying selected server...');
        fastestServer = _selectedConfig ?? _configs.first;
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
      } else {
        debugPrint('? Fastest server found: ${fastestServer.remark} (${lowestPing}ms)');
      }
      
      // IMPORTANT: Don't call selectConfig here to keep Smart Connect as selected
      // Just connect directly to the fastest server
      
      _isConnecting = false;
      notifyListeners();
      
      // Now connect to fastest server (without changing selectedConfig)
      final success = await connectToServer(fastestServer);
      
      if (success) {
        debugPrint('?? Smart Connect successful to ${fastestServer.remark}');
        return true;
      } else {
        // If connection failed, try next best server
        debugPrint('? Connection to ${fastestServer.remark} failed, trying alternatives...');
        
        // Sort servers by ping and try next ones
        final sortedServers = serversToTest.where((s) {
          final ping = pingResults[s.id];
          return ping != null && ping < 9999 && s.id != fastestServer!.id;
        }).toList()
          ..sort((a, b) {
            final pingA = pingResults[a.id] ?? 999999;
            final pingB = pingResults[b.id] ?? 999999;
            return pingA.compareTo(pingB);
          });
        
        // Try up to 2 more servers (without changing selectedConfig)
        for (final server in sortedServers.take(2)) {
<<<<<<< HEAD
          debugPrint('🔄 Trying alternative server: ${server.remark}');
=======
          debugPrint('?? Trying alternative server: ${server.remark}');
          await selectConfig(server);
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
          
          final altSuccess = await connectToServer(server);
          if (altSuccess) {
            debugPrint('? Connected to alternative server: ${server.remark}');
            return true;
          }
        }
        
        _setError('Could not connect to any available server');
        return false;
      }
    } catch (e) {
      debugPrint('? Smart Connect error: $e');
      _setError('Smart Connect failed: $e');
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // Removed testServerDelay method as requested

  // Removed pingServer and pingAllServers methods as requested

  Future<void> selectConfig(V2RayConfig config) async {
    _selectedConfig = config;
    
    // Track if user selected Smart Connect or a manual server
    if (config.isSmartConnect) {
      _wasUsingSmartConnect = true;
      debugPrint('? User selected Smart Connect');
    } else {
      _wasUsingSmartConnect = false;
      debugPrint('? User selected manual server: ${config.remark}');
    }
    
    // IMPORTANT: Save selected server to persist across app restarts
    await _saveSelectedServer(config);
    debugPrint('? Selected and saved server: ${config.remark}');
    
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
  
  // Save selected server to SharedPreferences
  Future<void> _saveSelectedServer(V2RayConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_server_id', config.id);
      debugPrint('?? Saved selected server ID: ${config.id}');
    } catch (e) {
      debugPrint('? Error saving selected server: $e');
    }
  }
  
  // Load selected server from SharedPreferences
  Future<V2RayConfig?> _loadSelectedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedServerId = prefs.getString('selected_server_id');
      
      if (selectedServerId != null) {
        // Check if Smart Connect was selected
        if (selectedServerId == 'smart_connect') {
          debugPrint('?? Loaded Smart Connect');
          return V2RayConfig.smartConnect();
        }
        
        // Try to find the saved server in configs
        if (_configs.isNotEmpty) {
          try {
            final server = _configs.firstWhere(
              (config) => config.id == selectedServerId,
            );
            debugPrint('?? Loaded selected server: ${server.remark}');
            return server;
          } catch (e) {
            debugPrint('?? Saved server not found in configs');
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('? Error loading selected server: $e');
      return null;
    }
  }

  // Proxy mode feature removed for simplification
  
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
    debugPrint('?? Notification disconnect triggered');
    
    // Actually disconnect the VPN service
    await _v2rayService.disconnect();
    
    // Update config status when disconnected from notification
    for (int i = 0; i < _configs.length; i++) {
      _configs[i].isConnected = false;
    }

    // IMPORTANT: Keep _selectedConfig so user can easily reconnect
    // Don't set _selectedConfig = null
    debugPrint('?? Keeping selected config: ${_selectedConfig?.remark}');

    // Notify listeners immediately to update UI in real-time
    notifyListeners();

    // Persist the changes
    try {
      await _v2rayService.saveConfigs(_configs);
      notifyListeners();
      debugPrint('? Configs saved after notification disconnect');
    } catch (e) {
      debugPrint('? Error saving configs after notification disconnect: $e');
      notifyListeners();
    }
  }

  
  // OPTIMISTIC UI: Load saved state immediately for instant UI display
  Future<void> _loadSavedStateAndShowUI() async {
    try {
      debugPrint('?? Loading saved state for optimistic UI...');
      
      // Load configs from storage immediately (very fast, no network)
      final savedConfigs = await _v2rayService.loadConfigs();
      if (savedConfigs.isNotEmpty) {
        _configs = savedConfigs;
        debugPrint('?? Loaded ${_configs.length} saved configs');
        
        // بازیابی وضعیت اتصال ذخیره شده
        await _restoreConnectionState();
        
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
              debugPrint('?? Restored selected server: ${_selectedConfig?.remark}');
            } else {
              debugPrint('?? Saved server not found in configs');
            }
          } catch (e) {
            debugPrint('?? Could not restore saved server: $e');
          }
        }
        
        // Check if any config is marked as connected
        final connectedConfigIndex = _configs.indexWhere((c) => c.isConnected);
        if (connectedConfigIndex != -1) {
          _selectedConfig = _configs[connectedConfigIndex];
          debugPrint('?? Found connected config: ${_selectedConfig?.remark}');
          
          // CRITICAL: Force service to restore activeConfig immediately
          // This ensures activeConfig is available when UI checks it
          if (_v2rayService.activeConfig == null) {
            debugPrint('?? Service activeConfig is null, triggering restore...');
            // Try to restore immediately in background
            _v2rayService.initialize().then((_) {
              debugPrint('? Service initialized, checking activeConfig...');
              if (_v2rayService.activeConfig != null) {
                debugPrint('? ActiveConfig restored: ${_v2rayService.activeConfig?.remark}');
                notifyListeners();
              } else {
                debugPrint('?? ActiveConfig still null after init');
              }
            }).catchError((e) {
              debugPrint('? Error initializing service: $e');
            });
          }
        }
        
        // Notify UI immediately with saved state
        notifyListeners();
        debugPrint('? Optimistic UI loaded and displayed');
      } else {
        debugPrint('?? No saved configs found');
      }
    } catch (e) {
      debugPrint('? Error loading saved state: $e');
      // Error loading saved state, continue with empty list
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

  /// Force check VPN status (inspired by defyxVPN's getVPNStatus)
  /// This method directly queries the VPN service for actual status
  /// Use this after app resume or when you need to verify connection state
  Future<void> forceCheckVpnStatus() async {
    // بهینه‌سازی: اگه کمتر از 3 ثانیه پیش چک شده، دوباره چک نکن
    // این از چک‌های مکرر و بی‌مورد جلوگیری می‌کنه
    if (_lastStatusCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastStatusCheck!);
      if (timeSinceLastCheck.inSeconds < 3) {
        debugPrint('⏭️ Skipping status check (checked ${timeSinceLastCheck.inSeconds}s ago)');
        return;
      }
    }
    
    try {
      debugPrint('?? Force checking VPN status from service...');
      _lastStatusCheck = DateTime.now();
      
      // روش defyxVPN: اول از isTunnelRunning استفاده کن (سریع‌تر)
      final isTunnelRunning = await _v2rayService.isTunnelRunning()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('?? Tunnel check timeout');
              return false;
            },
          );
      
      debugPrint('?? Tunnel running: $isTunnelRunning');
      
      // اگه tunnel در حال اجراست، مطمئناً متصلیم
      final isActuallyConnected = isTunnelRunning;
      
      debugPrint('?? VPN actually connected: $isActuallyConnected');
      debugPrint('?? Active config: ${_v2rayService.activeConfig?.remark ?? "none"}');
      
      if (isActuallyConnected) {
        // VPN is running, sync state
        await _enhancedSyncWithVpnServiceState();
        
        // Clear any error messages when VPN is actually connected
        if (_errorMessage.isNotEmpty) {
          _errorMessage = '';
          debugPrint('? Cleared error message (VPN is connected)');
        }
        
        // CRITICAL: Ensure UI shows connected state
<<<<<<< HEAD
        if (_configs.isNotEmpty) {
          final connectedConfig = _configs.firstWhere(
            (c) => c.isConnected,
            orElse: () => _configs.first,
          );
          
          debugPrint('✅ VPN status confirmed: CONNECTED');
          debugPrint('✅ Active server: ${_v2rayService.activeConfig?.remark ?? "Unknown"}');
          debugPrint('✅ UI showing: ${connectedConfig.remark} as connected');
        } else {
          debugPrint('⚠️ VPN connected but no configs loaded yet');
        }
=======
        final connectedConfig = _configs.firstWhere(
          (c) => c.isConnected,
          orElse: () => _configs.first,
        );
        
        debugPrint('? VPN status confirmed: CONNECTED');
        debugPrint('? Active server: ${_v2rayService.activeConfig?.remark ?? "Unknown"}');
        debugPrint('? UI showing: ${connectedConfig.remark} as connected');
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
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
          debugPrint('? VPN status confirmed: DISCONNECTED');
          debugPrint('? All configs marked as disconnected');
        } else {
          debugPrint('?? VPN already disconnected, no state change needed');
        }
      }
      
      // CRITICAL: Always notify UI to refresh, even if state didn't change
      // This ensures UI reflects the correct state after app resume
      notifyListeners();
      debugPrint('? UI notified of current VPN state');
    } catch (e) {
      debugPrint('? Error force checking VPN status: $e');
      // Still notify listeners to show last known state
      notifyListeners();
    }
  }
  
  // Method to manually check connection status
  Future<void> checkConnectionStatus() async {
    try {
      debugPrint('?? Checking connection status...');
      
      // Always check the actual VPN connection status
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;
      
      debugPrint('?? VPN is actually connected: $isActuallyConnected');
      debugPrint('?? Active config: ${activeConfig?.remark}');
      
      bool statusChanged = false;
      
      if (isActuallyConnected && activeConfig != null) {
        // VPN is actually connected - ensure UI shows this
        debugPrint('? VPN is connected, syncing UI...');
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
              debugPrint('? Found matching config: ${_configs[i].remark}');
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
            debugPrint('?? Active config not in list, adding it');
            activeConfig.isConnected = true;
            _configs.insert(0, activeConfig);
            _selectedConfig = activeConfig;
            statusChanged = true;
          }
        }
      } else {
        // VPN is NOT connected - ensure all configs show disconnected
        debugPrint('? VPN is not connected, clearing all connection states');
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
        debugPrint('?? Connection status saved');
      }
      
      // Always notify to refresh UI
      notifyListeners();
      debugPrint('?? UI updated with connection status');
    } catch (e) {
      debugPrint('? Error checking connection status: $e');
      // Don't change connection state on errors, but still notify UI
      notifyListeners();
    }
  }
  
  /// ذخیره وضعیت اتصال به‌صورت جداگانه - برای بازیابی سریع
  Future<void> _saveConnectionState(V2RayConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ذخیره اطلاعات اتصال فعلی
      await prefs.setString('last_connected_server_id', config.id);
      await prefs.setString('last_connected_server_name', config.remark);
      await prefs.setString('last_connected_server_address', config.address);
      await prefs.setInt('last_connected_server_port', config.port);
      await prefs.setString('last_connection_time', DateTime.now().toIso8601String());
      await prefs.setBool('is_vpn_connected', true);
      
      debugPrint('💾 Connection state saved: ${config.remark}');
    } catch (e) {
      debugPrint('❌ Error saving connection state: $e');
    }
  }
  
  /// بازیابی وضعیت اتصال از SharedPreferences
  Future<void> _restoreConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final isConnected = prefs.getBool('is_vpn_connected') ?? false;
      
      if (!isConnected) {
        debugPrint('📂 No saved connection state found');
        return;
      }
      
      final serverId = prefs.getString('last_connected_server_id');
      final serverName = prefs.getString('last_connected_server_name') ?? 'Unknown';
      final lastConnectionTime = prefs.getString('last_connection_time');
      
      if (serverId == null) {
        debugPrint('⚠️ Saved connection state incomplete');
        return;
      }
      
      debugPrint('📂 Found saved connection state:');
      debugPrint('   Server: $serverName');
      debugPrint('   ID: $serverId');
      debugPrint('   Last connected: $lastConnectionTime');
      
      // پیدا کردن config مربوطه
      final config = _configs.firstWhere(
        (c) => c.id == serverId,
        orElse: () => _configs.first,
      );
      
      // علامت‌گذاری به‌عنوان متصل
      for (var c in _configs) {
        c.isConnected = (c.id == serverId);
      }
      
      _selectedConfig = config;
      
      debugPrint('✅ Connection state restored: ${config.remark}');
    } catch (e) {
      debugPrint('❌ Error restoring connection state: $e');
    }
  }
  
  /// پاک کردن وضعیت اتصال ذخیره شده
  Future<void> _clearConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('last_connected_server_id');
      await prefs.remove('last_connected_server_name');
      await prefs.remove('last_connected_server_address');
      await prefs.remove('last_connected_server_port');
      await prefs.remove('last_connection_time');
      await prefs.setBool('is_vpn_connected', false);
      
      debugPrint('🗑️ Connection state cleared');
    } catch (e) {
      debugPrint('❌ Error clearing connection state: $e');
    }
  }
  
  Future<void> checkAndAutoReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final wasConnected = prefs.getBool('is_vpn_connected') ?? false;
      
      if (!wasConnected) {
        return;
      }
      
      final isCurrentlyConnected = await _v2rayService.isTunnelRunning()
          .timeout(const Duration(seconds: 2));
      
      if (isCurrentlyConnected) {
        debugPrint('✅ VPN still connected');
        return;
      }
      
      debugPrint('🔄 VPN was connected but now disconnected, auto-reconnecting...');
      
      final serverId = prefs.getString('last_connected_server_id');
      if (serverId == null) {
        return;
      }
      
      final server = _configs.firstWhere(
        (c) => c.id == serverId,
        orElse: () => _configs.first,
      );
      
      debugPrint('🔄 Reconnecting to: ${server.remark}');
      
      await connectToServer(server);
      
    } catch (e) {
      debugPrint('❌ Auto-reconnect failed: $e');
    }
  }
  
}
