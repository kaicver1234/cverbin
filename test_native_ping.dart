import 'package:flutter/material.dart';
import 'lib/services/ping_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('🧪 Testing Native Ping Service');
  debugPrint('=' * 50);
  
  // Initialize
  await NativePingService.initialize();
  debugPrint('✅ Service initialized');
  
  // Test 1: Ping google.com
  debugPrint('\n📍 Test 1: Ping google.com:80');
  try {
    final result = await NativePingService.pingMultipleHosts(
      hosts: [(host: 'google.com', port: 80)],
      timeoutMs: 5000,
      useIcmp: true,
      useTcp: true,
    );
    
    result.forEach((key, value) {
      debugPrint('Result for $key:');
      debugPrint('  Success: ${value.success}');
      debugPrint('  Latency: ${value.latency}ms');
      debugPrint('  Method: ${value.method}');
      if (!value.success) {
        debugPrint('  Error: ${value.error}');
      }
    });
  } catch (e) {
    debugPrint('❌ Error: $e');
  }
  
  debugPrint('\n${'=' * 50}');
  debugPrint('Test completed!');
}
