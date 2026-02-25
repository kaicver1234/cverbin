import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/v2ray_config.dart';
import '../utils/country_flags.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class ServerService {
  // Default server URL for server configurations
  static const String defaultServerUrl =
      'https://sub.tiksar.ir/tiksarserver.txt';

  Future<List<V2RayConfig>> fetchServers({required String customUrl}) async {
    try {
      final url = customUrl;
      
      debugPrint('🌐 Starting server fetch from: $url');
      debugPrint('🌐 Device: Making HTTP request...');
      
      // Add timeout for slow networks (especially important for J7 and older devices)
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 15), // Generous timeout for slow networks
        onTimeout: () {
          debugPrint('❌ HTTP request timeout after 15 seconds');
          throw Exception('Connection timeout - please check your internet');
        },
      );

      debugPrint('🌐 HTTP response received: ${response.statusCode}');
      debugPrint('🌐 Response body length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        
        // Check if response is empty
        if (responseBody.trim().isEmpty) {
          debugPrint('❌ Server returned empty response');
          throw Exception('Server returned empty response');
        }
        
        final List<V2RayConfig> servers = [];

        // Split the response by lines and process each line
        final lines = responseBody.split('\n');
        debugPrint('🌐 Processing ${lines.length} lines...');

        int successCount = 0;
        int failCount = 0;

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          try {
            // Extract country code if present: [CC] config
            String? countryCode;
            String configLine = line;
            
            // Try to extract country code from beginning: [CC] config (case insensitive)
            final countryCodeMatch = RegExp(r'^\[([A-Za-z]{2})\]\s*(.+)').firstMatch(line);
            if (countryCodeMatch != null) {
              countryCode = countryCodeMatch.group(1)!.toUpperCase();
              configLine = countryCodeMatch.group(2)!;
            }
            
            // Try to parse as JSON first
            if (configLine.startsWith('{') && configLine.endsWith('}')) {
              final serverJson = jsonDecode(configLine);
              final config = _parseJsonConfig(serverJson);
              if (config != null) {
                servers.add(config);
                successCount++;
              } else {
                failCount++;
              }
            }
            // If not JSON, try to parse as a V2Ray URI (vmess://, vless://, etc.)
            else if (configLine.contains('://')) {
              final config = _parseUriConfig(configLine, countryCode: countryCode);
              if (config != null) {
                servers.add(config);
                successCount++;
              } else {
                failCount++;
              }
            }
          } catch (e) {
            failCount++;
            debugPrint('⚠️ Error parsing line: $e');
          }
        }

        debugPrint('✅ Parsing complete: $successCount success, $failCount failed');

        // Successfully parsed servers
        if (servers.isEmpty) {
          debugPrint('❌ No valid servers found in response');
          throw Exception('No valid servers found in response');
        }
        
        debugPrint('✅ Returning ${servers.length} servers');
        return servers;
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        throw Exception('Server error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ fetchServers failed: $e');
      // Re-throw with more context for better error handling
      throw Exception('Failed to fetch servers: $e');
    }
  }

  // Parse a JSON configuration
  V2RayConfig? _parseJsonConfig(Map<String, dynamic> json) {
    try {
      return V2RayConfig(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        remark: json['remark'] ?? json['ps'] ?? 'Unknown Server',
        address: json['address'] ?? json['add'] ?? '',
        port:
            int.tryParse(json['port']?.toString() ?? '') ??
            int.tryParse(json['port']?.toString() ?? '') ??
            443,
        configType: json['type'] ?? json['net'] ?? 'vmess',
        fullConfig: jsonEncode(json),
      );
    } catch (e) {
      // Error parsing JSON config
      return null;
    }
  }

  // Parse a URI configuration (vmess://, vless://, etc.)
  V2RayConfig? _parseUriConfig(String uri, {String? countryCode}) {
    try {
      // Use FlutterV2ray to parse the URL
      if (uri.startsWith('vmess://') ||
          uri.startsWith('vless://') ||
          uri.startsWith('ss://') ||
          uri.startsWith('trojan://')) {
        try {
          V2RayURL parser = V2ray.parseFromURL(uri);
          String configType = '';

          if (uri.startsWith('vmess://')) {
            configType = 'vmess';
          } else if (uri.startsWith('vless://')) {
            configType = 'vless';
          } else if (uri.startsWith('ss://')) {
            configType = 'shadowsocks';
          } else if (uri.startsWith('trojan://')) {
            configType = 'trojan';
          }

          // If no country code from line prefix, try to extract from remark
          if (countryCode == null && parser.remark.isNotEmpty) {
            countryCode = _extractCountryCodeFromRemark(parser.remark);
          }

          // Use the parsed address and port from the V2RayURL parser
          String address = parser.address;
          int port = parser.port;
          
          // Build remark with country code prefix if available
          String finalRemark = parser.remark;
          if (countryCode != null && !finalRemark.toUpperCase().contains('[$countryCode]')) {
            finalRemark = '[$countryCode] $finalRemark';
          }

          return V2RayConfig(
            id: '${DateTime.now().millisecondsSinceEpoch}_${address}_$port',
            remark: finalRemark,
            countryCode: countryCode,
            address: address,
            port: port,
            configType: configType,
            fullConfig: uri,
          );
        } catch (e) {
          // Error parsing with FlutterV2ray: $e
          return null;
        }
      }

      return null;
    } catch (e) {
      // Error parsing URI config: $e
      return null;
    }
  }

  // Extract country code from remark string
  String? _extractCountryCodeFromRemark(String remark) {
    return CountryFlags.extractCountryCode(remark);
  }
}
