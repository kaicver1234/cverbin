import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

/// Cloudflare speed test — faithful port of the official `@cloudflare/speedtest`
/// engine that powers https://speed.cloudflare.com.
///
/// It reproduces Cloudflare's exact methodology rather than approximating it:
///
///  • Same measurement plan and payload sizes (100 KB → 250 MB download,
///    100 KB → 50 MB upload), grouped per UI phase (latency → download →
///    upload) instead of interleaved.
///  • Server processing time is subtracted from every timing by parsing the
///    `Server-Timing: cfRequestDuration;dur=…` response header (falling back to
///    a 10 ms estimate), exactly like the reference engine.
///  • Download speed = 8 · bytes · 1.005 / ((ttfb − serverTime) + payloadTransferTime).
///    Upload speed   = 8 · bytes · 1.005 / ttfb.
///  • The reported bandwidth is the **90th percentile** of every individual
///    request's bits-per-second (pooled across all payload sizes), using the
///    same linear-interpolation percentile as Cloudflare. Latency is the
///    **median** ping; jitter is the mean of consecutive ping deltas.
///  • The "finish" rule (once a round's fastest request exceeds 1000 ms, stop
///    testing larger payloads of that type) scales the payload to the link
///    speed automatically — so slow links never attempt the giant transfers
///    and fast links climb up to 250 MB to saturate the pipe.
class SpeedTestProvider with ChangeNotifier {
  SpeedTestState _state = const SpeedTestState();
  SpeedTestState get state => _state;

  bool _isCanceled = false;
  bool _disposed = false;
  String _measurementId = '';

  // Guards notifyListeners() against firing after the provider is disposed
  // (a speed test resolving its final notify while the user navigates away
  // would otherwise crash with "used after being disposed").
  void _safeNotify() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // Raw samples (pooled exactly like Cloudflare's getBandwidthPoints).
  final List<double> _latencies = [];        // ping in ms
  final List<_Sample> _downloadSamples = [];  // {durationMs, bps}
  final List<_Sample> _uploadSamples = [];

  Dio? _dio;
  CancelToken? _token;

  // ── Endpoints (identical to the reference engine) ───────────────────────────
  static const String _base = 'https://speed.cloudflare.com';
  static const String _downUrl = '$_base/__down';
  static const String _upUrl = '$_base/__up';

  // ── Measurement plan (Cloudflare defaultConfig.measurements) ─────────────────
  // Grouped per UI phase. `bypass` marks the warm-up request that must not count
  // toward the finish threshold (Cloudflare's `bypassMinDuration: true`).
  static const List<Map<String, int>> _latencyPlan = [
    {'numPackets': 1},
    {'numPackets': 20},
  ];
  static const List<_Round> _downloadPlan = [
    _Round(bytes: 100000, count: 1, bypass: true), // initial estimation
    _Round(bytes: 100000, count: 9),
    _Round(bytes: 1000000, count: 8),
    _Round(bytes: 10000000, count: 6),
    _Round(bytes: 25000000, count: 4),
    _Round(bytes: 100000000, count: 3),
    _Round(bytes: 250000000, count: 2),
  ];
  static const List<_Round> _uploadPlan = [
    _Round(bytes: 100000, count: 8),
    _Round(bytes: 1000000, count: 6),
    _Round(bytes: 10000000, count: 4),
    _Round(bytes: 25000000, count: 4),
    _Round(bytes: 50000000, count: 3),
  ];

  // ── Cloudflare default config constants ──────────────────────────────────────
  static const double _bandwidthPercentile = 0.9;
  static const double _latencyPercentile = 0.5;
  static const double _bandwidthMinRequestDuration = 10; // ms
  static const double _bandwidthFinishRequestDuration = 1000; // ms
  static const double _estimatedServerTime = 10; // ms
  static const double _headerFraction = 0.005; // ~0.5% on-wire overhead

  static const int _maxConsecutiveFailures = 3;
  // Safety valve so a single phase can never run unbounded through a slow tunnel
  // (the finish rule already bounds individual requests to ~10 s; this caps the
  // wall-clock of an oversized round in case of high variance).
  static const Duration _roundWallClockCap = Duration(seconds: 25);

  static const Duration _measurementDelay = Duration(milliseconds: 50);
  static const Duration _latencyDelay = Duration(milliseconds: 10);
  static const Duration _phaseTransitionDelay = Duration(milliseconds: 1200);

  // ── Live upload-speed display tuning ─────────────────────────────────────────
  // `onSendProgress` counts bytes handed to the OS socket *send buffer*, not bytes
  // that have crossed the wire. The kernel swallows the first few MB into that
  // buffer almost instantly, so we (1) discard a warm-up period while the buffer
  // fills and (2) report the instantaneous rate over a trailing time window —
  // once the buffer is saturated, dio can only accept a new byte when an older
  // one has actually left the wire, so the windowed rate tracks real throughput.
  static const int _uploadWarmupUs = 300000; // 300 ms — skip the buffer-fill burst
  static const int _uploadWindowUs = 500000; // 500 ms instantaneous window

  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 90);
  static const Duration _sendTimeout = Duration(seconds: 90);

  SpeedTestProvider();

  Dio _createDio() => Dio(BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        headers: {'User-Agent': 'TiksarVPN/SpeedTest'},
      ));

  String _generateMeasurementId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(999999)}';

  // True once this run is no longer the active one — either the user cancelled
  // (`_isCanceled`) or a newer run replaced it (`myId != _measurementId`).
  // A new run resets `_isCanceled` to false, so the id comparison is what stops
  // a stale run (resumed from a non-cancelable `Future.delayed`) from mutating
  // the new run's shared sample buffers / UI state. Checked after every await
  // and wherever `_isCanceled` used to be checked inside the measurement loops.
  bool _isStale(String myId) => _isCanceled || myId != _measurementId;

  // ── Public API ──────────────────────────────────────────────────────────────

  void stopTest() {
    _isCanceled = true;
    _token?.cancel('stopped');
    _dio?.close(force: true);
    _dio = null;
    _latencies.clear();
    _downloadSamples.clear();
    _uploadSamples.clear();
    _state = const SpeedTestState();
    _safeNotify();
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
    // Capture this run's id. A previous run paused at an await could otherwise
    // resume after we reset _isCanceled and corrupt the shared sample buffers;
    // comparing against the live _measurementId makes stale runs bail out.
    final myId = _measurementId;
    _latencies.clear();
    _downloadSamples.clear();
    _uploadSamples.clear();

    _dio = _createDio();
    _token = CancelToken();

    _state = const SpeedTestState(
      step: SpeedTestStep.loading,
      currentPhase: 'Initializing...',
    );
    _safeNotify();
    debugPrint('[SpeedTest] Started');

    try {
      // Phase 1: Latency
      _state = _state.copyWith(
        step: SpeedTestStep.loading,
        currentPhase: 'Measuring latency...',
        progress: 0.0,
        currentSpeed: 0,
      );
      _safeNotify();
      await _runLatencyPhase(myId);
      if (_isStale(myId)) return;

      // Phase 2: Download
      await _transitionTo(SpeedTestStep.download, 'Measuring download...', myId);
      if (_isStale(myId)) return;
      await _runBandwidthPhase(_downloadPlan, _downloadSamples,
          isDownload: true, myId: myId);
      if (_isStale(myId)) return;

      // Phase 3: Upload
      await _transitionTo(SpeedTestStep.upload, 'Measuring upload...', myId);
      if (_isStale(myId)) return;
      await _runBandwidthPhase(_uploadPlan, _uploadSamples,
          isDownload: false, myId: myId);
      if (_isStale(myId)) return;

      _finalize();
      debugPrint(
          '[SpeedTest] Complete: down=${_state.result.downloadSpeed.toStringAsFixed(1)} up=${_state.result.uploadSpeed.toStringAsFixed(1)} Mbps ping=${_state.result.ping}ms');
    } catch (e) {
      debugPrint('[SpeedTest] Error: $e');
      // Don't surface an error (or clobber state) if a newer run has taken over.
      if (!_isStale(myId)) {
        _state = _state.copyWith(
          step: SpeedTestStep.ready,
          errorMessage: 'test_failed',
          hadError: true,
          isConnectionStable: false,
          currentSpeed: 0,
        );
        _safeNotify();
      }
    } finally {
      // Only tear down the dio if THIS run still owns it. A stale run reaching
      // its finally must not close the active run's client out from under it.
      if (!_isStale(myId)) {
        _dio?.close();
        _dio = null;
      }
    }
  }

  // ── Phase transition (Cloudflare-style 1200 ms gap + progress reset) ─────────

  Future<void> _transitionTo(
      SpeedTestStep step, String phase, String myId) async {
    _state = _state.copyWith(progress: 0.0, currentSpeed: 0);
    _safeNotify();
    await Future.delayed(_phaseTransitionDelay);
    if (_isStale(myId)) return;
    _state = _state.copyWith(step: step, currentPhase: phase, progress: 0.0);
    _safeNotify();
  }

  // ── Latency ──────────────────────────────────────────────────────────────────
  // A 0-byte download; ping = max(0.01, ttfb − serverTime).

  Future<void> _runLatencyPhase(String myId) async {
    final total = _latencyPlan.fold<int>(0, (s, g) => s + g['numPackets']!);
    int done = 0;
    int consecutiveFailures = 0;

    for (final group in _latencyPlan) {
      final numPackets = group['numPackets']!;
      for (int i = 0; i < numPackets; i++) {
        if (_isStale(myId)) return;
        try {
          final ping = await _measureLatency(myId);
          if (ping != null && !_isStale(myId)) {
            _latencies.add(ping);
            consecutiveFailures = 0;
            _publishLatency();
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

  Future<double?> _measureLatency(String myId) async {
    final sw = Stopwatch()..start();
    final resp = await _dio!.get<ResponseBody>(
      '$_downUrl?bytes=0&measId=$_measurementId',
      options: Options(
        responseType: ResponseType.stream,
        headers: const {'Cache-Control': 'no-cache, no-store'},
      ),
      cancelToken: _token,
    );
    // The future resolves once response headers arrive → first byte time (ttfb).
    final ttfb = sw.elapsedMicroseconds / 1000.0;
    final serverTime = _parseServerTime(resp.headers);
    // Drain (0 bytes, but make sure the stream completes / connection frees).
    await resp.data!.stream.drain<void>();
    if (_isStale(myId)) return null;
    return math.max(0.01, ttfb - (serverTime ?? _estimatedServerTime));
  }

  // ── Bandwidth (download + upload share the same engine) ──────────────────────

  Future<void> _runBandwidthPhase(
    List<_Round> plan,
    List<_Sample> sink, {
    required bool isDownload,
    required String myId,
  }) async {
    final total = plan.fold<int>(0, (s, r) => s + r.count);
    int done = 0;
    int consecutiveFailures = 0;
    bool finished = false;

    for (final round in plan) {
      if (_isStale(myId)) return;
      if (finished) {
        // Skip larger payloads of this type — but keep progress moving.
        done += round.count;
        _setProgress(done / total);
        continue;
      }

      double roundMinDuration = double.infinity;
      final roundWatch = Stopwatch()..start();

      for (int i = 0; i < round.count; i++) {
        if (_isStale(myId)) return;
        try {
          final sample = isDownload
              ? await _measureDownload(round.bytes, myId)
              : await _measureUpload(round.bytes, myId);

          if (!_isStale(myId) && sample != null) {
            // Cloudflare pools every request whose duration ≥ 10 ms.
            if (sample.durationMs >= _bandwidthMinRequestDuration &&
                sample.bps > 0) {
              sink.add(sample);
            }
            roundMinDuration = math.min(roundMinDuration, sample.durationMs);
            consecutiveFailures = 0;
            _publishBandwidth(sink, isDownload: isDownload);
          }
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) return;
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception(isDownload
                ? 'Network connection lost during download test'
                : 'Network connection lost during upload test');
          }
        } catch (_) {
          consecutiveFailures++;
          if (consecutiveFailures >= _maxConsecutiveFailures) {
            throw Exception(isDownload
                ? 'Network connection lost during download test'
                : 'Network connection lost during upload test');
          }
        }

        done++;
        _setProgress(done / total);
        await Future.delayed(_measurementDelay);

        // Safety valve: bound an oversized round's wall-clock time.
        if (roundWatch.elapsed > _roundWallClockCap) {
          // Count the rest as done so the progress bar still completes.
          done += (round.count - 1 - i);
          _setProgress(done / total);
          finished = true;
          break;
        }
      }

      // Cloudflare finish rule: once the fastest request in a (non-bypass) round
      // exceeds 1000 ms, stop testing larger payloads of this type.
      if (!round.bypass &&
          roundMinDuration.isFinite &&
          roundMinDuration > _bandwidthFinishRequestDuration) {
        finished = true;
      }
    }
  }

  /// Download: duration = (ttfb − serverTime) + payloadDownloadTime.
  Future<_Sample?> _measureDownload(int bytes, String myId) async {
    final sw = Stopwatch()..start();
    final resp = await _dio!.get<ResponseBody>(
      '$_downUrl?bytes=$bytes&measId=$_measurementId&during=download',
      options: Options(
        responseType: ResponseType.stream,
        headers: const {
          'Cache-Control': 'no-cache, no-store',
          'Accept-Encoding': 'identity',
        },
      ),
      cancelToken: _token,
    );
    final ttfb = sw.elapsedMicroseconds / 1000.0; // ms to first byte
    final serverTime = _parseServerTime(resp.headers);

    int received = 0;
    final payloadWatch = Stopwatch()..start();
    DateTime? lastUpdate;

    await for (final chunk in resp.data!.stream) {
      if (_isStale(myId)) break;
      received += chunk.length;

      final elapsed = payloadWatch.elapsedMilliseconds / 1000.0;
      final now = DateTime.now();
      if (elapsed > 0.05 &&
          (lastUpdate == null ||
              now.difference(lastUpdate).inMilliseconds > 100)) {
        _setCurrentSpeed(_roundSpeed((received * 8) / elapsed / 1e6));
        lastUpdate = now;
      }
    }
    final payloadMs = payloadWatch.elapsedMicroseconds / 1000.0;
    sw.stop();
    if (_isStale(myId) || received <= 0) return null;

    final ping = math.max(0.01, ttfb - (serverTime ?? _estimatedServerTime));
    final durationMs = ping + payloadMs;
    if (durationMs <= 0) return null;
    // Match Cloudflare's transferSize: its engine bills the on-wire size
    // (body + headers) via `numBytes * (1 + ESTIMATED_HEADER_FRACTION)`. dio only
    // exposes the decoded body length (`received`), so apply the same ~0.5%
    // header overhead for exact parity with speed.cloudflare.com.
    final bps = (8 * received * (1 + _headerFraction)) / (durationMs / 1000.0);
    return _Sample(durationMs, bps);
  }

  /// Upload: duration = ttfb (the server's first response byte arrives only
  /// after it has received the whole body). bps = 8·bytes·1.005 / duration.
  Future<_Sample?> _measureUpload(int bytes, String myId) async {
    // A fixed zero-filled buffer — instantaneous to allocate, unlike the old
    // per-byte random generation that throttled uploads to CPU speed.
    final payload = Uint8List(bytes);
    final sw = Stopwatch()..start();

    // Live-display state (see _uploadWarmupUs / _uploadWindowUs above). We must
    // NOT use the naive cumulative `sent/elapsed` rate here: it counts bytes
    // buffered by the kernel, not bytes on the wire, and spikes wildly at the
    // start of every request. Instead we ignore a warm-up burst, then publish
    // the instantaneous rate over a trailing window.
    bool warmedUp = false;
    int windowStartSent = 0;
    int windowStartUs = 0;
    DateTime? lastUpdate;

    await _dio!.post(
      '$_upUrl?bytes=$bytes&measId=$_measurementId&during=upload',
      data: Stream<List<int>>.fromIterable(_chunked(payload)),
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': bytes,
          'Cache-Control': 'no-cache, no-store',
        },
      ),
      onSendProgress: (sent, t) {
        if (_isStale(myId)) return;
        final nowUs = sw.elapsedMicroseconds;

        // Phase 1: let the socket send buffer fill before trusting any reading.
        if (!warmedUp) {
          if (nowUs < _uploadWarmupUs) return;
          warmedUp = true;
          windowStartSent = sent;
          windowStartUs = nowUs;
          return;
        }

        // Phase 2: accumulate a full window, then publish its instantaneous rate.
        final windowUs = nowUs - windowStartUs;
        if (windowUs < _uploadWindowUs) return;

        final deltaBytes = sent - windowStartSent;
        final now = DateTime.now();
        if (deltaBytes > 0 &&
            (lastUpdate == null ||
                now.difference(lastUpdate!).inMilliseconds > 100)) {
          final mbps = (deltaBytes * 8) / (windowUs / 1e6) / 1e6;
          _setCurrentSpeed(_roundSpeed(mbps));
          lastUpdate = now;
        }
        // Slide the window forward.
        windowStartSent = sent;
        windowStartUs = nowUs;
      },
      cancelToken: _token,
    );
    sw.stop();
    if (_isStale(myId)) return null;

    final durationMs = sw.elapsedMicroseconds / 1000.0;
    if (durationMs <= 0) return null;
    final bits = 8 * bytes * (1 + _headerFraction);
    final bps = bits / (durationMs / 1000.0);
    return _Sample(durationMs, bps);
  }

  // Stream the upload body in 64 KB chunks so dio applies socket backpressure
  // instead of dumping the whole buffer into the send queue at once.
  static const int _chunkSize = 65536;
  Iterable<List<int>> _chunked(Uint8List data) sync* {
    int offset = 0;
    while (offset < data.length) {
      final end = math.min(offset + _chunkSize, data.length);
      yield Uint8List.sublistView(data, offset, end);
      offset = end;
    }
  }

  double? _parseServerTime(Headers headers) {
    final v = headers.value('server-timing');
    if (v == null) return null;
    final m = RegExp(r'(?:^|;)\s*dur=([0-9.]+)').firstMatch(v);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  // ── Publish helpers ───────────────────────────────────────────────────────────

  void _setProgress(double p) {
    _state = _state.copyWith(progress: p.clamp(0.0, 1.0));
    _safeNotify();
  }

  void _setCurrentSpeed(double v) {
    _state = _state.copyWith(currentSpeed: v);
    _safeNotify();
  }

  void _publishLatency() {
    if (_latencies.isEmpty) return;
    _state = _state.copyWith(
      result: _state.result.copyWith(
        ping: _percentile(_latencies, _latencyPercentile).round(),
        latency: _percentile(_latencies, _latencyPercentile).round(),
        jitter: _computeJitter(),
      ),
    );
    _safeNotify();
  }

  void _publishBandwidth(List<_Sample> samples, {required bool isDownload}) {
    final mbps = _bandwidthMbps(samples);
    if (isDownload) {
      _state = _state.copyWith(
        currentSpeed: mbps,
        result: _state.result.copyWith(downloadSpeed: mbps),
      );
    } else {
      _state = _state.copyWith(
        currentSpeed: mbps,
        result: _state.result.copyWith(uploadSpeed: mbps),
      );
    }
    _safeNotify();
  }

  // ── Finalize ────────────────────────────────────────────────────────────────

  void _finalize() {
    final down = _bandwidthMbps(_downloadSamples);
    final up = _bandwidthMbps(_uploadSamples);
    final ping = _latencies.isEmpty
        ? 0
        : _percentile(_latencies, _latencyPercentile).round();
    final jitter = _computeJitter();
    final packetLoss = _computePacketLoss();
    final stable = packetLoss < 5.0 && down > 0.1 && up > 0.1;

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
        latency: ping,
        jitter: jitter,
        packetLoss: packetLoss,
      ),
    );
    _safeNotify();
  }

  // ── Stats helpers (match Cloudflare exactly) ──────────────────────────────────

  /// 90th-percentile bandwidth in Mbps, pooled over every qualifying request.
  double _bandwidthMbps(List<_Sample> samples) {
    final bps = samples
        .where((s) => s.durationMs >= _bandwidthMinRequestDuration && s.bps > 0)
        .map((s) => s.bps)
        .toList();
    if (bps.isEmpty) return 0.0;
    return _percentile(bps, _bandwidthPercentile) / 1e6;
  }

  /// Linear-interpolation percentile on rank (N−1)·p — identical to the
  /// reference engine's `percentile()` (NumPy default method).
  double _percentile(List<double> values, double perc) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final idx = (sorted.length - 1) * perc;
    final lo = idx.floor();
    final hi = idx.ceil();
    if (lo == hi) return sorted[lo];
    final rem = idx - lo;
    return sorted[lo] + (sorted[hi] - sorted[lo]) * rem;
  }

  /// Mean of absolute differences between consecutive pings.
  int _computeJitter() {
    if (_latencies.length < 2) return 0;
    double sum = 0;
    for (int i = 1; i < _latencies.length; i++) {
      sum += (_latencies[i] - _latencies[i - 1]).abs();
    }
    return (sum / (_latencies.length - 1)).round();
  }

  /// Cloudflare measures packet loss over a WebRTC/TURN channel, which has no
  /// HTTP equivalent. We approximate it from the fraction of latency probes that
  /// failed to return.
  double _computePacketLoss() {
    final expected = _latencyPlan.fold<int>(0, (s, g) => s + g['numPackets']!);
    if (expected <= 10) return 0.0;
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
    _disposed = true;
    _isCanceled = true;
    _token?.cancel('disposed');
    _dio?.close(force: true);
    _dio = null;
    super.dispose();
  }
}

/// One bandwidth measurement: how long the request took and its bits/second.
class _Sample {
  final double durationMs;
  final double bps;
  const _Sample(this.durationMs, this.bps);
}

/// One entry of a bandwidth measurement plan.
class _Round {
  final int bytes;
  final int count;
  final bool bypass; // bypassMinDuration — excluded from the finish rule
  const _Round({required this.bytes, required this.count, this.bypass = false});
}
