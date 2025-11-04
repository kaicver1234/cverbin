import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Cloudflare Speed Test Service
/// Exactly like defyxVPN - uses official Cloudflare speed.cloudflare.com API
class CloudflareSpeedTestService {
  final Dio _dio = Dio();
  bool _isCancelled = false;
  
  // Measurement ID for Cloudflare logging
  String _measurementId = '';
  
  // Results storage
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];
  
  // Measurement configuration - exactly like defyxVPN
  static const List<Map<String, dynamic>> measurements = [
    {'type': 'latency', 'numPackets': 1},
    {'type': 'download', 'bytes': 100000, 'count': 1},
    {'type': 'latency', 'numPackets': 20},
    {'type': 'download', 'bytes': 100000, 'count': 9},
    {'type': 'download', 'bytes': 1000000, 'count': 8},
    {'type': 'upload', 'bytes': 100000, 'count': 8},
    {'type': 'upload', 'bytes': 1000000, 'count': 6},
    {'type': 'download', 'bytes': 10000000, 'count': 6},
  ];
  
  CloudflareSpeedTestService() {
    _dio.options.baseUrl = 'https://speed.cloudflare.com';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 60);
    _dio.options.headers['User-Agent'] = 'Tiksar VPN Speed Test';
  }
  
  /// Generate measurement ID
  String _generateMeasurementId() {
    return (Random().nextDouble() * 1e16).round().toString();
  }
  
  /// Start complete speed test - exactly like defyxVPN
  Future<void> startTest({
    required Function(TestPhase phase, double progress) onPhaseChange,
    required Function(double speed) onSpeedUpdate,
    required Function(SpeedTestResult result) onComplete,
    required Function(String error) onError,
  }) async {
    _isCancelled = false;
    _measurementId = _generateMeasurementId();
    
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();
    
    try {
      debugPrint('🚀 Cloudflare Speed Test Started - ID: $_measurementId');
      
      // Run measurement sequence
      await _runMeasurementSequence(
        onPhaseChange: onPhaseChange,
        onSpeedUpdate: onSpeedUpdate,
      );
      
      if (_isCancelled) {
        debugPrint('🛑 Speed test cancelled');
        return;
      }
      
      // Calculate final results
      final result = _calculateFinalResults();
      
      debugPrint('🏁 Speed test completed: ${result.toString()}');
      onComplete(result);
      
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      if (!_isCancelled) {
        onError(e.toString());
      }
    }
  }
  
  /// Run measurement sequence - exactly like defyxVPN
  Future<void> _runMeasurementSequence({
    required Function(TestPhase phase, double progress) onPhaseChange,
    required Function(double speed) onSpeedUpdate,
  }) async {
    TestPhase currentPhase = TestPhase.loading;
    int totalSteps = measurements.length;
    
    for (int i = 0; i < measurements.length; i++) {
      if (_isCancelled) return;
      
      final measurement = measurements[i];
      final type = measurement['type'] as String;
      
      // Check if we need to change phase
      TestPhase? nextPhase;
      if (type == 'latency' && currentPhase != TestPhase.loading) {
        nextPhase = TestPhase.loading;
      } else if (type == 'download' && currentPhase != TestPhase.download) {
        nextPhase = TestPhase.download;
      } else if (type == 'upload' && currentPhase != TestPhase.upload) {
        nextPhase = TestPhase.upload;
      }
      
      if (nextPhase != null) {
        currentPhase = nextPhase;
        onPhaseChange(currentPhase, 0.0);
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      debugPrint('📊 Step ${i + 1}/$totalSteps: $type');
      
      // Run measurement based on type
      switch (type) {
        case 'latency':
          await _runLatencyMeasurement(measurement);
          break;
        case 'download':
          await _runDownloadMeasurement(
            measurement,
            onSpeedUpdate: onSpeedUpdate,
            onPhaseProgress: (p) => onPhaseChange(currentPhase, p),
          );
          break;
        case 'upload':
          await _runUploadMeasurement(
            measurement,
            onSpeedUpdate: onSpeedUpdate,
            onPhaseProgress: (p) => onPhaseChange(currentPhase, p),
          );
          break;
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
  
  /// Test latency - exactly like defyxVPN
  Future<void> _runLatencyMeasurement(Map<String, dynamic> config) async {
    final numPackets = config['numPackets'] as int;
    
    for (int i = 0; i < numPackets; i++) {
      if (_isCancelled) return;
      
      try {
        final stopwatch = Stopwatch()..start();
        
        await _dio.get(
          '/__down',
          queryParameters: {
            'bytes': 0,
            'measId': _measurementId,
          },
        );
        
        stopwatch.stop();
        final latency = stopwatch.elapsedMilliseconds;
        _latencies.add(latency);
        
        debugPrint('   🏓 Ping: $latency ms');
      } catch (e) {
        debugPrint('   ❌ Latency test failed: $e');
      }
      
      if (i < numPackets - 1) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }
  
  /// Test download speed - exactly like defyxVPN
  Future<void> _runDownloadMeasurement(
    Map<String, dynamic> config, {
    required Function(double speed) onSpeedUpdate,
    required Function(double progress) onPhaseProgress,
  }) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    
    for (int i = 0; i < count; i++) {
      if (_isCancelled) return;
      
      try {
        final speed = await _measureDownloadSpeed(
          bytes: bytes,
          onSpeedUpdate: onSpeedUpdate,
        );
        
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          
          // Calculate 90th percentile (like defyxVPN)
          final percentile = _calculatePercentile(_downloadSpeeds, 0.9);
          debugPrint('   📥 Download ${i + 1}/$count: ${speed.toStringAsFixed(2)} Mbps (90th: ${percentile.toStringAsFixed(2)} Mbps)');
        }
        
        onPhaseProgress((i + 1) / count);
      } catch (e) {
        debugPrint('   ❌ Download test ${i + 1} failed: $e');
      }
    }
  }
  
  /// Measure single download speed
  Future<double> _measureDownloadSpeed({
    required int bytes,
    required Function(double speed) onSpeedUpdate,
  }) async {
    if (_isCancelled) return 0.0;
    
    try {
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;
      
      final response = await _dio.get(
        '/__down',
        queryParameters: {
          'bytes': bytes,
          'measId': _measurementId,
          'during': 'download',
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;
          
          if (!_isCancelled &&
              elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final speedMbps = (received * 8) / (elapsed * 1000000);
            onSpeedUpdate(speedMbps);
            lastUpdateTime = now;
          }
        },
      );
      
      if (_isCancelled) return 0.0;
      
      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;
      
      if (durationSeconds < 0.01) return 0.0;
      
      final actualBytes = (response.data as List<int>).length;
      final mbps = (actualBytes * 8) / (durationSeconds * 1000000);
      
      return mbps;
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }
  
  /// Test upload speed - exactly like defyxVPN
  Future<void> _runUploadMeasurement(
    Map<String, dynamic> config, {
    required Function(double speed) onSpeedUpdate,
    required Function(double progress) onPhaseProgress,
  }) async {
    final bytes = config['bytes'] as int;
    final count = config['count'] as int;
    
    for (int i = 0; i < count; i++) {
      if (_isCancelled) return;
      
      try {
        final speed = await _measureUploadSpeed(
          bytes: bytes,
          onSpeedUpdate: onSpeedUpdate,
        );
        
        if (speed > 0) {
          _uploadSpeeds.add(speed);
          
          // Calculate 90th percentile (like defyxVPN)
          final percentile = _calculatePercentile(_uploadSpeeds, 0.9);
          debugPrint('   📤 Upload ${i + 1}/$count: ${speed.toStringAsFixed(2)} Mbps (90th: ${percentile.toStringAsFixed(2)} Mbps)');
        }
        
        onPhaseProgress((i + 1) / count);
      } catch (e) {
        debugPrint('   ❌ Upload test ${i + 1} failed: $e');
      }
    }
  }
  
  /// Measure single upload speed
  Future<double> _measureUploadSpeed({
    required int bytes,
    required Function(double speed) onSpeedUpdate,
  }) async {
    if (_isCancelled) return 0.0;
    
    try {
      // Generate random data
      final data = List.generate(bytes, (index) => Random().nextInt(256));
      
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;
      
      await _dio.post(
        '/__up',
        data: Stream.fromIterable([data]),
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
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;
          
          if (!_isCancelled &&
              elapsed > 0.05 &&
              (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 100)) {
            final speedMbps = (sent * 8) / (elapsed * 1000000);
            onSpeedUpdate(speedMbps);
            lastUpdateTime = now;
          }
        },
      );
      
      if (_isCancelled) return 0.0;
      
      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;
      
      if (durationSeconds < 0.01) return 0.0;
      
      final mbps = (bytes * 8) / (durationSeconds * 1000000);
      
      return mbps;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }
  
  /// Calculate final results - exactly like defyxVPN (90th percentile)
  SpeedTestResult _calculateFinalResults() {
    // Calculate 90th percentile for download & upload (like defyxVPN)
    final downloadSpeed = _downloadSpeeds.isNotEmpty
        ? _calculatePercentile(_downloadSpeeds, 0.9)
        : 0.0;
    
    final uploadSpeed = _uploadSpeeds.isNotEmpty
        ? _calculatePercentile(_uploadSpeeds, 0.9)
        : 0.0;
    
    // Calculate average ping
    final ping = _latencies.isNotEmpty
        ? (_latencies.reduce((a, b) => a + b) / _latencies.length).round()
        : 0;
    
    // Calculate jitter
    int jitter = 0;
    if (_latencies.length >= 2) {
      int jitterSum = 0;
      for (int i = 1; i < _latencies.length; i++) {
        jitterSum += (_latencies[i] - _latencies[i - 1]).abs();
      }
      jitter = (jitterSum / (_latencies.length - 1)).round();
    }
    
    return SpeedTestResult(
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      ping: ping,
      jitter: jitter,
    );
  }
  
  /// Calculate percentile - exactly like defyxVPN
  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<double>.from(values)..sort();
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
  
  /// Cancel test
  void cancelTest() {
    _isCancelled = true;
    debugPrint('🛑 Speed test cancelled');
  }
  
  /// Dispose
  void dispose() {
    _dio.close();
  }
}

/// Test phases
enum TestPhase {
  loading,   // Latency test
  download,  // Download test
  upload,    // Upload test
}

/// Speed test result
class SpeedTestResult {
  final double downloadSpeed; // Mbps (90th percentile)
  final double uploadSpeed;   // Mbps (90th percentile)
  final int ping;            // ms (average)
  final int jitter;          // ms
  
  const SpeedTestResult({
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.ping = 0,
    this.jitter = 0,
  });
  
  @override
  String toString() {
    return 'SpeedTestResult(download: ${downloadSpeed.toStringAsFixed(2)} Mbps, '
           'upload: ${uploadSpeed.toStringAsFixed(2)} Mbps, '
           'ping: $ping ms, jitter: $jitter ms)';
  }
}
