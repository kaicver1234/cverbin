import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Cloudflare Speed Test Provider
/// Real speed test using Cloudflare's speed test servers
class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  bool _isCanceled = false;
  CancelToken? _cancelToken;

  final List<int> _latencies = [];
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];

  void stopTest() {
    _isCanceled = true;
    _cancelToken?.cancel('User stopped');
    _cancelToken = null;
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _state = const SpeedTestState();
    notifyListeners();
  }

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready) {
      stopTest();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isCanceled = false;
    _cancelToken = CancelToken();
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();

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
      // Phase 1: Ping/Latency
      await _testLatency();
      if (_isCanceled) return;

      // Phase 2: Download
      await _testDownload();
      if (_isCanceled) return;

      // Phase 3: Upload
      await _testUpload();
      if (_isCanceled) return;

      // Done
      _completeTest();
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      if (!_isCanceled) {
        _state = _state.copyWith(
          step: SpeedTestStep.ready,
          errorMessage: 'خطا در تست سرعت',
          hadError: true,
        );
        notifyListeners();
      }
    }
  }

  Future<void> _testLatency() async {
    debugPrint('📡 Testing latency...');

    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 10)
      ..options.receiveTimeout = const Duration(seconds: 10);

    // Warmup
    try {
      await dio.head('https://speed.cloudflare.com/__down?bytes=0');
    } catch (_) {}

    for (int i = 0; i < 20; i++) {
      if (_isCanceled) return;

      try {
        final sw = Stopwatch()..start();
        await dio.head(
          'https://speed.cloudflare.com/__down?bytes=0',
          cancelToken: _cancelToken,
        );
        sw.stop();

        _latencies.add(sw.elapsedMilliseconds);

        final minPing = _latencies.reduce(min);
        final jitter = _calcJitter();

        _state = _state.copyWith(
          progress: (i + 1) / 20,
          result: _state.result.copyWith(ping: minPing, jitter: jitter),
        );
        notifyListeners();

        debugPrint('  Ping ${i + 1}: ${sw.elapsedMilliseconds}ms');
      } catch (e) {
        debugPrint('  Ping ${i + 1} failed');
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_latencies.isEmpty) throw Exception('Latency test failed');
    dio.close();
  }

  Future<void> _testDownload() async {
    debugPrint('📥 Testing download...');

    _state = _state.copyWith(
      step: SpeedTestStep.download,
      progress: 0.0,
      currentSpeed: 0.0,
    );
    notifyListeners();

    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(seconds: 120);

    // Progressive test sizes
    final sizes = [
      100000,    // 100KB warmup
      1000000,   // 1MB
      10000000,  // 10MB
      25000000,  // 25MB
      50000000,  // 50MB
    ];

    for (int i = 0; i < sizes.length; i++) {
      if (_isCanceled) return;

      final bytes = sizes[i];
      final speed = await _downloadTest(dio, bytes);

      if (speed > 0) {
        // Skip warmup for final calculation
        if (i > 0) _downloadSpeeds.add(speed);

        final avgSpeed = _downloadSpeeds.isEmpty
            ? speed
            : _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;

        _state = _state.copyWith(
          progress: (i + 1) / sizes.length,
          currentSpeed: speed,
          result: _state.result.copyWith(downloadSpeed: avgSpeed),
        );
        notifyListeners();

        debugPrint('  Download ${_fmtBytes(bytes)}: ${speed.toStringAsFixed(2)} Mbps');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    dio.close();
  }

  Future<double> _downloadTest(Dio dio, int bytes) async {
    final sw = Stopwatch()..start();
    int received = 0;

    try {
      await dio.get<List<int>>(
        'https://speed.cloudflare.com/__down?bytes=$bytes',
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _cancelToken,
        onReceiveProgress: (recv, total) {
          received = recv;
          final elapsed = sw.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.3 && !_isCanceled) {
            final mbps = (recv * 8) / elapsed / 1000000;
            _state = _state.copyWith(currentSpeed: mbps);
            notifyListeners();
          }
        },
      );

      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000.0;
      if (secs < 0.1) return 0;

      return (received * 8) / secs / 1000000;
    } catch (e) {
      sw.stop();
      if (received > 0 && sw.elapsedMilliseconds > 200) {
        return (received * 8) / (sw.elapsedMilliseconds / 1000.0) / 1000000;
      }
      return 0;
    }
  }

  Future<void> _testUpload() async {
    debugPrint('📤 Testing upload...');

    _state = _state.copyWith(
      step: SpeedTestStep.upload,
      progress: 0.0,
      currentSpeed: 0.0,
    );
    notifyListeners();

    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.sendTimeout = const Duration(seconds: 120);

    final sizes = [
      100000,   // 100KB warmup
      500000,   // 500KB
      1000000,  // 1MB
      2000000,  // 2MB
      5000000,  // 5MB
    ];

    for (int i = 0; i < sizes.length; i++) {
      if (_isCanceled) return;

      final bytes = sizes[i];
      final speed = await _uploadTest(dio, bytes);

      if (speed > 0) {
        if (i > 0) _uploadSpeeds.add(speed);

        final avgSpeed = _uploadSpeeds.isEmpty
            ? speed
            : _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;

        _state = _state.copyWith(
          progress: (i + 1) / sizes.length,
          currentSpeed: speed,
          result: _state.result.copyWith(uploadSpeed: avgSpeed),
        );
        notifyListeners();

        debugPrint('  Upload ${_fmtBytes(bytes)}: ${speed.toStringAsFixed(2)} Mbps');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    dio.close();
  }

  Future<double> _uploadTest(Dio dio, int bytes) async {
    final data = Uint8List(bytes);
    final rng = Random();
    for (int i = 0; i < min(1000, bytes); i++) {
      data[i] = rng.nextInt(256);
    }

    final sw = Stopwatch()..start();
    int sent = 0;

    try {
      await dio.post(
        'https://speed.cloudflare.com/__up',
        data: data,
        cancelToken: _cancelToken,
        options: Options(
          headers: {'Content-Type': 'application/octet-stream'},
        ),
        onSendProgress: (s, total) {
          sent = s;
          final elapsed = sw.elapsedMilliseconds / 1000.0;
          if (elapsed > 0.3 && !_isCanceled) {
            final mbps = (s * 8) / elapsed / 1000000;
            _state = _state.copyWith(currentSpeed: mbps);
            notifyListeners();
          }
        },
      );

      sw.stop();
      final secs = sw.elapsedMilliseconds / 1000.0;
      if (secs < 0.1) return 0;

      return (sent * 8) / secs / 1000000;
    } catch (e) {
      sw.stop();
      if (sent > 0 && sw.elapsedMilliseconds > 200) {
        return (sent * 8) / (sw.elapsedMilliseconds / 1000.0) / 1000000;
      }
      return 0;
    }
  }

  void _completeTest() {
    final download = _downloadSpeeds.isEmpty
        ? 0.0
        : _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;

    final upload = _uploadSpeeds.isEmpty
        ? 0.0
        : _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;

    final ping = _latencies.isEmpty ? 0 : _latencies.reduce(min);
    final jitter = _calcJitter();

    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      progress: 1.0,
      currentSpeed: 0.0,
      testCompleted: true,
      hadError: false,
      result: SpeedTestResult(
        downloadSpeed: download,
        uploadSpeed: upload,
        ping: ping,
        latency: _latencies.isEmpty ? 0 : (_latencies.reduce((a, b) => a + b) ~/ _latencies.length),
        jitter: jitter,
        packetLoss: 0.0,
      ),
    );
    notifyListeners();

    debugPrint('✅ Complete: ↓${download.toStringAsFixed(1)} ↑${upload.toStringAsFixed(1)} Mbps, ${ping}ms');
  }

  int _calcJitter() {
    if (_latencies.length < 2) return 0;
    int sum = 0;
    for (int i = 1; i < _latencies.length; i++) {
      sum += (_latencies[i] - _latencies[i - 1]).abs();
    }
    return sum ~/ (_latencies.length - 1);
  }

  String _fmtBytes(int b) {
    if (b < 1000) return '${b}B';
    if (b < 1000000) return '${(b / 1000).round()}KB';
    return '${(b / 1000000).round()}MB';
  }

  void resetTest() => stopTest();
}
