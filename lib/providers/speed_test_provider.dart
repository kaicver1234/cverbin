import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Internet speed test using the same method as speedtest.net / Cloudflare:
/// **multiple parallel connections with aggregate throughput**.
///
/// Why parallel? A single TCP stream cannot saturate a fast link (TCP window
/// limits), so a one-connection test always under-reports. We instead open
/// several simultaneous transfers, sum the bytes across all of them, and run
/// for a fixed time window — discarding an initial warm-up so TCP slow-start
/// doesn't drag the number down.
///
///   download / upload speed = (bytes transferred in the measurement window) × 8
///                             ─────────────────────────────────────────────────
///                                          window duration (s) × 1e6   → Mbps
///
/// Endpoints are Cloudflare's public speed test edge (anycast picks the nearest
/// PoP automatically, so no server-selection step is needed).
class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  late final Dio _dio;
  String _measurementId = '';
  bool _isCanceled = false;
  final List<CancelToken> _tokens = [];

  // ── Endpoints ──────────────────────────────────────────────────────────────
  static const String _base = 'https://speed.cloudflare.com';
  static const String _downUrl = '$_base/__down';
  static const String _upUrl = '$_base/__up';

  // ── Tunables ────────────────────────────────────────────────────────────────
  // Parallel connections per phase. speedtest.net uses up to 8 flows; a handful
  // is plenty to saturate typical links without overwhelming mobile sockets.
  static const int _downloadConnections = 4;
  static const int _uploadConnections = 3;
  // How long each throughput phase actively transfers.
  static const Duration _downloadDuration = Duration(seconds: 10);
  static const Duration _uploadDuration = Duration(seconds: 8);
  // Ignore this much of the start (TCP slow-start / TLS / ramp-up).
  static const double _warmupSeconds = 2.0;
  // Per-request payload sizes. Large enough that a request lasts long enough to
  // matter, small enough that a worker cycles a few times during the window.
  static const int _downloadReqBytes = 25 * 1000 * 1000; // 25 MB per request
  static const int _uploadReqBytes = 10 * 1000 * 1000; // 10 MB per request
  static const int _uploadChunkSize = 64 * 1024; // 64 KB stream chunks
  // Latency probing.
  static const int _latencyPackets = 15;
  // How often the live gauge / progress bar refreshes.
  static const Duration _sampleInterval = Duration(milliseconds: 100);

  // ── Live counters (shared across parallel workers) ──────────────────────────
  int _bytes = 0; // cumulative bytes for the current phase
  final List<int> _latencies = [];

  SpeedTestProvider() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // Phases are bounded by their own timers, so transport timeouts are loose.
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'User-Agent': 'Tiksar VPN Speed Test'},
    ));
  }

  String _generateMeasurementId() =>
      (Random().nextDouble() * 1e16).round().toString();

  // ── Public API (unchanged for the UI) ──────────────────────────────────────

  void stopTest() {
    _isCanceled = true;
    _cancelAll();
    _latencies.clear();
    _bytes = 0;
    _state = const SpeedTestState();
    notifyListeners();
    debugPrint('🛑 Speed test stopped and reset');
  }

  void resetTest() => stopTest();

  Future<void> startTest() async {
    if (_state.step != SpeedTestStep.ready) {
      stopTest();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _isCanceled = false;
    _measurementId = _generateMeasurementId();
    _latencies.clear();

    _state = const SpeedTestState(
      step: SpeedTestStep.loading,
      currentPhase: 'Initializing...',
    );
    notifyListeners();
    debugPrint('🚀 Speed test started');

    try {
      // 1) Latency / jitter
      await _runLatency();
      if (_isCanceled) return;

      // 2) Download (parallel)
      _state = _state.copyWith(
        step: SpeedTestStep.download,
        currentPhase: 'Measuring download...',
        progress: 0.0,
        currentSpeed: 0,
      );
      notifyListeners();
      final download = await _runThroughput(isUpload: false);
      if (_isCanceled) return;
      _state = _state.copyWith(
        result: _state.result.copyWith(downloadSpeed: download),
        currentSpeed: 0,
        progress: 1.0,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 400));
      if (_isCanceled) return;

      // 3) Upload (parallel)
      _state = _state.copyWith(
        step: SpeedTestStep.upload,
        currentPhase: 'Measuring upload...',
        progress: 0.0,
        currentSpeed: 0,
      );
      notifyListeners();
      final upload = await _runThroughput(isUpload: true);
      if (_isCanceled) return;

      _finalize(download: download, upload: upload);
      debugPrint('🏁 Speed test completed');
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

  // ── Latency ──────────────────────────────────────────────────────────────────
  Future<void> _runLatency() async {
    _state = _state.copyWith(
      step: SpeedTestStep.loading,
      currentPhase: 'Measuring latency...',
    );
    notifyListeners();

    int consecutiveFailures = 0;
    for (int i = 0; i < _latencyPackets; i++) {
      if (_isCanceled) return;
      final token = CancelToken();
      _tokens.add(token);
      try {
        final sw = Stopwatch()..start();
        await _dio.get(
          '$_downUrl?bytes=0&measId=$_measurementId',
          options: Options(headers: {'Cache-Control': 'no-cache, no-store'}),
          cancelToken: token,
        );
        sw.stop();
        final latency = sw.elapsedMilliseconds;
        if (latency > 0 && latency < 5000) {
          _latencies.add(latency);
          consecutiveFailures = 0;
          _publishLatency();
        }
      } catch (e) {
        if (_isCanceled) return;
        consecutiveFailures++;
        if (consecutiveFailures >= 3) {
          throw Exception('Network connection failed');
        }
      }
      await Future.delayed(const Duration(milliseconds: 40));
    }
    if (_latencies.isEmpty) throw Exception('Failed to measure latency');
  }

  void _publishLatency() {
    final avg =
        (_latencies.reduce((a, b) => a + b) / _latencies.length).round();
    _state = _state.copyWith(
      result: _state.result.copyWith(
        ping: _latencies.reduce(min),
        latency: avg,
        jitter: _jitter(),
      ),
    );
    notifyListeners();
  }

  int _jitter() {
    if (_latencies.length < 2) return 0;
    int sum = 0;
    for (int i = 1; i < _latencies.length; i++) {
      sum += (_latencies[i] - _latencies[i - 1]).abs();
    }
    return (sum / (_latencies.length - 1)).round();
  }

  // ── Throughput (parallel, aggregate) ────────────────────────────────────────
  /// Runs `connections` simultaneous transfers for a fixed duration and returns
  /// the windowed aggregate speed in Mbps.
  Future<double> _runThroughput({required bool isUpload}) async {
    final duration = isUpload ? _uploadDuration : _downloadDuration;
    final connections = isUpload ? _uploadConnections : _downloadConnections;
    final totalMs = duration.inMilliseconds;

    _bytes = 0;
    // Cumulative samples: [elapsedSeconds, cumulativeBytes].
    final samples = <List<double>>[];
    final phaseSw = Stopwatch()..start();

    // Spawn the parallel workers. They keep transferring until canceled.
    final workers = <Future<void>>[];
    for (int i = 0; i < connections; i++) {
      final token = CancelToken();
      _tokens.add(token);
      workers.add(isUpload ? _uploadWorker(token) : _downloadWorker(token));
    }

    // Periodic sampler: records the aggregate byte count and drives the UI.
    final sampler = Timer.periodic(_sampleInterval, (_) {
      final t = phaseSw.elapsedMilliseconds / 1000.0;
      samples.add([t, _bytes.toDouble()]);
      final instant = _instantSpeedMbps(samples);
      _state = _state.copyWith(
        currentSpeed: _roundSpeed(instant),
        progress: (phaseSw.elapsedMilliseconds / totalMs).clamp(0.0, 1.0),
      );
      notifyListeners();
    });

    // Let it run for the measurement duration, then stop everything.
    await Future.delayed(duration);
    sampler.cancel();
    phaseSw.stop();
    samples.add([phaseSw.elapsedMilliseconds / 1000.0, _bytes.toDouble()]);
    _cancelAll();
    // Give canceled requests a moment to unwind.
    await Future.delayed(const Duration(milliseconds: 50));

    if (_isCanceled) return 0.0;
    return _windowedSpeedMbps(samples, _warmupSeconds);
  }

  /// One download worker: streams a large payload, restarting when the server
  /// finishes one, until its token is canceled. Adds every chunk to [_bytes].
  Future<void> _downloadWorker(CancelToken token) async {
    while (!_isCanceled && !token.isCancelled) {
      try {
        final resp = await _dio.get<ResponseBody>(
          '$_downUrl?bytes=$_downloadReqBytes&measId=$_measurementId',
          options: Options(
            responseType: ResponseType.stream,
            headers: const {
              'Cache-Control': 'no-cache, no-store',
              'Accept-Encoding': 'identity',
            },
          ),
          cancelToken: token,
        );
        await for (final chunk in resp.data!.stream) {
          if (_isCanceled || token.isCancelled) return;
          _bytes += chunk.length;
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {
        return;
      }
    }
  }

  /// One upload worker: POSTs a fixed-size body of zero-filled chunks and counts
  /// bytes accepted via send-progress, restarting until canceled.
  Future<void> _uploadWorker(CancelToken token) async {
    final chunk = Uint8List(_uploadChunkSize); // zero-filled; CF doesn't compress
    while (!_isCanceled && !token.isCancelled) {
      int lastSent = 0;

      Stream<List<int>> body() async* {
        int produced = 0;
        while (produced < _uploadReqBytes && !_isCanceled && !token.isCancelled) {
          final remaining = _uploadReqBytes - produced;
          if (remaining >= chunk.length) {
            yield chunk;
            produced += chunk.length;
          } else {
            yield Uint8List(remaining);
            produced += remaining;
          }
        }
      }

      try {
        await _dio.post(
          '$_upUrl?measId=$_measurementId',
          data: body(),
          options: Options(
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Length': _uploadReqBytes,
              'Cache-Control': 'no-cache, no-store',
            },
          ),
          onSendProgress: (sent, total) {
            _bytes += (sent - lastSent);
            lastSent = sent;
          },
          cancelToken: token,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {
        return;
      }
    }
  }

  /// Aggregate speed over the steady-state window: bytes transferred after the
  /// warm-up, divided by the time spent in that window.
  double _windowedSpeedMbps(List<List<double>> samples, double warmupSec) {
    if (samples.length < 2) return 0.0;
    final endT = samples.last[0];
    final endB = samples.last[1];

    // If the whole phase was shorter than the warm-up, use it all.
    if (endT <= warmupSec) {
      final dt = endT - samples.first[0];
      if (dt < 0.2) return 0.0;
      return (endB - samples.first[1]) * 8 / dt / 1e6;
    }

    // First sample at/after the warm-up mark = window start.
    List<double> start = samples.first;
    for (final s in samples) {
      if (s[0] >= warmupSec) {
        start = s;
        break;
      }
    }
    final dt = endT - start[0];
    final db = endB - start[1];
    if (dt < 0.2 || db <= 0) return 0.0;
    return db * 8 / dt / 1e6;
  }

  /// Instantaneous aggregate speed over roughly the last second (live gauge).
  double _instantSpeedMbps(List<List<double>> samples) {
    if (samples.length < 2) return 0.0;
    final endT = samples.last[0];
    final endB = samples.last[1];
    List<double> start = samples.first;
    for (int i = samples.length - 1; i >= 0; i--) {
      if (endT - samples[i][0] >= 1.0) {
        start = samples[i];
        break;
      }
    }
    final dt = endT - start[0];
    final db = endB - start[1];
    if (dt < 0.15 || db <= 0) return 0.0;
    return db * 8 / dt / 1e6;
  }

  // ── Finalize ─────────────────────────────────────────────────────────────────
  void _finalize({required double download, required double upload}) {
    _state = _state.copyWith(
      step: SpeedTestStep.ready,
      progress: 1.0,
      currentSpeed: 0,
      testCompleted: true,
      hadError: false,
      clearErrorMessage: true,
      result: SpeedTestResult(
        downloadSpeed: download,
        uploadSpeed: upload,
        ping: _latencies.isEmpty ? 0 : _latencies.reduce(min),
        latency: _latencies.isEmpty
            ? 0
            : (_latencies.reduce((a, b) => a + b) / _latencies.length).round(),
        jitter: _jitter(),
        packetLoss: 0,
      ),
    );
    notifyListeners();
    debugPrint(
        'Complete: ↓${download.toStringAsFixed(1)} ↑${upload.toStringAsFixed(1)} Mbps');
  }

  void _cancelAll() {
    for (final t in _tokens) {
      if (!t.isCancelled) t.cancel('phase-complete');
    }
    _tokens.clear();
  }

  double _roundSpeed(double speed) {
    if (speed < 10) return (speed / 0.1).round() * 0.1;
    if (speed < 50) return (speed / 0.25).round() * 0.25;
    return (speed / 0.5).round() * 0.5;
  }

  @override
  void dispose() {
    _isCanceled = true;
    _cancelAll();
    _dio.close(force: true);
    super.dispose();
  }
}
