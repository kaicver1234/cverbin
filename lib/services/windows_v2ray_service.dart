import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';

class WindowsV2rayService {
  static Process? _v2rayProcess;
  static bool _isRunning = false;
  static String? _configPath;
  static Timer? _statsTimer;
  static int _uploadSpeed = 0;
  static int _downloadSpeed = 0;
  static int _totalUpload = 0;
  static int _totalDownload = 0;

  static bool get isRunning => _isRunning;
  static int get uploadSpeed => _uploadSpeed;
  static int get downloadSpeed => _downloadSpeed;
  static int get totalUpload => _totalUpload;
  static int get totalDownload => _totalDownload;

  static Future<String> _getV2rayCoreDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final v2rayDir = Directory('${appDocDir.path}\\TiksarVPN\\v2ray-core');
    if (!await v2rayDir.exists()) {
      await v2rayDir.create(recursive: true);
    }
    return v2rayDir.path;
  }

  static Future<bool> _copyFromAssets() async {
    try {
      final v2rayDir = await _getV2rayCoreDirectory();
      
      debugPrint('📦 Copying V2Ray core from assets...');
      
      // List of required files
      final files = ['v2ray.exe', 'geoip.dat', 'geosite.dat'];
      
      for (final fileName in files) {
        try {
          // Try to load from assets
          final assetPath = 'assets/v2ray-core/$fileName';
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();
          
          // Write to destination
          final destFile = File('$v2rayDir\\$fileName');
          await destFile.writeAsBytes(bytes);
          
          debugPrint('✅ Copied $fileName from assets');
        } catch (e) {
          debugPrint('⚠️ Could not copy $fileName from assets: $e');
          return false;
        }
      }
      
      debugPrint('✅ All V2Ray core files copied from assets');
      return true;
    } catch (e) {
      debugPrint('❌ Error copying from assets: $e');
      return false;
    }
  }

  static Future<bool> downloadV2rayCore() async {
    try {
      final v2rayDir = await _getV2rayCoreDirectory();
      final v2rayExePath = '$v2rayDir\\v2ray.exe';
      
      final v2rayFile = File(v2rayExePath);
      if (await v2rayFile.exists()) {
        debugPrint('✅ V2Ray core already exists');
        return true;
      }

      // First try to copy from assets
      debugPrint('🔍 Checking assets for V2Ray core...');
      final copiedFromAssets = await _copyFromAssets();
      if (copiedFromAssets) {
        return true;
      }

      // If assets don't exist, download from internet
      debugPrint('📥 Downloading V2Ray core from internet...');
      
      const v2rayUrl = 'https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-windows-64.zip';
      
      final response = await http.get(Uri.parse(v2rayUrl));
      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download V2Ray core: ${response.statusCode}');
        return false;
      }

      final zipFile = File('$v2rayDir\\v2ray.zip');
      await zipFile.writeAsBytes(response.bodyBytes);
      
      debugPrint('📦 Extracting V2Ray core...');
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$v2rayDir" -Force'
        ],
      );

      if (result.exitCode != 0) {
        debugPrint('❌ Failed to extract V2Ray core: ${result.stderr}');
        return false;
      }

      await zipFile.delete();
      
      debugPrint('✅ V2Ray core downloaded and extracted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error downloading V2Ray core: $e');
      return false;
    }
  }

  static Future<bool> startV2ray(String v2rayConfig) async {
    try {
      if (_isRunning) {
        await stopV2ray();
      }

      await downloadV2rayCore();

      final v2rayDir = await _getV2rayCoreDirectory();
      final v2rayExePath = '$v2rayDir\\v2ray.exe';
      final configDir = Directory('${v2rayDir}\\configs');
      
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      _configPath = '${configDir.path}\\config.json';
      
      final fullConfig = _buildFullV2rayConfig(v2rayConfig);
      await File(_configPath!).writeAsString(jsonEncode(fullConfig));

      debugPrint('🚀 Starting V2Ray core...');
      debugPrint('📄 Config path: $_configPath');
      
      _v2rayProcess = await Process.start(
        v2rayExePath,
        ['-config', _configPath!],
        workingDirectory: v2rayDir,
      );

      _v2rayProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('V2Ray stdout: $data');
      });

      _v2rayProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('V2Ray stderr: $data');
      });

      await Future.delayed(const Duration(seconds: 2));

      _isRunning = true;
      _startStatsMonitoring();
      
      debugPrint('✅ V2Ray started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting V2Ray: $e');
      return false;
    }
  }

  static Map<String, dynamic> _buildFullV2rayConfig(String baseConfig) {
    try {
      Map<String, dynamic> config;
      
      // Check if it's a URI format (vmess://, vless://, etc.)
      if (baseConfig.contains('://')) {
        debugPrint('📝 URI format detected, converting to V2Ray config');
        try {
          // Use flutter_v2ray to parse the URL and get full configuration
          final v2rayUrl = FlutterV2ray.parseFromURL(baseConfig);
          final fullConfigString = v2rayUrl.getFullConfiguration();
          config = jsonDecode(fullConfigString) as Map<String, dynamic>;
          
          debugPrint('✅ Successfully converted URI to config');
        } catch (e) {
          debugPrint('❌ Error parsing URI: $e');
          // Fallback to basic config
          config = {
            'log': {'loglevel': 'warning'},
            'inbounds': [],
            'outbounds': [],
            'routing': {'rules': []}
          };
        }
      } else {
        // Try to parse as JSON
        final decoded = jsonDecode(baseConfig);
        if (decoded is Map<String, dynamic>) {
          config = decoded;
        } else {
          throw Exception('Invalid config format');
        }
      }

      config['log'] = {
        'loglevel': 'warning',
      };

      config['api'] = {
        'tag': 'api',
        'services': ['StatsService']
      };

      config['stats'] = {};

      config['policy'] = {
        'levels': {
          '0': {
            'statsUserUplink': true,
            'statsUserDownlink': true
          }
        },
        'system': {
          'statsInboundUplink': true,
          'statsInboundDownlink': true,
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true
        }
      };

      final inbounds = config['inbounds'] as List? ?? [];
      
      final socks5Exists = inbounds.any((inbound) => 
        inbound['protocol'] == 'socks' || inbound['tag'] == 'socks'
      );

      if (!socks5Exists) {
        inbounds.add({
          'tag': 'socks',
          'port': 10808,
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true
          }
        });
      }

      final httpExists = inbounds.any((inbound) => 
        inbound['protocol'] == 'http' || inbound['tag'] == 'http'
      );

      if (!httpExists) {
        inbounds.add({
          'tag': 'http',
          'port': 10809,
          'protocol': 'http',
          'settings': {}
        });
      }

      inbounds.add({
        'listen': '127.0.0.1',
        'port': 10085,
        'protocol': 'dokodemo-door',
        'settings': {
          'address': '127.0.0.1'
        },
        'tag': 'api'
      });

      config['inbounds'] = inbounds;

      final routing = config['routing'] as Map<String, dynamic>? ?? {};
      final rules = routing['rules'] as List? ?? [];
      
      rules.insert(0, {
        'inboundTag': ['api'],
        'outboundTag': 'api',
        'type': 'field'
      });

      routing['rules'] = rules;
      config['routing'] = routing;

      return config;
    } catch (e) {
      debugPrint('❌ Error building config: $e');
      rethrow;
    }
  }

  static void _startStatsMonitoring() {
    _statsTimer?.cancel();
    _totalUpload = 0;
    _totalDownload = 0;
    
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final uploadDiff = await _queryStats('outbound>>>proxy>>>traffic>>>uplink');
        final downloadDiff = await _queryStats('outbound>>>proxy>>>traffic>>>downlink');

        _uploadSpeed = uploadDiff;
        _downloadSpeed = downloadDiff;
        _totalUpload += uploadDiff;
        _totalDownload += downloadDiff;
      } catch (e) {
        debugPrint('⚠️ Error querying stats: $e');
      }
    });
  }

  static Future<int> _queryStats(String statName) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:10085/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': 'QueryStats',
          'pattern': statName,
          'reset': true,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['stat'] != null && data['stat'].isNotEmpty) {
          return data['stat'][0]['value'] as int? ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> stopV2ray() async {
    try {
      debugPrint('🛑 Stopping V2Ray...');
      
      _statsTimer?.cancel();
      _statsTimer = null;
      
      _v2rayProcess?.kill();
      _v2rayProcess = null;
      
      _isRunning = false;
      _uploadSpeed = 0;
      _downloadSpeed = 0;
      _totalUpload = 0;
      _totalDownload = 0;
      
      debugPrint('✅ V2Ray stopped');
    } catch (e) {
      debugPrint('❌ Error stopping V2Ray: $e');
    }
  }

  static Future<void> dispose() async {
    await stopV2ray();
  }
}
