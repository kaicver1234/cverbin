import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/v2ray_config.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

class ServerService {
  // Default GitHub URL for server configurations
  static const String defaultServerUrl =
      'https://raw.githubusercontent.com/cverhud/v2ray-sub/refs/heads/main/sub.txt';

  Future<List<V2RayConfig>> fetchServers({required String customUrl}) async {
    try {
      final url = customUrl;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        final List<V2RayConfig> servers = [];

        // Split the response by lines and process each line
        final lines = responseBody.split('\n');

        // Fetched lines from server

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          // Processing line

          try {
            // Try to parse as JSON first
            if (line.startsWith('{') && line.endsWith('}')) {
              final serverJson = jsonDecode(line);
              final config = _parseJsonConfig(serverJson);
              if (config != null) {
                servers.add(config);
                // Added JSON config
              }
            }
            // If not JSON, try to parse as a V2Ray URI (vmess://, vless://, etc.)
            else if (line.contains('://')) {
              final config = _parseUriConfig(line);
              if (config != null) {
                servers.add(config);
                // Added URI config
              } else {
                // Failed to parse URI
              }
            } else {
              // Line is not JSON or URI format
            }
          } catch (e) {
            // Error parsing server line
          }
        }

        // Successfully parsed servers
        return servers;
      } else {
        throw Exception('Failed to load servers: ${response.statusCode}');
      }
    } catch (e) {
      // Error fetching servers
      return [];
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
  V2RayConfig? _parseUriConfig(String uri) {
    try {
      // Parsing URI

      // Use FlutterV2ray to parse the URL
      if (uri.startsWith('vmess://') ||
          uri.startsWith('vless://') ||
          uri.startsWith('ss://')) {
        try {
          V2RayURL parser = FlutterV2ray.parseFromURL(uri);
          String configType = '';

          if (uri.startsWith('vmess://')) {
            configType = 'vmess';
          } else if (uri.startsWith('vless://')) {
            configType = 'vless';
          } else if (uri.startsWith('ss://')) {
            configType = 'shadowsocks';
          }

          // Use the parsed address and port from the V2RayURL parser
          String address = parser.address;
          int port = parser.port;

          // Parsed URI with FlutterV2ray

          return V2RayConfig(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            remark: parser.remark,
            address: address,
            port: port,
            configType: configType,
            fullConfig: uri,
          );
        } catch (e) {
          // Error parsing with FlutterV2ray
          return null;
        }
      }

      return null;
    } catch (e) {
      // Error parsing URI config
      return null;
    }
  }
}
