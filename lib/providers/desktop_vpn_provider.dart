import 'package:flutter/foundation.dart';

class DesktopVpnProvider with ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _selectedServer;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  String _duration = '00:00:00';
  
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get selectedServer => _selectedServer;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  String get duration => _duration;
  
  void selectServer(String server) {
    _selectedServer = server;
    notifyListeners();
    debugPrint('📡 Server selected: $server');
  }
  
  Future<void> connect() async {
    if (_selectedServer == null) {
      debugPrint('⚠️ No server selected');
      return;
    }
    
    _isConnecting = true;
    notifyListeners();
    debugPrint('🔄 Connecting to $_selectedServer...');
    
    await Future.delayed(const Duration(seconds: 2));
    
    _isConnected = true;
    _isConnecting = false;
    notifyListeners();
    debugPrint('✅ Connected to $_selectedServer');
  }
  
  Future<void> disconnect() async {
    _isConnecting = true;
    notifyListeners();
    debugPrint('🔄 Disconnecting...');
    
    await Future.delayed(const Duration(seconds: 1));
    
    _isConnected = false;
    _isConnecting = false;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _duration = '00:00:00';
    notifyListeners();
    debugPrint('✅ Disconnected');
  }
  
  void updateStats(int upload, int download, String duration) {
    _uploadSpeed = upload;
    _downloadSpeed = download;
    _duration = duration;
    notifyListeners();
  }
}
