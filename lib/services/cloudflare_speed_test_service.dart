import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/speed_test_state.dart';

class CloudflareSpeedTestService {
  final Dio _dio = Dio();
  bool _isCancelled = false;
  Timer? _testTimer;
  
  // Measurement ID for Cloudflare logging
  String _measurementId = '';
  
  // Results storage
  final List<double> _downloadSpeeds = [];
  final List<double> _uploadSpeeds = [];
  final List<int> _latencies = [];
  
  // Test durations
  static const int downloadDurationSeconds = 30;
  static const int uploadDurationSeconds = 30;
  static const int pingTestCount = 5;
  
  // Current test phase tracking
  DateTime? _phaseStartTime;
  
  // Public getters for accessing results during test
  List<int> get latencies => _latencies;
  List<double> get downloadSpeeds => _downloadSpeeds;
  List<double> get uploadSpeeds => _uploadSpeeds;
  
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
  
  /// Reset all test data
  void _resetTestData() {
    _downloadSpeeds.clear();
    _uploadSpeeds.clear();
    _latencies.clear();
    _phaseStartTime = null;
    _testTimer?.cancel();
    _testTimer = null;
  }
  
  /// Start complete speed test - Time-based: Ping → 30s Download → 30s Upload
  Future<void> startTest({
    required Function(TestPhase phase, double progress) onPhaseChange,
    required Function(double speed) onSpeedUpdate,
    required Function(SpeedTestResult result) onComplete,
    required Function(String error) onError,
  }) async {
    // Reset everything on new test
    _isCancelled = false;
    _resetTestData();
    _measurementId = _generateMeasurementId();
    
    try {
      debugPrint('🚀 Speed Test Started - ID: $_measurementId');
      
      // Phase 1: Real Ping Test
      debugPrint('📡 Phase 1: Testing Ping...');
      onPhaseChange(TestPhase.loading, 0.0);
      await _runRealPingTest(onPhaseChange);
      
      if (_isCancelled) return;
      
      // Phase 2: 30 Second Download Test
      debugPrint('📥 Phase 2: Testing Download (30s)...');
      onPhaseChange(TestPhase.download, 0.0);
      await _run30SecondDownloadTest(onPhaseChange, onSpeedUpdate);
      
      if (_isCancelled) return;
      
      // Immediate transition to upload test
      debugPrint('📤 Phase 3: Testing Upload (30s)...');
      onPhaseChange(TestPhase.upload, 0.0);
      // Small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));
      await _run30SecondUploadTest(onPhaseChange, onSpeedUpdate);
      
      if (_isCancelled) return;
      
      // Calculate final results
      final result = _calculateFinalResults();
      
      debugPrint('🏁 Speed test completed: ${result.toString()}');
      onComplete(result);
      
    } catch (e) {
      debugPrint('❌ Speed test error: $e');
      if (!_isCancelled) {
        onError(e.toString());
      }
    } finally {
      _testTimer?.cancel();
    }
  }
  
  /// Run real ping test
  Future<void> _runRealPingTest(
    Function(TestPhase phase, double progress) onPhaseChange,
  ) async {
    for (int i = 0; i < pingTestCount; i++) {
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
        
        debugPrint('   🏓 Ping ${i + 1}/$pingTestCount: $latency ms');
        
        // Update progress
        onPhaseChange(TestPhase.loading, (i + 1) / pingTestCount);
      } catch (e) {
        debugPrint('   ❌ Ping test failed: $e');
      }
      
      // Small delay between pings
      if (i < pingTestCount - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
  
  /// Run 30-second download test with continuous measurement
  Future<void> _run30SecondDownloadTest(
    Function(TestPhase phase, double progress) onPhaseChange,
    Function(double speed) onSpeedUpdate,
  ) async {
    _phaseStartTime = DateTime.now();
    final endTime = _phaseStartTime!.add(Duration(seconds: downloadDurationSeconds));
    
    // Start progress timer
    _testTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final elapsed = now.difference(_phaseStartTime!).inMilliseconds / 1000.0;
      final progress = (elapsed / downloadDurationSeconds).clamp(0.0, 1.0);
      onPhaseChange(TestPhase.download, progress);
    });
    
    // Keep downloading until 30 seconds
    int downloadAttempts = 0;
    while (DateTime.now().isBefore(endTime) && !_isCancelled) {
      downloadAttempts++;
      debugPrint('   🔄 Download attempt $downloadAttempts');
      
      try {
        // Download a chunk (3MB for faster iterations)
        final speed = await _measureDownloadSpeed(
          bytes: 3000000,
          onSpeedUpdate: onSpeedUpdate,
        );
        
        if (speed > 0) {
          _downloadSpeeds.add(speed);
          debugPrint('   📥 Download speed: ${speed.toStringAsFixed(2)} Mbps');
        } else {
          debugPrint('   ⚠️ Download returned 0 speed');
        }
      } catch (e) {
        debugPrint('   ⚠️ Download chunk failed: $e');
        // Continue testing even if one chunk fails
        // Add small delay on error to prevent rapid retries
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // No delay between successful downloads to maximize testing
    }
    
    _testTimer?.cancel();
    onPhaseChange(TestPhase.download, 1.0);
    
    debugPrint('✅ Download test completed: ${_downloadSpeeds.length} measurements');
  }
  
  /// Run 30-second upload test with continuous measurement
  Future<void> _run30SecondUploadTest(
    Function(TestPhase phase, double progress) onPhaseChange,
    Function(double speed) onSpeedUpdate,
  ) async {
    _phaseStartTime = DateTime.now();
    final endTime = _phaseStartTime!.add(Duration(seconds: uploadDurationSeconds));
    
    // Start progress timer
    _testTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final elapsed = now.difference(_phaseStartTime!).inMilliseconds / 1000.0;
      final progress = (elapsed / uploadDurationSeconds).clamp(0.0, 1.0);
      onPhaseChange(TestPhase.upload, progress);
    });
    
    // Keep uploading until 30 seconds
    int uploadAttempts = 0;
    while (DateTime.now().isBefore(endTime) && !_isCancelled) {
      uploadAttempts++;
      debugPrint('   🔄 Upload attempt $uploadAttempts');
      
      try {
        // Upload a chunk (3MB for faster iterations)
        final speed = await _measureUploadSpeed(
          bytes: 3000000,
          onSpeedUpdate: onSpeedUpdate,
        );
        
        if (speed > 0) {
          _uploadSpeeds.add(speed);
          debugPrint('   📤 Upload speed: ${speed.toStringAsFixed(2)} Mbps');
        } else {
          debugPrint('   ⚠️ Upload returned 0 speed');
        }
      } catch (e) {
        debugPrint('   ⚠️ Upload chunk failed: $e');
        // Continue testing even if one chunk fails
        // Add small delay on error to prevent rapid retries
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // No delay between successful uploads to maximize testing
    }
    
    _testTimer?.cancel();
    onPhaseChange(TestPhase.upload, 1.0);
    
    debugPrint('✅ Upload test completed: ${_uploadSpeeds.length} measurements');
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
  
  /// Measure single upload speed
  Future<double> _measureUploadSpeed({
    required int bytes,
    required Function(double speed) onSpeedUpdate,
  }) async {
    if (_isCancelled) return 0.0;
    
    try {
      debugPrint('      🔧 Generating ${(bytes / 1000000).toStringAsFixed(1)}MB upload data...');
      
      // Generate random data very efficiently (fill with pattern instead of random for speed)
      final data = Uint8List(bytes);
      // Fill with a repeating pattern (faster than random, still valid for upload test)
      for (int i = 0; i < bytes; i += 8) {
        data[i] = 0xFF;
        if (i + 1 < bytes) data[i + 1] = 0xAA;
        if (i + 2 < bytes) data[i + 2] = 0x55;
        if (i + 3 < bytes) data[i + 3] = 0x00;
        if (i + 4 < bytes) data[i + 4] = 0xCC;
        if (i + 5 < bytes) data[i + 5] = 0x33;
        if (i + 6 < bytes) data[i + 6] = 0x99;
        if (i + 7 < bytes) data[i + 7] = 0x66;
      }
      
      debugPrint('      🚀 Starting upload to Cloudflare...');
      final startTime = DateTime.now();
      DateTime? lastUpdateTime;
      int lastSent = 0;
      bool progressCallbackCalled = false;
      
<<<<<<< HEAD
      // Split data into smaller chunks for better live progress tracking
      const chunkSize = 64 * 1024; // 64KB chunks for smooth progress
      List<List<int>> chunks = [];
      for (int i = 0; i < bytes; i += chunkSize) {
        final end = (i + chunkSize < bytes) ? i + chunkSize : bytes;
        chunks.add(data.sublist(i, end));
      }
      debugPrint('      📦 Split into ${chunks.length} chunks for live progress');
      
=======
>>>>>>> 0230e278905dde01d89da8d30ca9ae07e94600a9
      await _dio.post(
        '/__up',
        data: Stream.fromIterable(chunks),
        queryParameters: {
          'measId': _measurementId,
          'during': 'upload',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytes.toString(),
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        onSendProgress: (sent, total) {
          if (!progressCallbackCalled) {
            debugPrint('      ✅ Upload progress callback working! sent=$sent, total=$total');
            progressCallbackCalled = true;
          }
          
          if (_isCancelled) return;
          
          final now = DateTime.now();
          final elapsed = now.difference(startTime).inMilliseconds / 1000.0;
          
          // Update speed more frequently for live display
          if (elapsed > 0.01 && sent > lastSent) {
            final speedMbps = (sent * 8) / (elapsed * 1000000);
            
            // Update every 50ms for smooth live display
            if (lastUpdateTime == null || now.difference(lastUpdateTime!).inMilliseconds > 50) {
              onSpeedUpdate(speedMbps);
              lastUpdateTime = now;
              lastSent = sent;
              
              // Log less frequently to avoid spam (every 10%)
              if (sent % (bytes ~/ 10) < 100000 || sent == total) {
                debugPrint('         📊 Upload: ${(sent / bytes * 100).toStringAsFixed(0)}% - ${speedMbps.toStringAsFixed(2)} Mbps');
              }
            }
          }
        },
      );
      
      if (!progressCallbackCalled) {
        debugPrint('      ⚠️ WARNING: Upload progress callback was NEVER called!');
      }
      
      if (_isCancelled) return 0.0;
      
      final duration = DateTime.now().difference(startTime);
      final durationSeconds = duration.inMilliseconds / 1000.0;
      
      debugPrint('      ✅ Upload completed in ${durationSeconds.toStringAsFixed(2)}s');
      
      if (durationSeconds < 0.01) {
        debugPrint('      ⚠️ Upload too fast, duration: $durationSeconds');
        return 0.0;
      }
      
      final mbps = (bytes * 8) / (durationSeconds * 1000000);
      debugPrint('      📈 Final upload speed: ${mbps.toStringAsFixed(2)} Mbps');
      
      // If progress callback wasn't called, at least update with final speed
      if (!progressCallbackCalled && mbps > 0) {
        debugPrint('      🔧 Updating UI with final speed since progress callback failed');
        onSpeedUpdate(mbps);
      }
      
      return mbps;
    } catch (e, stackTrace) {
      debugPrint('   ❌ Upload error: $e');
      debugPrint('   📋 Stack trace: $stackTrace');
      throw Exception('Upload failed: $e');
    }
  }
  
  /// Calculate final results - accurate median with outlier removal
  SpeedTestResult _calculateFinalResults() {
    // Use median instead of 90th percentile for more accurate results
    // Remove outliers (top and bottom 10%) for better accuracy
    final downloadSpeed = _downloadSpeeds.isNotEmpty
        ? _calculateAccurateSpeed(_downloadSpeeds)
        : 0.0;
    
    final uploadSpeed = _uploadSpeeds.isNotEmpty
        ? _calculateAccurateSpeed(_uploadSpeeds)
        : 0.0;
    
    // Calculate median ping (more accurate than average)
    final ping = _latencies.isNotEmpty
        ? _calculatePercentile(_latencies.map((e) => e.toDouble()).toList(), 0.5).round()
        : 0;
    
    // Calculate jitter (standard deviation of latencies)
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
  
  /// Calculate accurate speed by removing outliers and using median
  double _calculateAccurateSpeed(List<double> speeds) {
    if (speeds.isEmpty) return 0.0;
    if (speeds.length < 3) return speeds.reduce((a, b) => a + b) / speeds.length;
    
    // Sort speeds
    final sorted = List<double>.from(speeds)..sort();
    
    // Remove outliers (bottom 10% and top 10%)
    final outlierCount = (sorted.length * 0.1).ceil();
    final filteredSpeeds = sorted.sublist(
      outlierCount,
      sorted.length - outlierCount,
    );
    
    // Return median of filtered speeds
    return _calculatePercentile(filteredSpeeds, 0.5);
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
    _testTimer?.cancel();
    _testTimer = null;
    debugPrint('🛑 Speed test cancelled');
  }
  
  /// Dispose
  void dispose() {
    _testTimer?.cancel();
    _dio.close();
  }
}


