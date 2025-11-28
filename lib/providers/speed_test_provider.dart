import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Speed Test Configuration
class SpeedMeasurementConfig {
  static const List<Map<String, dynamic>> measurements = [
    {'type': 'latency', 'numPackets': 1},
    {'type': 'download', 'bytes': 100000, 'count': 1, 'bypassMinDuration': true},
    {'type': 'latency', 'numPackets': 20},
    {'type': 'download', 'bytes': 100000, 'count': 9},
    {'type': 'download', 'bytes': 1000000, 'count': 8},
    {'type': 'upload', 'bytes': 100000, 'count': 8},
    {'type': 'upload', 'bytes': 1000000, 'count': 6},
    {'type': 'download', 'bytes': 10000000, 'count': 6},
  ];

  static const int totalMeasurements = 8;
  static const int maxConsecutiveFailures = 3;
  static const int chunkSize = 65536;
  static const Duration measurementDelay = Duration(milliseconds: 50);
  static const Duration latencyDelay = Duration(milliseconds: 10);

  static String formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(0)}KB';
    if (bytes < 1000000000) return '${(bytes / 1000000).toStringAsFixed(0)}MB';
    return '${(bytes / 1000000000).toStringAsFixed(0)}GB';
  }

  static double roundSpeed(double speed) {
    if (speed < 10) {
      return (speed / 0.1).round() * 0.1;
    } else if (speed < 50) {
      return (speed / 0.25).round() * 0.25;
    } else {
      return (speed / 0.5).round() * 0.5;
    }
  }
}

class SpeedTestProvider with ChangeNotifier {
  final Dio _dio = Dio();
  
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;
  
  bool _isTestCanceled = false;
  String _measurementId = '';
  
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];


  SpeedTestProvider() {
    _dio.options.baseUrl = 'https://speed.cloudflare.com';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 60);
    _dio.options.headers['User-Agent'] = 'Tiksar VPN Speed Test';
  }

  @override
  void dispose() {
    stopTest();
    _dio.close();
    super.dispose();
  }

  String _generateMeasurementId() {
    return (Random().nextDouble() * 1e16).round().toString();
  }

  void stopTest() {
    _isTestCanceled = true;
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();
    _state = const SpeedTestState();
    notifyListeners();
    debugPrint('🛑 Speed test stopped and reset');
  }

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready && !_isTestCanceled) {
      stopTest();
      return;
    }

    _isTestCanceled = false;
    _measurementId = _generateMeasurementId();
    debugPrint('🚀 Cloudflare Speed Test Started - ID: $_measurementId');

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
      await _runMeasurementSequence();

      if (_isTestCanceled) {
        debugPrint('🛑 Speed test was canceled');
        return;
      }

      _calculateFinalResults();
      _checkConnectionStability();
      debugPrint('🏁 Speed test completed successfully');
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


  Future<void> _runMeasurementSequence() async {
    String currentPhase = '';

    for (int i = 0; i < SpeedMeasurementConfig.measurements.length; i++) {
      if (_isTestCanceled) {
        debugPrint('🛑 Measurement sequence canceled');
        return;
      }

      final measurement = SpeedMeasurementConfig.measurements[i];
      final progress = (i + 1) / SpeedMeasurementConfig.totalMeasurements;
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

      if (needsPhaseChange && i > 0 && _state.progress > 0) {
        _state = _state.copyWith(progress: 0.0);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 1200));

        if (_isTestCanceled) {
          debugPrint('🛑 Measurement sequence canceled during transition');
          return;
        }
      }

      if (needsPhaseChange && nextStep != null) {
        _state = _state.copyWith(step: nextStep);
        notifyListeners();
      }

      debugPrint('📊 Running measurement ${i + 1}/${SpeedMeasurementConfig.totalMeasurements}: $type');

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

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
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
      if (_isTestCanceled) {
        debugPrint('🛑 Latency measurement canceled');
        return;
      }

      try {
        final startTime = DateTime.now();
        await _dio.get('/__down', queryParameters: {
          'bytes': 0,
          'measId': _measurementId,
        });
        final latency = DateTime.now().difference(startTime).inMilliseconds;

        if (_isTestCanceled) return;

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

        debugPrint('   📡 Latency ${i + 1}/$numPackets: ${latency}ms (Avg: ${avgLatency}ms, Jitter: ${jitter}ms)');
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Latency measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection failed. Please check your internet connection.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.latencyDelay);
    }

    if (_latencies.isEmpty) {
      throw Exception('Failed to measure latency. Please check your internet connection.');
    }
  }


  Future<void> _runDownloadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);
    int consecutiveFailures = 0;

    _state = _state.copyWith(
      step: SpeedTestStep.download,
      currentPhase: 'Download test: $sizeLabel',
      progress: progress,
    );
    notifyListeners();

    for (int i = 0; i < count; i++) {
      if (_isTestCanceled) {
        debugPrint('🛑 Download measurement canceled');
        return;
      }

      try {
        final speed = await _measureDownloadSpeed(bytes);
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          consecutiveFailures = 0;

          final percentileSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
          final avgSpeed = _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;
          final currentPing = _latencies.isNotEmpty ? _latencies.last : 0;
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
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(
              downloadSpeed: percentileSpeed,
              ping: currentPing,
              latency: avgLatency,
              jitter: jitter,
            ),
          );
          notifyListeners();

          debugPrint('   📥 Download ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Download measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection lost during download test.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
    }
  }

  Future<double> _measureDownloadSpeed(int bytes) async {
    if (_isTestCanceled) return 0.0;

    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;

      final response = await _dio.get<List<int>>(
        '/__down',
        queryParameters: {
          'bytes': bytes,
          'measId': _measurementId,
          'during': 'download',
        },
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;

          if (!_isTestCanceled &&
              elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (received * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;
            final roundedSpeed = SpeedMeasurementConfig.roundSpeed(currentSpeedMbps);
            _state = _state.copyWith(currentSpeed: roundedSpeed);
            notifyListeners();
            lastUpdateTime = now;
          }
        },
      );

      if (_isTestCanceled) return 0.0;

      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;

      if (durationSeconds < 0.01) return 0.0;

      final actualBytes = response.data?.length ?? bytes;
      final bits = actualBytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      return mbps;
    } catch (e) {
      debugPrint('   ❌ Download measurement error: $e');
      throw Exception('Download failed: $e');
    }
  }


  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double progress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    final sizeLabel = SpeedMeasurementConfig.formatBytes(bytes);
    int consecutiveFailures = 0;

    _state = _state.copyWith(
      step: SpeedTestStep.upload,
      currentPhase: 'Upload test: $sizeLabel',
      progress: progress,
    );
    notifyListeners();

    for (int i = 0; i < count; i++) {
      if (_isTestCanceled) {
        debugPrint('🛑 Upload measurement canceled');
        return;
      }

      try {
        final speed = await _measureUploadSpeed(bytes);
        if (speed > 0 && !_isTestCanceled) {
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

          double packetLoss = 0.0;
          if (_latencies.length > 10) {
            final expectedPackets = SpeedMeasurementConfig.measurements
                .where((m) => m['type'] == 'latency')
                .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
            packetLoss = ((expectedPackets - _latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
          }

          _state = _state.copyWith(
            currentSpeed: avgSpeed,
            result: _state.result.copyWith(
              uploadSpeed: percentileSpeed,
              jitter: jitter,
              packetLoss: packetLoss,
            ),
          );
          notifyListeners();

          debugPrint('   📤 Upload ${i + 1}/$count ($sizeLabel): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        consecutiveFailures++;
        debugPrint('   ❌ Upload measurement ${i + 1} failed: $e');

        if (consecutiveFailures >= SpeedMeasurementConfig.maxConsecutiveFailures) {
          throw Exception('Network connection lost during upload test.');
        }
      }

      await Future.delayed(SpeedMeasurementConfig.measurementDelay);
    }
  }

  Future<double> _measureUploadSpeed(int bytes) async {
    if (_isTestCanceled) return 0.0;

    try {
      DateTime? lastUpdateTime;
      DateTime? firstByteTime;
      int lastSentBytes = 0;

      // Generate random data for upload
      final random = Random();
      final data = Uint8List.fromList(
        List<int>.generate(bytes, (_) => random.nextInt(256)),
      );

      final response = await _dio.post(
        '/__up',
        data: data,
        queryParameters: {
          'measId': _measurementId,
          'during': 'upload',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytes,
          },
        ),
        onSendProgress: (sent, total) {
          final now = DateTime.now();
          
          // Record time when first bytes are actually sent
          if (firstByteTime == null && sent > 0) {
            firstByteTime = now;
            lastSentBytes = sent;
            return;
          }

          if (firstByteTime == null) return;
          
          final elapsed = now.difference(firstByteTime!).inMilliseconds / 1000.0;

          if (!_isTestCanceled &&
              elapsed > 0.05 &&
              sent > lastSentBytes &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final currentSpeedBps = (sent * 8) / elapsed;
            final currentSpeedMbps = currentSpeedBps / 1000000;
            final roundedSpeed = SpeedMeasurementConfig.roundSpeed(currentSpeedMbps);
            _state = _state.copyWith(currentSpeed: roundedSpeed);
            notifyListeners();
            lastUpdateTime = now;
            lastSentBytes = sent;
          }
        },
      );

      if (_isTestCanceled) return 0.0;

      // Use server timing if available from response headers
      final serverTiming = response.headers.value('server-timing');
      double durationSeconds;
      
      if (serverTiming != null && serverTiming.contains('dur=')) {
        // Parse server timing: "cfRequestDuration;dur=123.45"
        final match = RegExp(r'dur=(\d+\.?\d*)').firstMatch(serverTiming);
        if (match != null) {
          durationSeconds = double.parse(match.group(1)!) / 1000.0;
        } else {
          durationSeconds = firstByteTime != null 
              ? DateTime.now().difference(firstByteTime!).inMilliseconds / 1000.0
              : 0.0;
        }
      } else {
        durationSeconds = firstByteTime != null 
            ? DateTime.now().difference(firstByteTime!).inMilliseconds / 1000.0
            : 0.0;
      }

      if (durationSeconds < 0.01) return 0.0;

      final bits = bytes * 8;
      final bps = bits / durationSeconds;
      final mbps = bps / 1000000;

      return mbps;
    } catch (e) {
      debugPrint('   ❌ Upload measurement error: $e');
      throw Exception('Upload failed: $e');
    }
  }


  void _calculateFinalResults() {
    final finalDownloadSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
    final finalUploadSpeed = _calculatePercentile(_uploadSpeeds, 0.9);

    final ping = _latencies.isNotEmpty ? _latencies.reduce((a, b) => a < b ? a : b) : 0;
    final latency = _calculatePercentile(_latencies.map((e) => e.toDouble()).toList(), 0.5).round();

    int jitter = 0;
    if (_latencies.length >= 2) {
      List<int> jitterValues = [];
      for (int i = 1; i < _latencies.length; i++) {
        jitterValues.add((_latencies[i] - _latencies[i - 1]).abs());
      }
      jitter = jitterValues.isNotEmpty
          ? (jitterValues.reduce((a, b) => a + b) / jitterValues.length).round()
          : 0;
    }

    double packetLoss = 0.0;
    if (_latencies.length > 10) {
      final expectedPackets = SpeedMeasurementConfig.measurements
          .where((m) => m['type'] == 'latency')
          .fold<int>(0, (sum, m) => sum + (m['numPackets'] as int));
      packetLoss = ((expectedPackets - _latencies.length) / expectedPackets * 100).clamp(0.0, 100.0);
    }

    _state = _state.copyWith(
      result: SpeedTestResult(
        downloadSpeed: finalDownloadSpeed,
        uploadSpeed: finalUploadSpeed,
        ping: ping,
        latency: latency,
        jitter: jitter,
        packetLoss: packetLoss,
      ),
      progress: 1.0,
      currentPhase: 'Test completed',
      testCompleted: true,
    );
    notifyListeners();

    debugPrint('📊 Final Results: Download: ${finalDownloadSpeed.toStringAsFixed(2)} Mbps, '
        'Upload: ${finalUploadSpeed.toStringAsFixed(2)} Mbps, '
        'Ping: ${ping}ms, Jitter: ${jitter}ms');
  }

  void _checkConnectionStability() {
    final result = _state.result;
    final isStable = result.packetLoss < 5.0 &&
        result.jitter < 50 &&
        result.downloadSpeed > 0.1 &&
        result.uploadSpeed > 0.1;

    if (!isStable) {
      _state = _state.copyWith(
        step: SpeedTestStep.ready,
        isConnectionStable: false,
        errorMessage: 'Your connection was unstable, and the test was interrupted.',
        hadError: true,
      );
    } else {
      _state = _state.copyWith(
        step: SpeedTestStep.ready,
        clearErrorMessage: true,
        hadError: false,
      );
    }
    notifyListeners();
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  void resetTest() {
    stopTest();
  }

  void retryConnection() {
    stopTest();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isTestCanceled) {
        startTest();
      }
    });
  }
}
