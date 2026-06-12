import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Cloudflare speed test.
///
/// This mirrors the measurement methodology of the defyxVPN project: instead of
/// streaming data at full blast for a fixed number of seconds, it performs a
/// fixed *count* of bounded requests of fixed byte sizes and times each one
/// individually. The total duration emerges from those counts/sizes, exactly
/// like defyx. Because every request is small (≤ 10 MB download, ≤ 1 MB upload)
/// and completes naturally, the uplink / VPN tunnel is never flooded and the
/// connection can no longer be wedged by an aborted giant transfer.
class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  bool _isCanceled = false;
  String _measurementId = '';

  final List<int> _latencies = [];
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];

  Dio? _dio;
  CancelToken? _token;

  // ── Endpoints ──────────────────────────────────────────────────────────────
  static const String _base = 'https://speed.cloudflare.com';
  static const String _downUrl = '$_base/__down';
  static const String _upUrl = '$_base/__up';

  // ── Measurement plan (mirrors defyxVPN's SpeedMeasurementConfig) ─────────────
  // Grouped per UI phase so latency → download → upload each run contiguously.
  static const List<Map<String, int>> _latencyPlan = [
    {'numPackets': 1},
    {'numPackets': 20},
  ];
  static const List<Map<String, int>> _downloadPlan = [
    {'bytes': 100000, 'count': 1},
    {'bytes': 100000, 'count': 9},
    {'bytes': 1000000, 'count': 8},
    {'bytes': 10000000, 'count': 6},
  ];
  static const List<Map<String, int>> _uploadPlan = [
    {'bytes': 100000, 'count': 8},
    {'bytes': 1000000, 'count': 6},
  ];

  static const int _maxConsecutiveFailures = 3;
  static const int _chunkSize = 65536;
  static const Duration _measurementDelay = Duration(milliseconds: 50);
  static const Duration _latencyDelay = Duration(milliseconds: 10);
  static const Duration _phaseTransitionDelay = Duration(milliseconds: 1200);

  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 60);
  static const Duration _sendTimeout = Duration(seconds: 60);

  SpeedTestProvider();

  Dio _createDio() => Dio(BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: {'User-Agent': 'TiksarVPN/SpeedTest'},
      ));

  String _generateMeasurementId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

  // ── Public API ──────────────────────────────────────────────────────────────

  void stopTest() {
    _isCanceled = true;
    _token?.cancel('stopped');
    _dio?.close(force: true);
    _dio = null;
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _state = const SpeedTestState();
    notifyListeners();
    debugPrint('[SpeedTest] Stopped');
  }

  void resetTest() => stopTest();

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready) {
      stopTest();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isCanceled = false;
    _measurementId = _generateMeasurementId();
    _latencies.clear();
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();

    _dio = _createDio();
    _token = CancelToken();

    _state = const SpeedTestState(
      step: SpeedTestStep.loading,
      currentPhase: 'Initializing...',
    );
    notifyListeners();
    debugPrint('[SpeedTest] Started');

    try {
      // Phase 1: Latency
      _state = _state.copyWith(
        step: SpeedTestStep.loading,
        currentPhase: 'Measuring latency...',
        progress: 0.0,
        currentSpeed: 0,
      );
      notifyListeners();
      await _runLatencyPhase();
      if (_isCanceled) return;

      // Phase 2: Download
      await _transitionTo(
        SpeedTestStep.download,
        'Measuring download...',
      );
      if (_isCanceled) return;
      await _runDownloadPhase();
      if (_isCanceled) return;

      // Phase 3: Upload
      await _transitionTo(
        SpeedTestStep.upload,
        'Measuring upload...',
      );
      if (_isCanceled) return;
      await _runUploadPhase();
      if (_isCanceled) return;

      _finalize();
      debugPrint(
          '[SpeedTest] Complete: down=${_state.result.downloadSpeed.toStringAsFixed(1)} up=${_state.result.uploadSpeed.toStringAsFixed(1)} Mbps');
    } catch (e) {
      debugPrint('[SpeedTest] Error: $e');
      if (!_isCanceled) {
        _state = _state.copyWith(
          step: SpeedTestStep.ready,
          errorMessage: 'test_failed',
          hadError: true,
          isConnectionStable: false,
          currentSpeed: 0,
        );
        notifyListeners();
      }
    } finally {
      _dio?.close();
      _dio = null;
    }
  }

  // ── Phase transition (mirrors defyx's 1200ms gap + progress reset) ───────────

  Future<void> _transitionTo(SpeedTestStep step, String phase) async {
    _state = _state.copyWith(progress: 0.0, currentSpeed: 0);
    notifyListeners();
    await Future.delayed(_phaseTransitionDelay);
    if (_isCanceled) return;
    _state = _state.copyWith(step: step, currentPhase: phase, progress: 0.0);
    notifyListeners();
  }

  // ── Latency ──────────────────────────────────────────────────────────────────

  Future<void> _runLatencyPhase() async {
    final total = _latencyPlan.fold<int>(0, (s, g) => s + g['numPackets']!);
    int done = 0;
    int consecutiveFailures = 0;

    for (final group in _latencyPlan) {
      final numPackets = group['numPackets']!;
      for (int i = 0; i < numPackets; i++) {
        if (_isCanceled) return;
        try {
          final sw = Stopwatch()..start();
          await _dio!.get(
            '$_downUrl?bytes=0&measId=$_measurementId',
            options: Options(headers: const {
              'Cache-Control': 'no-cache, no-store',
            }),
            cancelToken: _token,
          );
          sw.stop();
          if (_isCanceled) return;

          final ms = sw.elapsedMilliseconds;
          if (ms >= 0) {
            _latencies.add(ms);
            consecutiveFailures = 0;
            _publishLatency(ms);
          }
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) return;
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception('Network unreachable during latency test');
          }
        }

        done++;
        _setProgress(done / total);
        await Future.delayed(_latencyDelay);
      }
    }

    if (_latencies.isEmpty) throw Exception('Latency measurement failed');
  }

  // ── Download ──────────────────────────────────────────────────────────────────

  Future<void> _runDownloadPhase() async {
    final total = _downloadPlan.fold<int>(0, (s, g) => s + g['count']!);
    int done = 0;
    int consecutiveFailures = 0;

    for (final group in _downloadPlan) {
      final bytes = group['bytes']!;
      final count = group['count']!;
      for (int i = 0; i < count; i++) {
        if (_isCanceled) return;
        try {
          final speed = await _measureDownload(bytes);
          if (speed > 0 && !_isCanceled) {
            _downloadSpeeds.add(speed);
            consecutiveFailures = 0;
            _publishDownload();
          }
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) return;
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception('Network connection lost during download test');
          }
        } catch (_) {
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception('Network connection lost during download test');
          }
        }

        done++;
        _setProgress(done / total);
        await Future.delayed(_measurementDelay);
      }
    }
  }

  Future<double> _measureDownload(int bytes) async {
    final sw = Stopwatch()..start();
    DateTime? lastUpdate;

    final resp = await _dio!.get<List<int>>(
      '$_downUrl?bytes=$bytes&measId=$_measurementId&during=download',
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {
          'Cache-Control': 'no-cache, no-store',
          'Accept-Encoding': 'identity',
        },
      ),
      onReceiveProgress: (received, total) {
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        final now = DateTime.now();
        if (!_isCanceled &&
            elapsed > 0.05 &&
            (lastUpdate == null ||
                now.difference(lastUpdate!).inMilliseconds > 100)) {
          final mbps = (received * 8) / elapsed / 1e6;
          _setCurrentSpeed(_roundSpeed(mbps));
          lastUpdate = now;
        }
      },
      cancelToken: _token,
    );
    sw.stop();
    if (_isCanceled) return 0.0;

    final seconds = sw.elapsedMilliseconds / 1000.0;
    if (seconds < 0.01) return 0.0;
    final actualBytes = resp.data?.length ?? 0;
    if (actualBytes <= 0) return 0.0;
    return (actualBytes * 8) / seconds / 1e6;
  }

  // ── Upload ────────────────────────────────────────────────────────────────────

  Future<void> _runUploadPhase() async {
    final total = _uploadPlan.fold<int>(0, (s, g) => s + g['count']!);
    int done = 0;
    int consecutiveFailures = 0;

    for (final group in _uploadPlan) {
      final bytes = group['bytes']!;
      final count = group['count']!;
      for (int i = 0; i < count; i++) {
        if (_isCanceled) return;
        try {
          final speed = await _measureUpload(bytes);
          if (speed > 0 && !_isCanceled) {
            _uploadSpeeds.add(speed);
            consecutiveFailures = 0;
            _publishUpload();
          }
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) return;
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception('Network connection lost during upload test');
          }
        } catch (_) {
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception('Network connection lost during upload test');
          }
        }

        done++;
        _setProgress(done / total);
        await Future.delayed(_measurementDelay);
      }
    }
  }

  Future<double> _measureUpload(int bytes) async {
    final sw = Stopwatch()..start();
    DateTime? lastUpdate;

    final controller = StreamController<List<int>>();
    final random = Random();
    int produced = 0;

    // Producer: stream the body in small chunks. dio applies backpressure as the
    // socket drains, so we never dump the whole body into the send buffer at once
    // (that buffer-fill was the old "spike to 50 then 0" artefact).
    unawaited(() async {
      try {
        while (produced < bytes && !controller.isClosed && !_isCanceled) {
          final size = min(_chunkSize, bytes - produced);
          controller.add(List<int>.generate(size, (_) => random.nextInt(256)));
          produced += size;
          await Future.delayed(const Duration(microseconds: 1));
        }
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }());

    await _dio!.post(
      '$_upUrl?measId=$_measurementId&during=upload',
      data: controller.stream,
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': bytes,
          'Cache-Control': 'no-cache, no-store',
        },
      ),
      onSendProgress: (sent, total) {
        final elapsed = sw.elapsedMilliseconds / 1000.0;
        final now = DateTime.now();
        if (!_isCanceled &&
            elapsed > 0.05 &&
            (lastUpdate == null ||
                now.difference(lastUpdate!).inMilliseconds > 100)) {
          final mbps = (sent * 8) / elapsed / 1e6;
          _setCurrentSpeed(_roundSpeed(mbps));
          lastUpdate = now;
        }
      },
      cancelToken: _token,
    );
    sw.stop();
    if (!controller.isClosed) await controller.close();
    if (_isCanceled) return 0.0;

    final seconds = sw.elapsedMilliseconds / 1000.0;
    if (seconds < 0.01) return 0.0;
    return (bytes * 8) / seconds / 1e6;
  }

  // ── Publish helpers ───────────────────────────────────────────────────────────

  void _setProgress(double p) {
    _state = _state.copyWith(progress: p.clamp(0.0, 1.0));
    notifyListeners();
  }

  void _setCurrentSpeed(double v) {
    _state = _state.copyWith(currentSpeed: v);
    notifyListeners();
  }

  void _publishLatency(int latency) {
    if (_latencies.isEmpty) return;
    final avg =
        (_latencies.reduce((a, b) => a + b) / _latencies.length).round();
    _state = _state.copyWith(
      result: _state.result.copyWith(
        ping: latency,
        latency: avg,
        jitter: _computeJitter(),
      ),
    );
    notifyListeners();
  }

  void _publishDownload() {
    final pct = _percentile(_downloadSpeeds, 0.9);
    final avg =
        _downloadSpeeds.reduce((a, b) => a + b) / _downloadSpeeds.length;
    _state = _state.copyWith(
      currentSpeed: avg,
      result: _state.result.copyWith(
        downloadSpeed: pct,
        ping: _latencies.isNotEmpty ? _latencies.last : _state.result.ping,
        latency: _latencies.isNotEmpty
            ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
            : _state.result.latency,
        jitter: _computeJitter(),
      ),
    );
    notifyListeners();
  }

  void _publishUpload() {
    final pct = _percentile(_uploadSpeeds, 0.9);
    final avg = _uploadSpeeds.reduce((a, b) => a + b) / _uploadSpeeds.length;
    _state = _state.copyWith(
      currentSpeed: avg,
      result: _state.result.copyWith(
        uploadSpeed: pct,
        jitter: _computeJitter(),
        packetLoss: _computePacketLoss(),
      ),
    );
    notifyListeners();
  }

  // ── Finalize ────────────────────────────────────────────────────────────────

  void _finalize() {
    final down = _percentile(_downloadSpeeds, 0.9);
    final up = _percentile(_uploadSpeeds, 0.9);
    final ping = _latencies.isEmpty ? 0 : _latencies.reduce(min);
    final latency = _latencies.isEmpty
        ? 0
        : _percentile(_latencies.map((e) => e.toDouble()).toList(), 0.5)
            .round();
    final jitter = _computeJitter();
    final packetLoss = _computePacketLoss();
    final stable =
        packetLoss < 5.0 && down > 0.1 && up > 0.1;

    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      progress: 1.0,
      currentSpeed: 0,
      testCompleted: true,
      hadError: false,
      isConnectionStable: stable,
      clearErrorMessage: true,
      result: SpeedTestResult(
        downloadSpeed: down,
        uploadSpeed: up,
        ping: ping,
        latency: latency,
        jitter: jitter,
        packetLoss: packetLoss,
      ),
    );
    notifyListeners();
  }

  // ── Stats helpers ─────────────────────────────────────────────────────────────

  double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  int _computeJitter() {
    if (_latencies.length < 2) return 0;
    int sum = 0;
    for (int i = 1; i < _latencies.length; i++) {
      sum += (_latencies[i] - _latencies[i - 1]).abs();
    }
    return (sum / (_latencies.length - 1)).round();
  }

  double _computePacketLoss() {
    if (_latencies.length <= 10) return 0.0;
    final expected = _latencyPlan.fold<int>(0, (s, g) => s + g['numPackets']!);
    return ((expected - _latencies.length) / expected * 100).clamp(0.0, 100.0);
  }

  double _roundSpeed(double speed) {
    if (speed <= 0) return 0;
    if (speed < 10) return (speed / 0.1).round() * 0.1;
    if (speed < 50) return (speed / 0.25).round() * 0.25;
    return (speed / 0.5).round() * 0.5;
  }

  @override
  void dispose() {
    _isCanceled = true;
    _token?.cancel('disposed');
    _dio?.close(force: true);
    _dio = null;
    super.dispose();
  }
}
