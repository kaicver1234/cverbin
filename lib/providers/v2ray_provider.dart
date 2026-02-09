import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
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
  bool _isLoadingServers = false;
  bool _isInitializing = true; // Track initialization state
  DateTime? _lastSuccessfulConnection; // Track last successful connection time
  
  // Missing private variables
  bool _isConnecting = false;
  bool _isLoading = false;
  String _errorMessage = '';
  V2RayConfig? _selectedConfig;
  bool _wasUsingSmartConnect = true; // Default to Smart Connect
  
  // Getter for wasUsingSmartConnect
  bool get wasUsingSmartConnect => _wasUsingSmartConnect;
  
  // Smart Connect: Find and connect to fastest server (tests first 15 servers)
  // Uses V2Ray core delay for accurate results
  Future<void> smartConnect() async {
    // Prevent multiple simultaneous calls
    if (_isConnecting) {
      debugPrint('⚠️ Smart Connect already in progress, ignoring...');
      return;
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('⚡ SMART CONNECT: Starting...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _errorMessage = '';
    _wasUsingSmartConnect = true;
    _isConnecting = true;
    notifyListeners();
    
    try {
      // Get server configs
      var servers = serverConfigs;
      
      // If no servers, try to load them first
      if (servers.isEmpty) {
        debugPrint('⚠️ No servers loaded, fetching...');
        await fetchServers();
        servers = serverConfigs;
      }
      
      if (servers.isEmpty) {
        debugPrint('❌ No servers available');
        _setError('No servers available');
        _isConnecting = false;
        notifyListeners();
        return;
      }
      
      debugPrint('📋 Total servers available: ${servers.length}');
      debugPrint('🎯 Testing first 15 servers using V2Ray core delay...');
      
      // Test first 15 servers using V2Ray core delay
      final serversToTest = servers.take(15).toList();
      debugPrint('📦 Servers to test: ${serversToTest.length}');
      
      // Test servers in batches (10 at a time)
      final results = <String, int>{};
      final batchSize = 10;
      
      for (int i = 0; i < serversToTest.length; i += batchSize) {
        final end = (i + batchSize < serversToTest.length) ? i + batchSize : serversToTest.length;
        final batch = serversToTest.sublist(i, end);
        
        debugPrint('');
        debugPrint('📊 Testing batch ${i ~/ batchSize + 1}: servers ${i + 1} to $end');
        
        // Test batch in parallel
        final batchResults = await Future.wait(
          batch.map((config) async {
            try {
              final delay = await _v2rayService.getServerDelay(config).timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  debugPrint('   ⏱️ ${config.remark}: Timeout');
                  return -1;
                },
              );
              
              if (delay != null && delay >= 0 && delay < 10000) {
                debugPrint('   ✅ ${config.remark}: ${delay}ms');
              } else {
                debugPrint('   ❌ ${config.remark}: Failed');
              }
              
              return MapEntry(config.id, delay ?? -1);
            } catch (e) {
              debugPrint('   ❌ ${config.remark}: Error - $e');
              return MapEntry(config.id, -1);
            }
          }),
        );
        
        // Add results
        for (final entry in batchResults) {
          results[entry.key] = entry.value;
        }
        
        // Small delay between batches
        if (end < serversToTest.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 RESULTS: Got ${results.length}/${serversToTest.length} responses');
      
      // Find fastest server from results
      V2RayConfig? fastestServer;
      int lowestPing = 999999;
      int successfulPings = 0;
      
      for (final server in serversToTest) {
        final delay = results[server.id];
        if (delay != null && delay >= 0 && delay < 10000) {
          successfulPings++;
          if (delay < lowestPing) {
            lowestPing = delay;
            fastestServer = server;
          }
        }
      }
      
      debugPrint('✅ Successful pings: $successfulPings/${serversToTest.length}');
      
      // Use fastest server or fallback to first
      final serverToConnect = fastestServer ?? servers.first;
      
      if (fastestServer != null) {
        debugPrint('');
        debugPrint('🏆 FASTEST SERVER FOUND:');
        debugPrint('   Server: ${serverToConnect.remark}');
        debugPrint('   Ping: ${lowestPing}ms');
      } else {
        debugPrint('');
        debugPrint('⚠️ No successful pings, using first server:');
        debugPrint('   Server: ${serverToConnect.remark}');
      }
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      _selectedConfig = serverToConnect;
      notifyListeners();
      
      // Reset _isConnecting before calling connectToServer
      // connectToServer will set it to true again
      _isConnecting = false;
      
      // Connect to the selected server
      debugPrint('🔌 Connecting to selected server...');
      await connectToServer(serverToConnect);
      
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ SMART CONNECT ERROR: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Fallback: try to connect to first server
      try {
        final servers = serverConfigs;
        if (servers.isNotEmpty) {
          debugPrint('⚠️ Fallback: Connecting to first server');
          _selectedConfig = servers.first;
          _isConnecting = false;
          await connectToServer(servers.first);
        } else {
          _setError('Connection failed: $e');
        }
      } catch (fallbackError) {
        debugPrint('❌ Fallback connection also failed: $fallbackError');
        _setError('Connection failed: $e');
      }
    } finally {
      // Always ensure _isConnecting is reset
      if (_isConnecting) {
        _isConnecting = false;
        notifyListeners();
      }
    }
  }
  
  // Getter for server configs (excluding smart connect)
  List<V2RayConfig> get serverConfigs => _configs.where((c) => !c.isSmartConnect).toList();
  
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
  bool get isInitializing => _isInitializing;

  // Expose V2Ray status for real-time traffic monitoring
  V2RayStatus? get currentStatus => _v2rayService.currentStatus;

  V2RayProvider() {
    WidgetsBinding.instance.addObserver(this);
    _v2rayService.addListener(_onV2RayServiceChanged);
    _setupVpnStatusListener();
    _initialize();
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
    
    // CRITICAL FIX: Ignore ALL native events for 8 seconds after successful connection
    // This prevents race conditions where native sends stale events that reset UI
    // Using milliseconds to catch events that arrive within first second
    if (_lastSuccessfulConnection != null) {
      final timeSinceConnection = DateTime.now().difference(_lastSuccessfulConnection!);
      if (timeSinceConnection.inMilliseconds < 8000) {
        debugPrint('⏭️ Ignoring ALL native events (within 8s grace period after connection)');
        debugPrint('⏭️ Time since connection: ${timeSinceConnection.inMilliseconds}ms');
        return;
      }
    }
    
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
        
        // CRITICAL: Ignore native disconnect events during connection process
        // to prevent UI from resetting while we're connecting
        if (_isConnecting) {
          debugPrint('⏭️ Ignoring native disconnect event during connection process');
          break;
        }
        
        // EXTRA SAFETY: If we just successfully connected (within last 10 seconds),
        // be extremely cautious about disconnect events
        if (_lastSuccessfulConnection != null) {
          final timeSinceConnection = DateTime.now().difference(_lastSuccessfulConnection!);
          if (timeSinceConnection.inMilliseconds < 10000) {
            debugPrint('⏭️ SAFETY: Ignoring disconnect within 10s of successful connection');
            debugPrint('⏭️ Time since connection: ${timeSinceConnection.inMilliseconds}ms');
            break;
          }
        }
        
        // ADDITIONAL FIX: Double-check that we actually have a connected config
        // and that we're not in the process of establishing a connection
        final hasConnectedConfig = _configs.any((c) => c.isConnected);
        final hasActiveConfig = _v2rayService.activeConfig != null;
        
        // If native says disconnected but we just connected, ignore this stale event
        if (hasActiveConfig && !hasConnectedConfig) {
          debugPrint('⏭️ Ignoring stale disconnect event - activeConfig exists but configs not yet updated');
          break;
        }
        
        // Only update if we think we're connected and have an active config
        if (hasConnectedConfig || hasActiveConfig) {
          debugPrint('🔄 Processing native disconnect event...');
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
        } else {
          debugPrint('⏭️ Ignoring disconnect event - already disconnected');
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
      
      // STEP 1: Initialize V2Ray service FIRST - this restores activeConfig
      await _v2rayService.initialize();
      debugPrint('✅ V2Ray service initialized');
      
      // STEP 2: Check if VPN is actually connected using delay check
      bool isVpnConnected = false;
      try {
        final delay = await _v2rayService.getConnectedServerDelayDirect()
            .timeout(const Duration(seconds: 3), onTimeout: () => -1);
        isVpnConnected = delay >= 0 && delay < 10000;
        debugPrint('🔎 VPN delay check: ${delay}ms, connected: $isVpnConnected');
      } catch (e) {
        debugPrint('⚠️ Delay check failed: $e');
      }
      
      // STEP 3: Load saved configs for UI
      await _loadSavedStateAndShowUI();
      debugPrint('✅ Saved state loaded');
      
      // STEP 4: Sync connection state based on actual VPN status
      if (isVpnConnected) {
        final activeConfig = _v2rayService.activeConfig;
        if (activeConfig != null) {
          // Mark the active config as connected
          bool foundMatch = false;
          for (var config in _configs) {
            final shouldBeConnected = 
                config.id == activeConfig.id ||
                config.fullConfig == activeConfig.fullConfig ||
                (config.address == activeConfig.address && config.port == activeConfig.port);
            
            config.isConnected = shouldBeConnected;
            if (shouldBeConnected) {
              foundMatch = true;
              _selectedConfig = config;
              _wasUsingSmartConnect = false;
            }
          }
          
          if (!foundMatch) {
            activeConfig.isConnected = true;
            _configs.insert(0, activeConfig);
            _selectedConfig = activeConfig;
            _wasUsingSmartConnect = false;
          }
          
          debugPrint('✅ VPN is connected to: ${_selectedConfig?.remark}');
        }
      } else {
        // VPN is not connected - clear all connection states
        for (var config in _configs) {
          config.isConnected = false;
        }
        debugPrint('❌ VPN is not connected');
      }
      
      notifyListeners();

      // Set up callback for notification disconnects
      _v2rayService.setDisconnectedCallback(() {
        _handleNotificationDisconnect();
      });

      // STEP 5: Fetch servers from main URL (replaces all old servers)
      try {
        await fetchServers();
        debugPrint('✅ Servers loaded: ${_configs.length} servers');
      } catch (e) {
        debugPrint('⚠️ Failed to fetch servers during init: $e');
        // Continue with cached servers if available
        if (_configs.isEmpty) {
          _setError('Could not load servers. Please check your internet connection.');
        }
      }
      
      // STEP 6: Final sync to ensure everything is correct
      await _enhancedSyncWithVpnServiceState();
      
      // Default to Smart Connect (unless already connected)
      final hasConnectedConfig = _configs.any((c) => c.isConnected);
      
      if (hasConnectedConfig) {
        _selectedConfig = _configs.firstWhere((c) => c.isConnected);
        _wasUsingSmartConnect = false;
        debugPrint('✅ Keeping connected server: ${_selectedConfig?.remark}');
      } else if (_selectedConfig == null) {
        // Default to Smart Connect only if no server selected
        _wasUsingSmartConnect = true;
        debugPrint('✅ Default to Smart Connect');
      }
      notifyListeners();

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
  
  // Note: Smart Connect is the default selection
  // User can manually select a specific server if they want
  
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
            // Check if not already in list to avoid duplicates
            if (!_configs.any((c) => c.id == activeConfigFromService.id)) {
              _configs.add(activeConfigFromService);
            }
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

  // Single server URL - ONLY source of servers
  static const String _serverUrl = 'https://sub.tiksar.ir/tiksarserver.txt';

  Future<void> fetchServers({String? customUrl}) async {
    _isLoadingServers = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Always use the main server URL
      final url = customUrl ?? _serverUrl;
      
      debugPrint('📡 Fetching servers from: $url');
      final servers = await _serverService.fetchServers(customUrl: url);

      if (servers.isNotEmpty) {
        _v2rayService.clearPingCache();
        
        // COMPLETELY REPLACE all configs - no merging, no duplicates
        _configs = servers;
        await _v2rayService.saveConfigs(_configs);
        debugPrint('✅ Loaded ${_configs.length} servers from online');
      } else {
        // Fallback to cache if online fetch returns empty
        debugPrint('⚠️ Online fetch returned empty, loading from cache...');
        _configs = await _v2rayService.loadConfigs();
        debugPrint('📂 Loaded ${_configs.length} servers from cache');
        
        if (_configs.isEmpty) {
          _setError('No servers available');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch servers: $e');
      debugPrint('📂 Loading servers from cache...');
      
      // Load from cache when network fails
      _configs = await _v2rayService.loadConfigs();
      
      if (_configs.isNotEmpty) {
        debugPrint('✅ Loaded ${_configs.length} servers from cache');
        // Don't set error if we have cached servers
      } else {
        _setError('Failed to load servers. Please check your connection.');
      }
    } finally {
      _isLoadingServers = false;
      notifyListeners();
    }
  }

  Future<void> loadSubscriptions() async {
    // Simplified - just ensure we have the default subscription
    _subscriptions = [
      Subscription(
        id: 'default',
        name: 'Default Subscription',
        url: _serverUrl,
        lastUpdated: DateTime.now(),
        configIds: [],
      ),
    ];
    await _v2rayService.saveSubscriptions(_subscriptions);
    notifyListeners();
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
    _setLoading(true);
    _errorMessage = '';
    try {
      final configs = await _v2rayService.parseSubscriptionUrl(url);
      if (configs.isEmpty) {
        _setError('No valid configurations found in subscription');
        return;
      }

      // Add configs and display them immediately (avoid duplicates)
      for (var config in configs) {
        if (!_configs.any((c) => c.id == config.id)) {
          _configs.add(config);
        }
      }

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

      // Add new configs and display them immediately (avoid duplicates)
      for (var config in configs) {
        if (!_configs.any((c) => c.id == config.id)) {
          _configs.add(config);
        }
      }

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

  // Update all subscriptions - simplified to just fetch from main URL
  Future<void> updateAllSubscriptions() async {
    // Simply fetch servers from the main URL
    await fetchServers();
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

  Future<void> connectToServer(V2RayConfig config) async {
    debugPrint('🚀 Starting connection to: ${config.remark}');
    
    // VALIDATION: Check if config is valid
    if (config.address.isEmpty || config.port <= 0) {
      _setError('Invalid server configuration: ${config.remark}');
      return;
    }
    
    // SAFETY: Prevent multiple simultaneous connections
    if (_isConnecting) {
      debugPrint('⚠️ Connection already in progress, ignoring duplicate request');
      return;
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
      debugPrint('📋 Connection parameters:');
      debugPrint('   - Server: ${config.remark}');
      debugPrint('   - Address: ${config.address}:${config.port}');
      debugPrint('   - Protocol: ${config.configType}');
      debugPrint('   - Max attempts: $maxAttempts');
      
      // STEP 1: Disconnect from current server if connected
      if (_v2rayService.activeConfig != null) {
        debugPrint('🔌 Disconnecting from current server: ${_v2rayService.activeConfig?.remark}');
        try {
          await _v2rayService.disconnect()
              .timeout(const Duration(seconds: 5));
          debugPrint('✅ Disconnected from previous server');
          
          // Small delay to ensure clean disconnect
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('⚠️ Error disconnecting from current server: $e');
          // Continue with connection attempt even if disconnect failed
        }
      }

      // STEP 2: Try to connect with automatic retry
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        debugPrint('🔄 Connection attempt $attempt/$maxAttempts...');
        
        try {
          // Attempt connection with timeout
          success = await _v2rayService
              .connect(config)
              .timeout(
                Duration(seconds: connectionTimeout),
                onTimeout: () {
                  debugPrint('⏱️ Connection timeout after ${connectionTimeout}s');
                  return false;
                },
              );

          if (success) {
            debugPrint('🎉 Connection attempt $attempt succeeded!');
            break;
          } else {
            lastError = 'Failed to connect to ${config.remark} on attempt $attempt';
            debugPrint('❌ $lastError');

            // If this is not the last attempt, wait before retrying
            if (attempt < maxAttempts) {
              debugPrint('⏳ Waiting ${retryDelaySeconds}s before retry...');
              await Future.delayed(Duration(seconds: retryDelaySeconds));
            }
          }
        } catch (e) {
          // Handle different types of errors
          if (e.toString().contains('timeout')) {
            lastError = 'Connection timeout on attempt $attempt';
            debugPrint('⏱️ $lastError: $e');
          } else if (e.toString().contains('permission')) {
            lastError = 'VPN permission denied';
            debugPrint('🚫 $lastError: $e');
            // Don't retry on permission errors
            break;
          } else {
            lastError = 'Error on connection attempt $attempt';
            debugPrint('❌ $lastError: $e');
          }

          // If this is not the last attempt, wait before retrying
          if (attempt < maxAttempts && !e.toString().contains('permission')) {
            debugPrint('⏳ Waiting ${retryDelaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: retryDelaySeconds));
          }
        }
      }

      // STEP 3: Handle connection result
      if (success) {
        try {
          debugPrint('✅ VPN connection successful, updating UI state...');
          
          // CRITICAL PHASE 1: Establish grace period FIRST
          // This MUST be the very first thing to prevent race conditions
          _lastSuccessfulConnection = DateTime.now();
          debugPrint('🛡️ Grace period activated for 8 seconds');
          debugPrint('🛡️ Start time: ${_lastSuccessfulConnection!.toIso8601String()}');
          
          // CRITICAL PHASE 2: Update internal state IMMEDIATELY
          _errorMessage = '';
          
          // Update all configs: only connected one should be marked
          bool configUpdated = false;
          for (int i = 0; i < _configs.length; i++) {
            if (_configs[i].id == config.id) {
              _configs[i].isConnected = true;
              configUpdated = true;
              debugPrint('✅ Marked ${_configs[i].remark} as connected');
            } else if (_configs[i].isConnected) {
              _configs[i].isConnected = false;
              debugPrint('📴 Unmarked ${_configs[i].remark}');
            }
          }
          
          if (!configUpdated) {
            debugPrint('⚠️ Warning: Config ${config.id} not found in list, adding it');
            config.isConnected = true;
            // Check if not already in list to avoid duplicates
            if (!_configs.any((c) => c.id == config.id)) {
              _configs.add(config);
            }
          }
          
          _selectedConfig = config;
          debugPrint('✅ Selected config updated: ${config.remark}');
          
          // CRITICAL PHASE 3: Verify activeConfig from service
          if (_v2rayService.activeConfig == null) {
            debugPrint('⚠️ WARNING: activeConfig is null after connection!');
            debugPrint('⚠️ This should not happen - connection may be unstable');
          } else {
            final activeRemark = _v2rayService.activeConfig?.remark ?? 'Unknown';
            debugPrint('✅ Service activeConfig verified: $activeRemark');
            
            // Double-check it matches our config
            if (_v2rayService.activeConfig?.id != config.id) {
              debugPrint('⚠️ Warning: activeConfig mismatch!');
              debugPrint('   Expected: ${config.id}');
              debugPrint('   Got: ${_v2rayService.activeConfig?.id}');
            }
          }
          
          // CRITICAL PHASE 4: Notify UI IMMEDIATELY
          notifyListeners();
          debugPrint('✅ UI notified - Connected: true, Error: cleared');
          
          // PHASE 5: Small delay to ensure UI renders
          await Future.delayed(const Duration(milliseconds: 150));
          
          // PHASE 6: Background tasks (non-blocking)
          debugPrint('📝 Starting background tasks...');
          
          _v2rayService.saveConfigs(_configs).catchError((e) {
            debugPrint('⚠️ Error saving configs: $e');
          });

          _v2rayService.resetUsageStats().catchError((e) {
            debugPrint('⚠️ Error resetting stats: $e');
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
            debugPrint('⚠️ Analytics error: $e');
          });
          
          debugPrint('🎉 Connection fully established to ${config.remark}!');
          
        } catch (e) {
          debugPrint('❌ CRITICAL: Error in post-connection setup: $e');
          debugPrint('❌ Stack trace: ${StackTrace.current}');
          // Don't set error - connection succeeded, just setup failed
          // Still notify UI to show connected state
          notifyListeners();
        }
      } else {
        // Connection failed after all attempts
        debugPrint('💔 Connection failed after $maxAttempts attempts');
        debugPrint('💔 Last error: $lastError');
        _setError(
          'Failed to connect to ${config.remark} after $maxAttempts attempts: $lastError',
        );
      }
    } catch (e) {
      // Unexpected error in connection process
      debugPrint('❌ FATAL: Unexpected error in connection process');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      _setError('Unexpected error connecting to ${config.remark}: $e');
    } finally {
      debugPrint('🏁 Entering finally block...');
      debugPrint('🏁 Success: $success');
      debugPrint('🏁 _isConnecting: $_isConnecting');
      
      _isConnecting = false;
      
      // CRITICAL SAFETY CHECK: Verify connection state integrity
      if (success && _v2rayService.activeConfig != null) {
        debugPrint('🔍 Final state verification...');
        
        // Find the config that should be connected
        V2RayConfig? connectedConfig;
        try {
          connectedConfig = _configs.firstWhere(
            (c) => c.id == config.id,
            orElse: () {
              debugPrint('⚠️ Config not found in list, using provided config');
              return config;
            },
          );
        } catch (e) {
          debugPrint('❌ Error finding config: $e');
          connectedConfig = config;
        }
        
        // Verify and restore if needed
        if (!connectedConfig.isConnected) {
          debugPrint('🚨 CRITICAL: Connected state was corrupted! Restoring...');
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
          
          debugPrint('✅ State restored successfully');
        } else {
          debugPrint('✅ State integrity verified - all good!');
        }
        
        // Final verification
        final activeRemark = _v2rayService.activeConfig?.remark ?? 'Unknown';
        final connectedCount = _configs.where((c) => c.isConnected).length;
        debugPrint('📊 Final state summary:');
        debugPrint('   Active config: $activeRemark');
        debugPrint('   Connected configs count: $connectedCount');
        debugPrint('   Selected config: ${_selectedConfig?.remark ?? 'None'}');
        
        if (connectedCount != 1) {
          debugPrint('⚠️ WARNING: Expected 1 connected config, got $connectedCount');
        }
      } else if (success && _v2rayService.activeConfig == null) {
        debugPrint('🚨 WARNING: Success but no activeConfig!');
        debugPrint('   This indicates a serious problem');
      }
      
      // Always notify UI at the end to ensure latest state
      notifyListeners();
      debugPrint('🏁 Connection process completed - UI notified');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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
      
      // Clear the grace period timer
      _lastSuccessfulConnection = null;
      
      // Update config status
      for (int i = 0; i < _configs.length; i++) {
        _configs[i].isConnected = false;
      }

      // After disconnect, reset to Smart Connect
      _wasUsingSmartConnect = true;
      _selectedConfig = null;
      debugPrint('✅ Reset to Smart Connect after disconnect');

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
    // Check if Smart Connect is selected
    if (config.isSmartConnect) {
      debugPrint('⚡ Smart Connect selected');
      _wasUsingSmartConnect = true;
      notifyListeners();
      return; // Don't set as selected config, will be handled by connect
    }
    
    _wasUsingSmartConnect = false;
    _selectedConfig = config;
    // Note: We don't save selected server anymore - always defaults to first server
    // User selection is temporary until disconnect
    
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
      debugPrint('📱 App resumed, checking VPN status immediately...');
      
      // CRITICAL: Notify listeners FIRST to show last known state immediately
      notifyListeners();
      
      // CRITICAL: Like defyxVPN, check status IMMEDIATELY without delays
      // This ensures UI is synced with actual VPN state right away
      _syncVpnStatusOnResume();
      
    } else if (state == AppLifecycleState.paused) {
      // App is paused, VPN status will be maintained in background
      debugPrint('📱 App paused, VPN will continue in background');
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('📱 App inactive');
    } else if (state == AppLifecycleState.detached) {
      debugPrint('📱 App detached');
    }
  }
  
  /// Sync VPN status immediately on app resume (inspired by defyxVPN)
  Future<void> _syncVpnStatusOnResume() async {
    if (_isInitializing || _isConnecting) {
      debugPrint('⏭️ Skipping sync - app is initializing or connecting');
      return;
    }
    
    try {
      debugPrint('🔄 Syncing VPN status on app resume...');
      
      // STEP 1: Re-initialize service to restore saved state
      await _v2rayService.initialize();
      
      // STEP 2: Check actual VPN connection status using delay check FIRST
      // This is the most reliable method - it actually tests if V2Ray is running
      bool isOurVpnConnected = false;
      V2RayConfig? activeConfig = _v2rayService.activeConfig;
      
      // Try delay check first - most reliable
      try {
        final delay = await _v2rayService.getConnectedServerDelayDirect()
            .timeout(const Duration(seconds: 3), onTimeout: () => -1);
        
        if (delay >= 0 && delay < 10000) {
          isOurVpnConnected = true;
          debugPrint('✅ VPN connected (delay: ${delay}ms)');
        }
      } catch (e) {
        debugPrint('⚠️ Delay check failed: $e');
      }
      
      // If delay check failed, try isActuallyConnected
      if (!isOurVpnConnected) {
        isOurVpnConnected = await _v2rayService.isActuallyConnected()
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
        
        if (isOurVpnConnected) {
          debugPrint('✅ isActuallyConnected returned true');
          activeConfig = _v2rayService.activeConfig;
        }
      }
      
      debugPrint('🔎 Our VPN connected: $isOurVpnConnected');
      debugPrint('🔎 Active config: ${activeConfig?.remark ?? "none"}');
      
      bool stateChanged = false;
      
      if (isOurVpnConnected && activeConfig != null) {
        final config = activeConfig; // Local variable for type promotion
        debugPrint('✅ Our VPN is connected! Syncing UI...');
        
        // Find matching config in our list and mark as connected
        bool foundMatch = false;
        for (var c in _configs) {
          final shouldBeConnected = 
              c.id == config.id ||
              c.fullConfig == config.fullConfig ||
              (c.address == config.address && c.port == config.port);
          
          if (c.isConnected != shouldBeConnected) {
            c.isConnected = shouldBeConnected;
            stateChanged = true;
          }
          
          if (shouldBeConnected) {
            foundMatch = true;
            _selectedConfig = c;
          }
        }
        
        // If no match found, add active config to list
        if (!foundMatch && !_configs.any((c) => c.id == config.id)) {
          config.isConnected = true;
          _configs.insert(0, config);
          _selectedConfig = config;
          stateChanged = true;
          debugPrint('➕ Added active config to list: ${config.remark}');
        }
        
        // Ensure monitoring is active
        _v2rayService.ensureMonitoringActive();
      } else {
        debugPrint('❌ Our VPN is NOT connected, clearing states');
        
        // Clear all connection states
        for (var config in _configs) {
          if (config.isConnected) {
            config.isConnected = false;
            stateChanged = true;
          }
        }
      }
      
      // Save and notify
      if (stateChanged) {
        await _v2rayService.saveConfigs(_configs);
      }
      notifyListeners();
      
      debugPrint('✅ Sync complete - UI updated');
      
    } catch (e) {
      debugPrint('❌ Error syncing VPN status: $e');
      notifyListeners();
    }
  }
  
  /// Public method to force sync VPN status (can be called from UI)
  Future<void> forceSyncVpnStatus() async {
    debugPrint('🔄 Force sync requested...');
    await _syncVpnStatusOnResume();
  }
  
  // Method to fetch connection status from the notification
  Future<void> fetchNotificationStatus() async {
    try {
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;

      debugPrint(
        'Fetching notification status - Connected: $isActuallyConnected, Active config: ${activeConfig?.remark}',
      );

      bool statusChanged = false;

      if (activeConfig != null && isActuallyConnected) {
        for (int i = 0; i < _configs.length; i++) {
          bool shouldBeConnected =
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
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
            debugPrint('Updated config ${_configs[i].remark} to disconnected');
          }
        }
      }

      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
        notifyListeners();
        debugPrint('Connection status updated from notification check');
      }
    } catch (e) {
      debugPrint('Error fetching notification status: $e');
    }
  }

  // OPTIMISTIC UI: Load saved state immediately for instant UI display
  Future<void> _loadSavedStateAndShowUI() async {
    try {
      debugPrint('📂 Loading saved state for optimistic UI...');
      
      final savedConfigs = await _v2rayService.loadConfigs();
      if (savedConfigs.isNotEmpty) {
        _configs = savedConfigs;
        debugPrint('📂 Loaded ${_configs.length} saved configs');
        
        final prefs = await SharedPreferences.getInstance();
        final savedServerId = prefs.getString('selected_server_id');
        
        if (savedServerId != null) {
          try {
            final savedServerIndex = _configs.indexWhere(
              (config) => config.id == savedServerId,
            );
            if (savedServerIndex != -1) {
              _selectedConfig = _configs[savedServerIndex];
              debugPrint('📂 Restored selected server: ${_selectedConfig?.remark}');
            }
          } catch (e) {
            debugPrint('⚠️ Could not restore saved server: $e');
          }
        }
        
        final connectedConfigIndex = _configs.indexWhere((c) => c.isConnected);
        if (connectedConfigIndex != -1) {
          _selectedConfig = _configs[connectedConfigIndex];
          debugPrint('📂 Found connected config: ${_selectedConfig?.remark}');
        }
        
        notifyListeners();
        debugPrint('✅ Optimistic UI loaded and displayed');
      }
    } catch (e) {
      debugPrint('❌ Error loading saved state: $e');
    }
  }

  /// Force check VPN status
  Future<void> forceCheckVpnStatus() async {
    try {
      debugPrint('🔎 Force checking VPN status from service...');
      
      final isActuallyConnected = await _v2rayService.isActuallyConnected()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => _v2rayService.activeConfig != null,
          );
      
      debugPrint('🔎 VPN actually connected: $isActuallyConnected');
      
      if (isActuallyConnected) {
        await _enhancedSyncWithVpnServiceState();
        
        if (_errorMessage.isNotEmpty) {
          _errorMessage = '';
        }
        debugPrint('✅ VPN status confirmed: CONNECTED');
      } else {
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
      notifyListeners();
    }
  }
  
  // Method to manually check connection status
  Future<void> checkConnectionStatus() async {
    try {
      debugPrint('🔍 Checking connection status...');
      
      final isActuallyConnected = await _v2rayService.isActuallyConnected();
      final activeConfig = _v2rayService.activeConfig;
      
      bool statusChanged = false;
      
      if (isActuallyConnected && activeConfig != null) {
        debugPrint('✅ VPN is connected, syncing UI...');
        
        for (int i = 0; i < _configs.length; i++) {
          bool shouldBeConnected = _configs[i].fullConfig == activeConfig.fullConfig ||
              (_configs[i].address == activeConfig.address &&
               _configs[i].port == activeConfig.port);
          
          if (_configs[i].isConnected != shouldBeConnected) {
            _configs[i].isConnected = shouldBeConnected;
            statusChanged = true;
            if (shouldBeConnected) {
              _selectedConfig = _configs[i];
            }
          }
        }
      } else {
        debugPrint('❌ VPN is not connected, clearing all connection states');
        for (int i = 0; i < _configs.length; i++) {
          if (_configs[i].isConnected) {
            _configs[i].isConnected = false;
            statusChanged = true;
          }
        }
      }
      
      if (statusChanged) {
        await _v2rayService.saveConfigs(_configs);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking connection status: $e');
      notifyListeners();
    }
  }
}
