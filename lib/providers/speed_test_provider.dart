import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Speed Test Provider - Based on Cloudflare Speed Test
class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  bool _isCanceled = false;
  CancelToken? _cancelToken;
  late Dio _dio;

  final List<int> _latencies = [];
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];

  // Measurement configuration (like defyxVPN)
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

  SpeedTestProvider() {
    _dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(seconds: 60)
      ..options.sendTimeout = const Duration(seconds: 60)
      ..options.headers['User-Agent'] = 'Tiksar VPN Speed Test';
  }

  void stopTest() {
    _isCanceled = true;
    _cancelToken?.cancel('User stopped');
    _cancelToken = null;
    _reset();
    _state = const SpeedTestState();
    notifyListeners();
  }

  void _reset() {
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
  }

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready) {
      stopTest();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isCanceled = false;
    _cancelToken = CancelToken();
    _reset();

    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      progress: 0.0,
      result: const SpeedTestResult(),
      currentSpeed: 0.0,
      errorMessage: null,
      hadError: false,
      testCompleted: false,
    );
    notifyListeners();

    try {
      await _runMeasurementSequence();
      if (_isCanceled) return;
      _calculateFinalResults();
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      if (!_isCanceled) {
        _state = _state.copyWith(
          step: SpeedTestStep.ready,
          errorMessage: 'تست سرعت با خطا مواجه شد',
          hadError: true,
        );
        notifyListeners();
      }
    }
  }

  Future<void> _runMeasurementSequence() async {
    String currentPhase = '';
    int measurementIndex = 0;

    for (final measurement in _measurements) {
      if (_isCanceled) return;

      final type = measurement['type'] as String;
      measurementIndex++;
      final progress = measurementIndex / _measurements.length;

      // Phase change
      SpeedTestStep? nextStep;
      if (type == 'latency' && currentPhase != 'loading') {
        nextStep = SpeedTestStep.loading;
        currentPhase = 'loading';
      } else if (type == 'download' && currentPhase != 'download') {
        nextStep = SpeedTestStep.download;
        currentPhase = 'download';
        // Reset progress when changing phase
        if (measurementIndex > 1) {
          _state = _state.copyWith(progress: 0.0);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 800));
        }
      } else if (type == 'upload' && currentPhase != 'upload') {
        nextStep = SpeedTestStep.upload;
        currentPhase = 'upload';
        _state = _state.copyWith(progress: 0.0);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (nextStep != null) {
        _state = _state.copyWith(step: nextStep);
        notifyListeners();
      }

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

    for (int i = 0; i < numPackets; i++) {
      if (_isCanceled) return;

      try {
        final stopwatch = Stopwatch()..start();
        await _dio.get(
          'https://speed.cloudflare.com/__down?bytes=0',
          cancelToken: _cancelToken,
        );
        stopwatch.stop();

        final latency = stopwatch.elapsedMilliseconds;
        _latencies.add(latency);

        final avgLatency = (_latencies.reduce((a, b) => a + b) / _latencies.length).round();
        final jitter = _calculateJitter();

        _state = _state.copyWith(
          result: _state.result.copyWith(
            ping: _latencies.reduce(min),
            latency: avgLatency,
            jitter: jitter,
          ),
        );
        notifyListeners();

        debugPrint('📡 Latency ${i + 1}/$numPackets: ${latency}ms');
      } catch (e) {
        debugPrint('❌ Latency failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _runDownloadMeasurement(Map<String, dynamic> config, double overallProgress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;

    for (int i = 0; i < count; i++) {
      if (_isCanceled) return;

      try {
        final speed = await _measureDownload(bytes);
        if (speed > 0) {
          _downloadSpeeds.add(speed);

          final percentileSpeed = _calculatePercentile(_downloadSpeeds, 0.9);
          final avgSpeed = _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;

          _state = _state.copyWith(
            progress: overallProgress,
            currentSpeed: _roundSpeed(avgSpeed),
            result: _state.result.copyWith(downloadSpeed: percentileSpeed),
          );
          notifyListeners();

          debugPrint('📥 Download ${i + 1}/$count (${_formatBytes(bytes)}): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        debugPrint('❌ Download failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<double> _measureDownload(int bytes) async {
    final stopwatch = Stopwatch()..start();
    int receivedBytes = 0;

    try {
      final response = await _dio.get<List<int>>(
        'https://speed.cloudflare.com/__down?bytes=$bytes',
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.1 && !_isCanceled) {
            final speedMbps = (received * 8) / elapsed / 1000000;
            _state = _state.copyWith(currentSpeed: _roundSpeed(speedMbps));
            notifyListeners();
          }
        },
      );

      stopwatch.stop();
      final actualBytes = response.data?.length ?? receivedBytes;
      final durationSec = stopwatch.elapsedMilliseconds / 1000.0;

      if (durationSec < 0.01) return 0;
      return (actualBytes * 8) / durationSec / 1000000;
    } catch (e) {
      stopwatch.stop();
      if (receivedBytes > 0 && stopwatch.elapsedMilliseconds > 100) {
        return (receivedBytes * 8) / (stopwatch.elapsedMilliseconds / 1000.0) / 1000000;
      }
      return 0;
    }
  }

  Future<void> _runUploadMeasurement(Map<String, dynamic> config, double overallProgress) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;

    for (int i = 0; i < count; i++) {
      if (_isCanceled) return;

      try {
        final speed = await _measureUpload(bytes);
        if (speed > 0) {
          _uploadSpeeds.add(speed);

          final percentileSpeed = _calculatePercentile(_uploadSpeeds, 0.9);
          final avgSpeed = _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;

          _state = _state.copyWith(
            progress: overallProgress,
            currentSpeed: _roundSpeed(avgSpeed),
            result: _state.result.copyWith(uploadSpeed: percentileSpeed),
          );
          notifyListeners();

          debugPrint('📤 Upload ${i + 1}/$count (${_formatBytes(bytes)}): ${speed.toStringAsFixed(2)} Mbps');
        }
      } catch (e) {
        debugPrint('❌ Upload failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<double> _measureUpload(int bytes) async {
    final data = Uint8List(bytes);
    final rng = Random();
    for (int i = 0; i < min(1000, bytes); i++) {
      data[i] = rng.nextInt(256);
    }

    final stopwatch = Stopwatch()..start();
    int sentBytes = 0;

    try {
      await _dio.post(
        'https://speed.cloudflare.com/__up',
        data: data,
        cancelToken: _cancelToken,
        options: Options(headers: {'Content-Type': 'application/octet-stream'}),
        onSendProgress: (sent, total) {
          sentBytes = sent;
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.1 && !_isCanceled) {
            final speedMbps = (sent * 8) / elapsed / 1000000;
            _state = _state.copyWith(currentSpeed: _roundSpeed(speedMbps));
            notifyListeners();
          }
        },
      );

      stopwatch.stop();
      final durationSec = stopwatch.elapsedMilliseconds / 1000.0;

      if (durationSec < 0.01) return 0;
      return (sentBytes * 8) / durationSec / 1000000;
    } catch (e) {
      stopwatch.stop();
      if (sentBytes > 0 && stopwatch.elapsedMilliseconds > 100) {
        return (sentBytes * 8) / (stopwatch.elapsedMilliseconds / 1000.0) / 1000000;
      }
      return 0;
    }
  }

  void _calculateFinalResults() {
    final downloadSpeed = _downloadSpeeds.isNotEmpty
        ? _calculatePercentile(_downloadSpeeds, 0.9)
        : 0.0;
    final uploadSpeed = _uploadSpeeds.isNotEmpty
        ? _calculatePercentile(_uploadSpeeds, 0.9)
        : 0.0;
    final ping = _latencies.isNotEmpty ? _latencies.reduce(min) : 0;
    final latency = _latencies.isNotEmpty
        ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
        : 0;
    final jitter = _calculateJitter();

    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      progress: 1.0,
      currentSpeed: 0.0,
      testCompleted: true,
      hadError: false,
      result: SpeedTestResult(
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        ping: ping,
        latency: latency,
        jitter: jitter,
        packetLoss: 0.0,
      ),
    );
    notifyListeners();

    debugPrint('✅ Complete: ↓${downloadSpeed.toStringAsFixed(1)} ↑${uploadSpeed.toStringAsFixed(1)} Mbps, ${ping}ms');
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
    final index = (percentile * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  double _roundSpeed(double speed) {
    if (speed < 10) return (speed / 0.1).round() * 0.1;
    if (speed < 50) return (speed / 0.25).round() * 0.25;
    return (speed / 0.5).round() * 0.5;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1000) return '${bytes}B';
    if (bytes < 1000000) return '${(bytes / 1000).round()}KB';
    return '${(bytes / 1000000).round()}MB';
  }

  void resetTest() => stopTest();
}
