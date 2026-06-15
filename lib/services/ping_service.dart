import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PingResult {
  final bool success;
  final int latency;
  final String method;
  final String? error;
  final int timestamp;

  const PingResult({
    required this.success,
    required this.latency,
    required this.method,
    this.error,
    required this.timestamp,
  });

  factory PingResult.fromMap(Map<String, dynamic> map) {
    return PingResult(
      success: map['success'] ?? false,
      latency: (map['latency'] ?? -1) as int,
      method: map['method'] ?? 'unknown',
      error: map['error'],
      timestamp: (map['timestamp'] ?? 0) as int,
    );
  }

  factory PingResult.error(String errorMessage) {
    return PingResult(
      success: false,
      latency: -1,
      method: 'error',
      error: errorMessage,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'PingResult(success: $success, latency: ${latency}ms, method: $method)';
    } else {
      return 'PingResult(success: $success, error: $error, method: $method)';
    }
  }
}

class NativePingService {
  static const MethodChannel _channel = MethodChannel('com.tiksarvpn.app/ping');

  // Cache for ping results
  static final Map<String, PingResult> _pingCache = {};
  static final Map<String, bool> _pingInProgress = {};

  // Stream controllers for continuous ping
  static final Map<String, StreamController<PingResult>>
  _continuousPingControllers = {};

  /// Stop continuous ping
  static Future<void> stopContinuousPing(String pingId) async {
    try {
      await _channel.invokeMethod('stopContinuousPing', {'pingId': pingId});

      // Close and remove stream controller
      final controller = _continuousPingControllers[pingId];
      if (controller != null) {
        await controller.close();
        _continuousPingControllers.remove(pingId);
      }
    } catch (e) {
      debugPrint('Error stopping continuous ping: $e');
    }
  }

  /// Stop all continuous pings
  static Future<void> stopAllContinuousPings() async {
    final List<String> pingIds = List.from(_continuousPingControllers.keys);

    for (final pingId in pingIds) {
      await stopContinuousPing(pingId);
    }
  }

  /// Clear ping cache
  static void clearCache({String? host, int? port}) {
    if (host != null && port != null) {
      _pingCache.remove('$host:$port');
    } else {
      _pingCache.clear();
    }
  }

  /// Cleanup resources
  static Future<void> cleanup() async {
    try {
      await stopAllContinuousPings();
      await _channel.invokeMethod('cleanup');
      _pingCache.clear();
      _pingInProgress.clear();
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }
}
