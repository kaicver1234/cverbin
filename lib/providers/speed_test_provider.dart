import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';
import '../services/cloudflare_speed_test_service.dart';

class SpeedTestProvider with ChangeNotifier {
  final CloudflareSpeedTestService _service = CloudflareSpeedTestService();
  
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;
  
  Timer? _connectionMonitorTimer;
  bool _isTestCanceled = false;
  
  final List<int> _livePings = [];
  List<int> get livePings => List.unmodifiable(_livePings);
  
  @override
  void dispose() {
    stopTest();
    _connectionMonitorTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
  
  void stopTest() {
    _isTestCanceled = true;
    _service.cancelTest();
    _stopConnectionMonitoring();
    
    _state = const SpeedTestState();
    notifyListeners();
    
    debugPrint('🛑 Speed test stopped and reset');
  }
  
  Future<void> startTest() async {
    if (_state.step == SpeedTestStep.testing) {
      stopTest();
      return;
    }
    
    _isTestCanceled = false;
    _livePings.clear();
    
    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      currentSpeed: 0.0,
      result: const SpeedTestResult(),
      errorMessage: null,
      clearError: true,
      hadError: false,
      isConnectionStable: true,
    );
    notifyListeners();
    
    _startConnectionMonitoring();
    
    debugPrint('🚀 Speed test started');
    
    try {
      await _service.startTest(
        onPhaseChange: _handlePhaseChange,
        onSpeedUpdate: _handleSpeedUpdate,
        onComplete: _handleComplete,
        onError: _handleError,
      );
    } catch (e) {
      _handleError('Test failed: $e');
    }
  }
  
  void _handlePhaseChange(TestPhase phase, double progress) {
    if (_isTestCanceled) return;
    
    _state = _state.copyWith(
      step: SpeedTestStep.testing,
      currentPhase: phase,
      progress: progress,
    );
    
    // Update ping results when loading phase completes
    if (phase == TestPhase.loading && progress == 1.0) {
      final latencies = _service.latencies;
      if (latencies.isNotEmpty) {
        _livePings.addAll(latencies);
        final avgPing = (latencies.reduce((a, b) => a + b) / latencies.length).round();
        _state = _state.copyWith(
          result: _state.result.copyWith(ping: avgPing),
        );
      }
    }
    
    notifyListeners();
  }
  
  void _handleSpeedUpdate(double speed) {
    if (_isTestCanceled) return;
    
    _state = _state.copyWith(currentSpeed: speed);
    
    // Update result based on current phase
    if (_state.currentPhase == TestPhase.download && speed > 0) {
      _state = _state.copyWith(
        result: _state.result.copyWith(downloadSpeed: speed),
      );
    } else if (_state.currentPhase == TestPhase.upload && speed > 0) {
      _state = _state.copyWith(
        result: _state.result.copyWith(uploadSpeed: speed),
      );
    }
    
    notifyListeners();
  }
  
  void _handleComplete(SpeedTestResult result) {
    if (_isTestCanceled) return;
    
    _stopConnectionMonitoring();
    
    _state = _state.copyWith(
      step: SpeedTestStep.completed,
      result: result,
      progress: 1.0,
      currentSpeed: 0.0,
    );
    
    notifyListeners();
    debugPrint('✅ Speed test completed: $result');
  }
  
  void _handleError(String error) {
    _stopConnectionMonitoring();
    
    _state = _state.copyWith(
      step: SpeedTestStep.error,
      errorMessage: error,
      hadError: true,
      isConnectionStable: false,
      currentSpeed: 0.0,
    );
    
    notifyListeners();
    debugPrint('❌ Speed test error: $error');
  }
  
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    
    // Check connection stability every 2 seconds
    _connectionMonitorTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        // Simple check: if we're testing but speed is 0 for too long, connection might be unstable
        if (_state.step == SpeedTestStep.testing && 
            _state.currentSpeed == 0.0 && 
            _state.progress > 0.1) {
          _state = _state.copyWith(isConnectionStable: false);
          notifyListeners();
        }
      },
    );
  }
  
  void _stopConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }
}
