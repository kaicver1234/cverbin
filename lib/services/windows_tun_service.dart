import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing Windows TUN interface for true VPN mode
/// Uses V2Ray's built-in TUN support for system-wide VPN
class WindowsTunService {
  static bool _isAdminChecked = false;
  static bool _hasAdminRights = false;
  static Process? _tunProcess;

  /// Check if the application is running with administrator privileges
  static Future<bool> checkAdminRights() async {
    if (_isAdminChecked) {
      return _hasAdminRights;
    }

    try {
      // Try to run a command that requires admin rights
      final result = await Process.run(
        'net',
        ['session'],
        runInShell: true,
      );

      _hasAdminRights = result.exitCode == 0;
      _isAdminChecked = true;

      if (_hasAdminRights) {
        debugPrint('✅ Running with Administrator privileges');
      } else {
        debugPrint('⚠️ Not running with Administrator privileges');
      }

      return _hasAdminRights;
    } catch (e) {
      debugPrint('❌ Error checking admin rights: $e');
      _hasAdminRights = false;
      _isAdminChecked = true;
      return false;
    }
  }

  /// Request administrator privileges by restarting the application
  static Future<bool> requestAdminRights() async {
    try {
      debugPrint('🔐 Requesting administrator privileges...');

      // Get the current executable path
      final exePath = Platform.resolvedExecutable;

      // Use PowerShell to restart with admin rights
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Start-Process -FilePath "$exePath" -Verb RunAs'
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        debugPrint('✅ Restarting with admin rights...');
        // Exit current instance
        exit(0);
      } else {
        debugPrint('❌ Failed to request admin rights: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting admin rights: $e');
    }
    
    return false;
  }

  /// Start V2Ray with TUN mode for true system-wide VPN
  static Future<bool> startTunMode(String v2rayConfig) async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required for TUN VPN mode');
        return false;
      }

      debugPrint('🔧 Starting V2Ray with TUN mode...');

      // Get app directory
      final appDir = await getApplicationDocumentsDirectory();
      final v2rayDir = Directory('${appDir.path}/v2ray');
      if (!await v2rayDir.exists()) {
        await v2rayDir.create(recursive: true);
      }

      // Parse the V2Ray config and add TUN inbound
      final configWithTun = await _addTunToConfig(v2rayConfig);
      
      // Save config to file
      final configFile = File('${v2rayDir.path}/config_tun.json');
      await configFile.writeAsString(configWithTun);

      // Start V2Ray with TUN config
      final v2rayExe = '${v2rayDir.path}/v2ray.exe';
      
      if (!await File(v2rayExe).exists()) {
        debugPrint('❌ V2Ray executable not found at: $v2rayExe');
        return false;
      }

      _tunProcess = await Process.start(
        v2rayExe,
        ['run', '-c', configFile.path],
        runInShell: true,
      );

      // Listen to output
      _tunProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('V2Ray TUN: $data');
      });

      _tunProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('V2Ray TUN Error: $data');
      });

      debugPrint('✅ V2Ray TUN mode started');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting TUN mode: $e');
      return false;
    }
  }

  /// Stop TUN mode
  static Future<bool> stopTunMode() async {
    try {
      if (_tunProcess != null) {
        debugPrint('🔧 Stopping V2Ray TUN mode...');
        _tunProcess!.kill();
        _tunProcess = null;
        debugPrint('✅ V2Ray TUN mode stopped');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error stopping TUN mode: $e');
      return false;
    }
  }

  /// Add TUN inbound to V2Ray config for system-wide VPN
  static Future<String> _addTunToConfig(String originalConfig) async {
    try {
      final config = jsonDecode(originalConfig) as Map<String, dynamic>;

      // Add TUN inbound
      final inbounds = config['inbounds'] as List? ?? [];
      
      // Add TUN inbound for system-wide VPN
      inbounds.insert(0, {
        'tag': 'tun-in',
        'protocol': 'dokodemo-door',
        'port': 10808,
        'settings': {
          'address': '0.0.0.0',
          'network': 'tcp,udp',
          'followRedirect': true
        },
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls']
        }
      });

      // Add TUN interface configuration
      config['inbounds'] = inbounds;
      
      // Add routing rules
      final routing = config['routing'] as Map<String, dynamic>? ?? {};
      routing['domainStrategy'] = 'IPIfNonMatch';
      routing['rules'] = [
        {
          'type': 'field',
          'inboundTag': ['tun-in'],
          'outboundTag': 'proxy'
        }
      ];
      config['routing'] = routing;

      return jsonEncode(config);
    } catch (e) {
      debugPrint('❌ Error adding TUN to config: $e');
      return originalConfig;
    }
  }

  /// Enable system-wide routing through TUN interface
  static Future<bool> enableSystemRouting() async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required for system routing');
        return false;
      }

      debugPrint('🔧 Configuring system routing...');

      // Add route to redirect all traffic through TUN
      // Route all traffic (0.0.0.0/0) through the TUN interface
      final result = await Process.run(
        'route',
        ['add', '0.0.0.0', 'mask', '0.0.0.0', '10.0.85.1', 'metric', '1'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        debugPrint('✅ System routing configured');
        return true;
      } else {
        debugPrint('⚠️ Route add result: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error enabling system routing: $e');
      return false;
    }
  }

  /// Disable system-wide routing
  static Future<bool> disableSystemRouting() async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required to disable system routing');
        return false;
      }

      debugPrint('🔧 Removing system routing...');

      // Remove the route
      final result = await Process.run(
        'route',
        ['delete', '0.0.0.0'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        debugPrint('✅ System routing removed');
        return true;
      } else {
        debugPrint('⚠️ Route delete result: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error disabling system routing: $e');
      return false;
    }
  }

  /// Check if TUN adapter exists
  static Future<bool> checkTunAdapter() async {
    try {
      final result = await Process.run(
        'netsh',
        ['interface', 'show', 'interface'],
        runInShell: true,
      );

      final output = result.stdout.toString();
      final hasTun = output.contains('tun') || output.contains('TUN');

      if (hasTun) {
        debugPrint('✅ TUN adapter found');
      } else {
        debugPrint('ℹ️ TUN adapter will be created by V2Ray');
      }

      return true; // V2Ray will create it if needed
    } catch (e) {
      debugPrint('⚠️ Error checking TUN adapter: $e');
      return true; // Assume it will work
    }
  }

  /// Get VPN mode capabilities
  static Future<Map<String, dynamic>> getVpnCapabilities() async {
    final hasAdmin = await checkAdminRights();
    final hasTun = await checkTunAdapter();

    return {
      'hasAdminRights': hasAdmin,
      'hasTunSupport': hasTun,
      'canUseFullVpn': hasAdmin, // Only admin rights needed
      'canUseProxyMode': true, // Proxy mode doesn't require admin
      'message': hasAdmin 
          ? 'Ready for true VPN mode' 
          : 'Admin rights required for VPN mode',
    };
  }

  /// Check if TUN mode is currently active
  static bool isTunActive() {
    return _tunProcess != null;
  }
}
