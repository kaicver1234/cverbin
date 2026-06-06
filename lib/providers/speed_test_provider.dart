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

  static const List<Map<String, dynamic>> _measurements = [
    {'type': 'latency', 'numPackets': 20},
    {'type': 'download', 'bytes': 1000000,  'count': 2, 'warmup': true},
    {'type': 'download', 'bytes': 10000000, 'count': 4},
    {'type': 'download', 'bytes': 25000000, 'count': 3},
    {'type': 'upload',   'bytes': 1000000,  'count': 2, 'warmup': true},
    {'type': 'upload',   'bytes': 5000000,  'count': 4},
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

    // Count measurements by phase for accurate per-phase progress
    final downloadMeasurements = _measurements.where((m) => m['type'] == 'download').toList();
    final uploadMeasurements = _measurements.where((m) => m['type'] == 'upload').toList();
    int downloadDone = 0;
    int uploadDone = 0;

    for (int i = 0; i < _measurements.length; i++) {
      if (_isCanceled) return;

      final measurement = _measurements[i];
      final type = measurement['type'] as String;

      final bool phaseChanged = type != currentPhase;
      if (phaseChanged) {
        // Smooth transition between phases
        if (currentPhase.isNotEmpty) {
          _state = _state.copyWith(progress: 0.0, currentSpeed: 0);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 600));
          if (_isCanceled) return;
        }

        currentPhase = type;
        final nextStep = type == 'download'
            ? SpeedTestStep.download
            : type == 'upload'
                ? SpeedTestStep.upload
                : SpeedTestStep.loading;
        _state = _state.copyWith(step: nextStep);
        notifyListeners();
      }

      // Progress within current phase
      double phaseProgress = 0.0;
      if (type == 'download') {
        phaseProgress = downloadDone / downloadMeasurements.length;
      } else if (type == 'upload') {
        phaseProgress = uploadDone / uploadMeasurements.length;
      }

      debugPrint('📊 Measurement $i: $type');

      switch (type) {
        case 'latency':
          await _runLatencyMeasurement(measurement);
          break;
        case 'download':
          await _runDownloadMeasurement(measurement, phaseProgress);
          downloadDone++;
          break;
        case 'upload':
          await _runUploadMeasurement(measurement, phaseProgress);
          uploadDone++;
          break;
      }

      await Future.delayed(const Duration(milliseconds: 30));
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
    final isWarmup = config['warmup'] as bool? ?? false;
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
          consecutiveFailures = 0;
          if (!isWarmup) {
            _downloadSpeeds.add(speed);
          }

          // Display: rolling median of recent samples (more stable than percentile)
          final samples = _downloadSpeeds.isNotEmpty ? _downloadSpeeds : [speed];
          final stable = _calculatePercentile(samples, 0.5);

          _state = _state.copyWith(
            currentSpeed: speed,
            result: _state.result.copyWith(
              downloadSpeed: stable,
              ping: _latencies.isNotEmpty ? _latencies.last : 0,
            ),
          );
          notifyListeners();

          debugPrint('   📥 Download ${i + 1}/$count ($sizeLabel)${isWarmup ? " [warmup]" : ""}: ${speed.toStringAsFixed(2)} Mbps');
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

    final sw = Stopwatch();
    DateTime? lastUpdateTime;
    final List<double> realtimeSpeeds = [];
    int totalReceived = 0;
    bool started = false;

    try {
      await _dio.get<List<int>>(
        '$_downloadUrl?bytes=$bytes&measId=$_measurementId&during=download',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Cache-Control': 'no-cache, no-store',
            'Accept-Encoding': 'identity', // avoid compression skewing byte count
          },
        ),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (_isCanceled) return;

          // Start timing on first received byte (excludes connect/TTFB)
          if (!started && received > 0) {
            sw.start();
            started = true;
          }
          totalReceived = received;

          if (!started) return;

          final now = DateTime.now();
          final elapsed = sw.elapsedMilliseconds / 1000.0;

          if (elapsed > 0.05 &&
              (lastUpdateTime == null ||
                  now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedMbps = (received * 8) / elapsed / 1000000;
            realtimeSpeeds.add(currentSpeedMbps);

            final smoothedSpeed = realtimeSpeeds.length > 3
                ? realtimeSpeeds
                        .sublist(realtimeSpeeds.length - 3)
                        .reduce((a, b) => a + b) /
                    3
                : currentSpeedMbps;
            final roundedSpeed = _roundSpeed(smoothedSpeed);
            _state = _state.copyWith(currentSpeed: roundedSpeed);
            notifyListeners();
            lastUpdateTime = now;
          }
        },
      );

      if (_isCanceled) return 0.0;
      if (!started) return 0.0;

      sw.stop();
      final durationSeconds = sw.elapsedMilliseconds / 1000.0;
      if (durationSeconds < 0.05) return 0.0;

      return (totalReceived * 8) / durationSeconds / 1000000;
    } catch (e) {
      debugPrint('   ❌ Download measurement error: $e');
      throw Exception('Download failed: $e');
    }
  }

  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final isWarmup = config['warmup'] as bool? ?? false;
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
          consecutiveFailures = 0;
          if (!isWarmup) {
            _uploadSpeeds.add(speed);
          }

          final samples = _uploadSpeeds.isNotEmpty ? _uploadSpeeds : [speed];
          final stable = _calculatePercentile(samples, 0.5);

          int jitter = 0;
          if (_latencies.length >= 2) {
            int jitterSum = 0;
            for (int j = 1; j < _latencies.length; j++) {
              jitterSum += (_latencies[j] - _latencies[j - 1]).abs();
            }
            jitter = (jitterSum / (_latencies.length - 1)).round();
          }

          _state = _state.copyWith(
            currentSpeed: speed,
            result: _state.result.copyWith(
              uploadSpeed: stable,
              jitter: jitter,
            ),
          );
          notifyListeners();

          debugPrint('   📤 Upload ${i + 1}/$count ($sizeLabel)${isWarmup ? " [warmup]" : ""}: ${speed.toStringAsFixed(2)} Mbps');
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

    final random = Random();
    final data = Uint8List.fromList(
      List<int>.generate(bytes, (_) => random.nextInt(256)),
    );

    final sw = Stopwatch()..start();
    DateTime? lastUpdateTime;
    final List<double> realtimeSpeeds = [];

    try {
      await _dio.post(
        '$_uploadUrl?measId=$_measurementId&during=upload',
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Cache-Control': 'no-cache, no-store',
          },
          sendTimeout: const Duration(seconds: 90),
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
    // Use median of non-warmup samples for stable, representative result
    final downloadSpeed = _downloadSpeeds.isEmpty
        ? 0.0
        : _calculatePercentile(_downloadSpeeds, 0.5);
    final uploadSpeed = _uploadSpeeds.isEmpty
        ? 0.0
        : _calculatePercentile(_uploadSpeeds, 0.5);
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
