import 'package:flutter/foundation.dart';
import '../models/v2ray_config.dart';
import '../models/connection_mode.dart';

class DesktopVpnProvider with ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  V2RayConfig? _selectedServerConfig;
  ConnectionMode _connectionMode = ConnectionMode.vpn;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  String _duration = '00:00:00';
  
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  V2RayConfig? get selectedServerConfig => _selectedServerConfig;
  ConnectionMode get connectionMode => _connectionMode;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  String get duration => _duration;
  
  void selectServerConfig(V2RayConfig config) {
    if (_isConnected) {
      debugPrint('⚠️ Cannot change server while connected');
      return;
    }
    _selectedServerConfig = config;
    notifyListeners();
    debugPrint('📡 Server selected: ${config.remark}');
  }
  
  void setConnectionMode(ConnectionMode mode) {
    if (_isConnected) {
      debugPrint('⚠️ Cannot change mode while connected');
      return;
    }
    _connectionMode = mode;
    notifyListeners();
    debugPrint('🔄 Connection mode changed to: $mode');
  }
  
  void setConnecting(bool value) {
    _isConnecting = value;
    notifyListeners();
  }
  
  Future<void> connect() async {
    if (_selectedServerConfig == null) {
      debugPrint('⚠️ No server selected');
      return;
    }
    
    _isConnected = true;
    _isConnecting = false;
    notifyListeners();
    debugPrint('✅ Connected to ${_selectedServerConfig!.remark}');
  }
  
  Future<void> disconnect() async {
    _isConnected = false;
    _isConnecting = false;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _duration = '00:00:00';
    notifyListeners();
    debugPrint('✅ Disconnected');
  }
  
  void updateStats(int upload, int download, String duration) {
    if (_isConnected) {
      _uploadSpeed = upload;
      _downloadSpeed = download;
      _duration = duration;
      notifyListeners();
    }
  }
}
