import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  bool _isCanceled = false;
  CancelToken? _cancelToken;
  late Dio _dio;

  final List<int> _latencies = [];
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];

  static const String _baseUrl = 'https://speed.cloudflare.com';
  static const String _downloadUrl = '$_baseUrl/__down';
  static const String _uploadUrl = '$_baseUrl/__up';

  // Measurement configuration like defyxVPN
  static const List<Map<String, dynamic>> _measurements = [
    {'type': 'latency', 'numPackets': 1},
    {'type': 'download', 'bytes': 100000, 'count': 1},
    {'type': 'latency', 'numPackets': 20},
    {'type': 'download', 'bytes': 100000, 'count': 9},
    {'type': 'download', 'bytes': 1000000, 'count': 8},
    {'type': 'upload', 'bytes': 100000, 'count': 8},
    {'type': 'upload', 'bytes': 1000000, 'count': 6},
    {'type': 'download', 'bytes': 10000000, 'count': 6},
  ];

  String _measurementId = '';

  SpeedTestProvider() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {'User-Agent': 'Tiksar VPN Speed Test'},
    ));
  }

  String _generateMeasurementId() {
    return (Random().nextDouble() * 1e16).round().toString();
  }

  void stopTest() {
    _isCanceled = true;
    _cancelToken?.cancel('User canceled');
    _cancelToken = null;
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _state = const SpeedTestState();
    notifyListeners();
    debugPrint('🛑 Speed test stopped and reset');
  }

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready) {
      stopTest();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isCanceled = false;
    _cancelToken = CancelToken();
    _measurementId = _generateMeasurementId();
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();

    _state = const SpeedTestState(
      step: SpeedTestStep.loading,
      currentPhase: 'Initializing...',
    );
    notifyListeners();

    debugPrint('🚀 Cloudflare Speed Test Started');

    try {
      await _runMeasurementSequence();

      if (_isCanceled) {
        debugPrint('🛑 Speed test was canceled');
        return;
      }

      _calculateFinalResults();
      debugPrint('🏁 Speed test completed successfully');
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      if (!_isCanceled) {
        _state = _state.copyWith(
          step: SpeedTestStep.ready,
          errorMessage: 'test_failed',
          hadError: true,
          currentSpeed: 0,
        );
        notifyListeners();
      }
    }
  }

  Future<void> _runMeasurementSequence() async {
    String currentPhase = '';
    int totalMeasurements = _measurements.length;

    for (int i = 0; i < totalMeasurements; i++) {
      if (_isCanceled) {
        debugPrint('🛑 Measurement sequence canceled');
        return;
      }

      final measurement = _measurements[i];
      final progress = (i + 1) / totalMeasurements;
      final type = measurement['type'] as String;

      bool needsPhaseChange = false;
      SpeedTestStep? nextStep;

      if (type == 'latency' && currentPhase != 'loading') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.loading;
        currentPhase = 'loading';
      } else if (type == 'download' && currentPhase != 'download') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.download;
        currentPhase = 'download';
      } else if (type == 'upload' && currentPhase != 'upload') {
        needsPhaseChange = true;
        nextStep = SpeedTestStep.upload;
        currentPhase = 'upload';
      }

      // Reset progress when changing phase
      if (needsPhaseChange && i > 0 && _state.progress > 0) {
        _state = _state.copyWith(progress: 0.0);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_isCanceled) return;
      }

      if (needsPhaseChange && nextStep != null) {
        _state = _state.copyWith(step: nextStep);
        notifyListeners();
      }

      debugPrint('📊 Running measurement ${i + 1}/$totalMeasurements: $type');

      switch (type) {
        case 'latency':
          await _runLatencyMeasurement(measurement);
          break;
        case 'download':
          await _runDownloadMeasurement(measurement, progress);
          break;
        case 'upload':
          await _runUploadMeasurement(measurement, progress);
          break;
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _runLatencyMeasurement(Map<String, dynamic> config) async {
    final numPackets = config['numPackets'] as int;
    int consecutiveFailures = 0;

    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      currentPhase: 'Measuring latency... ($numPackets packets)',
    );
    notifyListeners();

    for (int i = 0; i < numPackets; i++) {
      if (_isCanceled) return;

      try {
        final sw = Stopwatch()..start();
        await _dio.get(
          '$_downloadUrl?bytes=0&measId=$_measurementId',
          cancelToken: _cancelToken,
        );
        sw.stop();

        final latency = sw.elapsedMilliseconds;
        if (latency > 0 && latency < 5000) {
          _latencies.add(latency);
          consecutiveFailures = 0;

          final avgLatency = _latencies.isNotEmpty
              ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
              : 0;

          int jitter = 0;
          if (_latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < _latencies.length; j++) {
              jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (_latencies.length - 1)).round();
          }

          _state = _state.copyWith(
            result: _state.result.copyWith(
              ping: latency,
              latency: avgLatency,
              jitter: jitter,
            ),
          );
          notifyListeners();

          debugPrint('   📡 Latency ${i + 1}/$numPackets: ${latency}ms');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Latency measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= 3) {
          throw Exception('Network connection failed');
        }
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (_latencies.isEmpty) {
      throw Exception('Failed to measure latency');
    }
  }

  Future<void> _runDownloadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = _formatBytes(bytes);
    int consecutiveFailures = 0;

    _state = _state.copyWith(
      step: SpeedTestStep.download,
      currentPhase: 'Download test: $sizeLabel',
      progress: progress,
    );
    notifyListeners();

    for (int i = 0; i < count; i++) {
      if (_isCanceled) return;

      try {
        final speed = await _measureDownloadSpeed(bytes);
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          consecutiveFailures = 0;

          final percentileSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
          final avgSpeed = _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;

          _state = _state.copyWith(
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(
              downloadSpeed: percentileSpeed,
              ping: _latencies.isNotEmpty ? _latencies.last : 0,
            ),
          );
          notifyListeners();

          debugPrint('   📥 Download ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Download measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= 3) {
          throw Exception('Network connection lost during download test');
        }
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<double> _measureDownloadSpeed(int bytes) async {
    if (_isCanceled) return 0.0;

    final sw = Stopwatch()..start();
    DateTime? lastUpdateTime;
    final List<double> realtimeSpeeds = [];

    try {
      final response = await _dio.get<List<int>>(
        '$_downloadUrl?bytes=$bytes&measId=$_measurementId&during=download',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Cache-Control': 'no-cache, no-store'},
        ),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (_isCanceled) return;

          final now = DateTime.now();
          final elapsed = sw.elapsedMilliseconds / 1000.0;

          if (elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedMbps = (received * 8) / elapsed / 1000000;
            realtimeSpeeds.add(currentSpeedMbps);
            
            // Use smoothed average instead of raw speed
            final smoothedSpeed = realtimeSpeeds.length > 3
                ? realtimeSpeeds.sublist(realtimeSpeeds.length - 3).reduce((a, b) => a + b) / 3
                : currentSpeedMbps;
            final roundedSpeed = _roundSpeed(smoothedSpeed);
            _state = _state.copyWith(currentSpeed: roundedSpeed);
            notifyListeners();
            lastUpdateTime = now;
          }
        },
      );

      if (_isCanceled) return 0.0;

      sw.stop();
      final durationSeconds = sw.elapsedMilliseconds / 1000.0;
      if (durationSeconds < 0.01) return 0.0;

      final actualBytes = response.data?.length ?? 0;
      return (actualBytes * 8) / durationSeconds / 1000000;
    } catch (e) {
      debugPrint('   ❌ Download measurement error: $e');
      throw Exception('Download failed: $e');
    }
  }

  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = _formatBytes(bytes);
    int consecutiveFailures = 0;

    _state = _state.copyWith(
      step: SpeedTestStep.upload,
      currentPhase: 'Upload test: $sizeLabel',
      progress: progress,
    );
    notifyListeners();

    for (int i = 0; i < count; i++) {
      if (_isCanceled) return;

      try {
        final speed = await _measureUploadSpeed(bytes);
        if (speed > 0) {
          _uploadSpeeds.add(speed);
          consecutiveFailures = 0;

          final percentileSpeed = _calculatePercentile(_uploadSpeeds, 0.9);
          final avgSpeed = _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;

          int jitter = 0;
          if (_latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < _latencies.length; j++) {
              jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (_latencies.length - 1)).round();
          }

          _state = _state.copyWith(
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(
              uploadSpeed: percentileSpeed,
              jitter: jitter,
            ),
          );
          notifyListeners();

          debugPrint('   📤 Upload ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Upload measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= 3) {
          throw Exception('Network connection lost during upload test');
        }
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<double> _measureUploadSpeed(int bytes) async {
    if (_isCanceled) return 0.0;

    final data = Uint8List(bytes);
    final random = Random();
    for (int i = 0; i < min(2048, bytes); i++) {
      data[i] = random.nextInt(256);
    }

    final sw = Stopwatch()..start();
    DateTime? lastUpdateTime;
    final List<double> realtimeSpeeds = [];

    try {
      await _dio.post(
        '$_uploadUrl?measId=$_measurementId&during=upload',
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/octet-stream'},
        ),
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (_isCanceled) return;

          final now = DateTime.now();
          final elapsed = sw.elapsedMilliseconds / 1000.0;

          if (elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedMbps = (sent * 8) / elapsed / 1000000;
            realtimeSpeeds.add(currentSpeedMbps);
            
            // Use smoothed average instead of raw speed
            final smoothedSpeed = realtimeSpeeds.length > 3
                ? realtimeSpeeds.sublist(realtimeSpeeds.length - 3).reduce((a, b) => a + b) / 3
                : currentSpeedMbps;
            final roundedSpeed = _roundSpeed(smoothedSpeed);
            _state = _state.copyWith(currentSpeed: roundedSpeed);
            notifyListeners();
            lastUpdateTime = now;
          }
        },
      );

      if (_isCanceled) return 0.0;

      sw.stop();
      final durationSeconds = sw.elapsedMilliseconds / 1000.0;
      if (durationSeconds < 0.05) return 0.0;

      return (bytes * 8) / durationSeconds / 1000000;
    } catch (e) {
      debugPrint('   ❌ Upload measurement error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  void _calculateFinalResults() {
    final downloadSpeed = _downloadSpeeds.isEmpty
        ? 0.0
        : _calculatePercentile(_downloadSpeeds, 0.9);
    final uploadSpeed = _uploadSpeeds.isEmpty
        ? 0.0
        : _calculatePercentile(_uploadSpeeds, 0.9);
    final ping = _latencies.isEmpty ? 0 : _latencies.reduce(min);
    final latency = _latencies.isEmpty
        ? 0
        : (_latencies.reduce((a, b) => a + b) / _latencies.length).round();

    int jitter = 0;
    if (_latencies.length >= 2) {
      int jitterSum = 0;
      for (int i = 1; i < _latencies.length; i++) {
        jitterSum += (_latencies[i] - _latencies[i - 1]).abs();
      }
      jitter = (jitterSum / (_latencies.length - 1)).round();
    }

    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      progress: 1.0,
      currentSpeed: 0,
      testCompleted: true,
      hadError: false,
      clearErrorMessage: true,
      result: SpeedTestResult(
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        ping: ping,
        latency: latency,
        jitter: jitter,
        packetLoss: 0,
      ),
    );
    notifyListeners();

    debugPrint('Complete: ↓${downloadSpeed.toStringAsFixed(1)} ↑${uploadSpeed.toStringAsFixed(1)} Mbps, ${ping}ms');
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  double _roundSpeed(double speed) {
    if (speed < 10) {
      return (speed / 0.1).round() * 0.1;
    } else if (speed < 50) {
      return (speed / 0.25).round() * 0.25;
    } else {
      return (speed / 0.5).round() * 0.5;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(0)}KB';
    if (bytes < 1000000000) return '${(bytes / 1000000).toStringAsFixed(0)}MB';
    return '${(bytes / 1000000000).toStringAsFixed(0)}GB';
  }

  void resetTest() => stopTest();
}
