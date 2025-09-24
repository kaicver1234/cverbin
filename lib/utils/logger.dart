import 'package:flutter/foundation.dart';

/// A centralized logger for the application that only logs in debug mode
class Logger {
  static const bool _enableLogging = kDebugMode;
  
  /// Log an error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_enableLogging && kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Error details: $error');
      }
      if (stackTrace != null && kDebugMode) {
        debugPrint('   Stack trace: $stackTrace');
      }
    }
  }
  
  /// Log a warning message
  static void warning(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }
  
  /// Log an info message
  static void info(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }
  
  /// Log a debug message (only in debug builds)
  static void debug(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('🐛 DEBUG: $message');
    }
  }
  
  /// Log a success message
  static void success(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
  }
  
  /// Log network-related messages
  static void network(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('🌐 NETWORK: $message');
    }
  }
  
  /// Log VPN connection-related messages
  static void vpn(String message) {
    if (_enableLogging && kDebugMode) {
      debugPrint('🔐 VPN: $message');
    }
  }
}
