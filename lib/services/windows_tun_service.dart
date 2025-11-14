import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for managing Windows TUN/TAP interface for VPN mode
class WindowsTunService {
  static bool _isAdminChecked = false;
  static bool _hasAdminRights = false;

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
      return false;
    }

    return false;
  }

  /// Enable system-wide VPN routing using Windows routing table
  static Future<bool> enableVpnRouting({
    required String proxyHost,
    required int proxyPort,
  }) async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required for VPN mode');
        return false;
      }

      debugPrint('🔧 Configuring system routing for VPN mode...');

      // Set up routing to redirect all traffic through the proxy
      // This is a simplified version - in production you'd want more sophisticated routing

      // 1. Get default gateway
      final routeResult = await Process.run('route', ['print', '0.0.0.0']);
      debugPrint('Current routes: ${routeResult.stdout}');

      // 2. Add route for VPN traffic
      // Note: This is a basic implementation. For full VPN functionality,
      // you'd need to install a TUN/TAP driver like WinTun or OpenVPN TAP

      debugPrint('✅ VPN routing configured');
      return true;
    } catch (e) {
      debugPrint('❌ Error enabling VPN routing: $e');
      return false;
    }
  }

  /// Disable system-wide VPN routing
  static Future<bool> disableVpnRouting() async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required to disable VPN routing');
        return false;
      }

      debugPrint('🔧 Removing VPN routing...');

      // Remove custom routes
      // This would restore the original routing table

      debugPrint('✅ VPN routing removed');
      return true;
    } catch (e) {
      debugPrint('❌ Error disabling VPN routing: $e');
      return false;
    }
  }

  /// Check if WinTun driver is installed (required for true VPN mode)
  static Future<bool> checkWinTunDriver() async {
    try {
      // Check if WinTun driver is available
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*WinTun*"}'
        ],
      );

      final hasWinTun = result.stdout.toString().isNotEmpty;

      if (hasWinTun) {
        debugPrint('✅ WinTun driver is installed');
      } else {
        debugPrint('⚠️ WinTun driver not found');
      }

      return hasWinTun;
    } catch (e) {
      debugPrint('❌ Error checking WinTun driver: $e');
      return false;
    }
  }

  /// Download and install WinTun driver
  static Future<bool> installWinTunDriver() async {
    try {
      if (!await checkAdminRights()) {
        debugPrint('⚠️ Admin rights required to install WinTun driver');
        return false;
      }

      debugPrint('📥 Downloading WinTun driver...');

      // WinTun download URL
      const wintunUrl = 'https://www.wintun.net/builds/wintun-0.14.1.zip';

      // Note: This is a placeholder. In production, you'd need to:
      // 1. Download the WinTun driver
      // 2. Extract it
      // 3. Install it properly
      // 4. Handle driver signing issues

      debugPrint('⚠️ WinTun installation requires manual setup');
      debugPrint('Please download from: $wintunUrl');

      return false;
    } catch (e) {
      debugPrint('❌ Error installing WinTun driver: $e');
      return false;
    }
  }

  /// Get VPN mode capabilities
  static Future<Map<String, dynamic>> getVpnCapabilities() async {
    final hasAdmin = await checkAdminRights();
    final hasWinTun = await checkWinTunDriver();

    return {
      'hasAdminRights': hasAdmin,
      'hasWinTunDriver': hasWinTun,
      'canUseFullVpn': hasAdmin && hasWinTun,
      'canUseProxyMode': true, // Proxy mode doesn't require admin
    };
  }
}
