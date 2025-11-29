import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Cloudflare Speed Test Provider
/// Based on speed.cloudflare.com API
class SpeedTestProvider with ChangeNotifier {
  final Dio _dio = Dio();
  
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;
  
  bool _isTestCanceled = false;
  String _measurementId = '';
  
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];

  // Cloudflare test configuration
  static const String _baseUrl = 'https://speed.cloudflare.com';
  static const int _latencyPackets = 20;
  
  // Download test sizes (progressive)
  static const List<int> _downloadSizes = [
    100000,    // 100KB warmup
    1000000,   // 1MB
    10000000,  // 10MB
    25000000,  // 25MB
  ];
  
  // Upload test sizes (progressive)
  static const List<int> _uploadSizes = [
    100000,    // 100KB warmup
    1000000,   // 1MB
    5000000,   // 5MB
  ];

  SpeedTestProvider() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _dio.options.headers['User-Agent'] = 'Tiksar VPN Speed Test';
  }

  @override
  void dispose() {
    stopTest();
    _dio.close();
    super.dispose();
  }

  void stopTest() {
    _isTestCanceled = true;
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();
    _state = const SpeedTestState();
    notifyListeners();
    debugPrint('🛑 Speed test stopped');
  }

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready && !_isTestCanceled) {
      stopTest();
      return;
    }

    _isTestCanceled = false;
    _measurementId = _generateMeasurementId();
    debugPrint('🚀 Speed Test Started - ID: $_measurementId');

    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      result: const SpeedTestResult(),
      currentPhase: 'Initializing...',
      currentSpeed: 0.0,
      errorMessage: null,
      isConnectionStable: true,
      hadError: false,
      testCompleted: false,
    );
    notifyListeners();

    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();

    try {
      // Phase 1: Latency Test
      await _runLatencyTest();
      if (_isTestCanceled) return;

      // Phase 2: Download Test
      await _runDownloadTest();
      if (_isTestCanceled) return;

      // Phase 3: Upload Test
      await _runUploadTest();
      if (_isTestCanceled) return;

      // Calculate final results
      _calculateFinalResults();
      debugPrint('🏁 Speed test completed');
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      _state = _state.copyWith(
        errorMessage: 'Speed test failed. Please try again.',
        step: SpeedTestStep.ready,
        isConnectionStable: false,
        currentSpeed: 0.0,
        hadError: true,
      );
      notifyListeners();
    }
  }

  String _generateMeasurementId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Phase 1: Latency Test
  Future<void> _runLatencyTest() async {
    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      currentPhase: 'Measuring latency...',
      progress: 0.0,
    );
    notifyListeners();

    for (int i = 0; i < _latencyPackets; i++) {
      if (_isTestCanceled) return;

      try {
        final latency = await _measureLatency();
        _latencies.add(latency);

        // Update UI with current latency
        final avgLatency = _latencies.reduce((a, b) => a + b) ~/ _latencies.length;
        final jitter = _calculateJitter();

        _state = _state.copyWith(
          progress: (i + 1) / _latencyPackets,
          result: _state.result.copyWith(
            ping: latency,
            latency: avgLatency,
            jitter: jitter,
          ),
        );
        notifyListeners();

        debugPrint('📡 Latency ${i + 1}/$_latencyPackets: ${latency}ms');
      } catch (e) {
        debugPrint('❌ Latency packet ${i + 1} failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_latencies.isEmpty) {
      throw Exception('Failed to measure latency');
    }
  }

  Future<int> _measureLatency() async {
    final startTime = DateTime.now();
    await _dio.get('/__down', queryParameters: {
      'bytes': 0,
      'measId': _measurementId,
    });
    return DateTime.now().difference(startTime).inMilliseconds;
  }

  /// Phase 2: Download Test
  Future<void> _runDownloadTest() async {
    _state = _state.copyWith(
      step: SpeedTestStep.download,
      currentPhase: 'Testing download...',
      progress: 0.0,
      currentSpeed: 0.0,
    );
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < _downloadSizes.length; i++) {
      if (_isTestCanceled) return;

      final bytes = _downloadSizes[i];
      final sizeLabel = _formatBytes(bytes);

      _state = _state.copyWith(
        currentPhase: 'Download: $sizeLabel',
        progress: i / _downloadSizes.length,
      );
      notifyListeners();

      try {
        final speed = await _measureDownload(bytes);
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          
          final avgSpeed = _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;
          final p90Speed = _calculatePercentile(_downloadSpeeds, 0.9);

          _state = _state.copyWith(
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(downloadSpeed: p90Speed),
          );
          notifyListeners();

          debugPrint('📥 Download $sizeLabel: ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        debugPrint('❌ Download $sizeLabel failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<double> _measureDownload(int bytes) async {
    final startTime = DateTime.now();
    int receivedBytes = 0;

    final response = await _dio.get<List<int>>(
      '/__down',
      queryParameters: {
        'bytes': bytes,
        'measId': _measurementId,
      },
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        receivedBytes = received;
        final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        if (elapsed > 0.1 && !_isTestCanceled) {
          final speedMbps = (received * 8) / elapsed / 1000000;
          _state = _state.copyWith(currentSpeed: _roundSpeed(speedMbps));
          notifyListeners();
        }
      },
    );

    final duration = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (duration < 0.01) return 0.0;

    final actualBytes = response.data?.length ?? receivedBytes;
    return (actualBytes * 8) / duration / 1000000;
  }

  /// Phase 3: Upload Test
  Future<void> _runUploadTest() async {
    _state = _state.copyWith(
      step: SpeedTestStep.upload,
      currentPhase: 'Testing upload...',
      progress: 0.0,
      currentSpeed: 0.0,
    );
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < _uploadSizes.length; i++) {
      if (_isTestCanceled) return;

      final bytes = _uploadSizes[i];
      final sizeLabel = _formatBytes(bytes);

      _state = _state.copyWith(
        currentPhase: 'Upload: $sizeLabel',
        progress: i / _uploadSizes.length,
      );
      notifyListeners();

      try {
        final speed = await _measureUpload(bytes);
        if (speed > 0) {
          _uploadSpeeds.add(speed);
          
          final avgSpeed = _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;
          final p90Speed = _calculatePercentile(_uploadSpeeds, 0.9);

          _state = _state.copyWith(
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(uploadSpeed: p90Speed),
          );
          notifyListeners();

          debugPrint('📤 Upload $sizeLabel: ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        debugPrint('❌ Upload $sizeLabel failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<double> _measureUpload(int bytes) async {
    // Generate random data
    final random = Random();
    final data = Uint8List.fromList(
      List<int>.generate(bytes, (_) => random.nextInt(256)),
    );

    final startTime = DateTime.now();

    await _dio.post(
      '/__up',
      data: data,
      queryParameters: {'measId': _measurementId},
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': bytes,
        },
      ),
      onSendProgress: (sent, total) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        if (elapsed > 0.1 && !_isTestCanceled) {
          final speedMbps = (sent * 8) / elapsed / 1000000;
          _state = _state.copyWith(currentSpeed: _roundSpeed(speedMbps));
          notifyListeners();
        }
      },
    );

    final duration = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (duration < 0.01) return 0.0;

    return (bytes * 8) / duration / 1000000;
  }

  void _calculateFinalResults() {
    final downloadSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
    final uploadSpeed = _calculatePercentile(_uploadSpeeds, 0.9);
    final ping = _latencies.isNotEmpty ? _latencies.reduce(min) : 0;
    final latency = _latencies.isNotEmpty 
        ? _latencies.reduce((a, b) => a + b) ~/ _latencies.length 
        : 0;
    final jitter = _calculateJitter();

    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      result: SpeedTestResult(
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        ping: ping,
        latency: latency,
        jitter: jitter,
        packetLoss: 0.0,
      ),
      progress: 1.0,
      currentPhase: 'Test completed',
      testCompleted: true,
      hadError: false,
    );
    notifyListeners();

    debugPrint('📊 Results: ↓${downloadSpeed.toStringAsFixed(1)} ↑${uploadSpeed.toStringAsFixed(1)} Mbps, ${ping}ms');
  }

  int _calculateJitter() {
    if (_latencies.length < 2) return 0;
    int sum = 0;
    for (int i = 1; i < _latencies.length; i++) {
      sum += (_latencies[i] - _latencies[i - 1]).abs();
    }
    return sum ~/ (_latencies.length - 1);
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = ((percentile * (sorted.length - 1)).round()).clamp(0, sorted.length - 1);
    return sorted[index];
  }

  String _formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).round()}KB';
    if (bytes < 1000000000) return '${(bytes / 1000000).round()}MB';
    return '${(bytes / 1000000000).round()}GB';
  }

  double _roundSpeed(double speed) {
    if (speed < 10) return (speed * 10).round() / 10;
    if (speed < 100) return (speed * 4).round() / 4;
    return speed.round().toDouble();
  }

  void resetTest() => stopTest();

  void retryConnection() {
    stopTest();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isTestCanceled) startTest();
    });
  }
}
