import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        body: VPNGradientBackground(
          child: SafeArea(
            child: Consumer<SpeedTestProvider>(
              builder: (context, provider, child) {
                final state = provider.state;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 45),
                      _buildHeader(context, state),
                      const SizedBox(height: 30),
                      Expanded(
                        child: _buildContent(context, provider, state),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context, SpeedTestState state) {
    String upperText;
    String bottomText;

    // Check states based on available SpeedTestStep values
    final isTestRunning = state.step == SpeedTestStep.loading || 
                          state.step == SpeedTestStep.download || 
                          state.step == SpeedTestStep.upload;
    final isCompleted = state.testCompleted && state.step == SpeedTestStep.ready;
    final hasError = state.hadError && state.errorMessage != null;

    if (isTestRunning) {
      upperText = 'is';
      bottomText = AppLocalizations.of(context).translate('speed_test.testing_speed');
    } else if (hasError) {
      upperText = 'has';
      bottomText = AppLocalizations.of(context).translate('speed_test.encountered_error');
    } else if (isCompleted) {
      upperText = 'has';
      bottomText = AppLocalizations.of(context).translate('speed_test.completed_test');
    } else {
      upperText = 'is ready';
      bottomText = AppLocalizations.of(context).translate('speed_test.to_speed_test');
    }

    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'T',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Text(
                    'iksar ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    upperText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                bottomText,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    return Column(
      children: [
        // Progress Indicator with Arcs
        Expanded(
          child: _buildProgressIndicator(state, provider),
        ),
        // Metrics Display
        if ((state.step != SpeedTestStep.ready || state.testCompleted) && state.result.ping > 0)
          _buildMetricsDisplay(state),
        const SizedBox(height: 20),
      ],
    );
  }


  Widget _buildProgressIndicator(SpeedTestState state, SpeedTestProvider provider) {
    // Determine progress for each arc based on current step
    double downloadProgress = 0.0;
    double uploadProgress = 0.0;

    if (state.step == SpeedTestStep.download) {
      downloadProgress = state.progress;
    } else if (state.step == SpeedTestStep.upload) {
      downloadProgress = 1.0; // Download completed
      uploadProgress = state.progress;
    } else if (state.testCompleted) {
      downloadProgress = 1.0;
      uploadProgress = 1.0;
    }

    return SizedBox(
      width: 350,
      height: 380,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Upload Arc (inner)
          CustomPaint(
            size: const Size(250, 190),
            painter: SemicircularProgressPainter(
              progress: uploadProgress,
              color: const Color(0xFF3B82F6), // Blue for upload
              strokeWidth: 3,
            ),
          ),
          // Download Arc (outer)
          CustomPaint(
            size: const Size(280, 190),
            painter: SemicircularProgressPainter(
              progress: downloadProgress,
              color: const Color(0xFF10B981), // Green for download
              strokeWidth: 3,
            ),
          ),

          // Center Content
          Positioned(
            top: 80,
            child: _buildCenterContent(state, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent(SpeedTestState state, SpeedTestProvider provider) {
    final isTestRunning = state.step == SpeedTestStep.download || 
                          state.step == SpeedTestStep.upload;
    final isCompleted = state.testCompleted && state.step == SpeedTestStep.ready;
    final hasError = state.hadError && state.errorMessage != null && state.step == SpeedTestStep.ready;

    if (state.step == SpeedTestStep.ready && !isCompleted && !hasError) {
      // Ready state - show start button
      return _buildStartButton(provider);
    } else if (state.step == SpeedTestStep.loading) {
      // Loading state (measuring latency)
      final tr = AppLocalizations.of(context);
      return Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${tr.translate('speed_test.ping')}: ${state.result.ping} ${tr.translate('speed_test.ms')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (isTestRunning) {
      // Testing state - show current speed
      return _buildSpeedDisplay(state, provider);
    } else if (hasError) {
      // Error state
      return _buildErrorContent(state, provider);
    } else if (isCompleted) {
      // Completed state - show retry button
      return _buildCompletedContent(state, provider);
    } else {
      // Default - show start button
      return _buildStartButton(provider);
    }
  }


  Widget _buildStartButton(SpeedTestProvider provider) {
    final tr = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => provider.startTest(),
      child: Column(
        children: [
          Text(
            tr.translate('speed_test.tap_here'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              final opacity = 0.7 + (_pulseController.value * 0.3);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: 15 / 3.14,
                      child: Icon(
                        Icons.near_me_outlined,
                        color: Colors.white.withValues(alpha: opacity),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDisplay(SpeedTestState state, SpeedTestProvider provider) {
    final tr = AppLocalizations.of(context);
    final isDownload = state.step == SpeedTestStep.download;
    final color = isDownload ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final label = isDownload 
        ? tr.translate('speed_test.download') 
        : tr.translate('speed_test.upload');

    return GestureDetector(
      onTap: () => provider.stopTest(),
      child: Column(
        children: [
          Text(
            state.currentSpeed.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr.translate('speed_test.mbps'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          // Stop button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text(
                  tr.translate('speed_test.stop'),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCompletedContent(SpeedTestState state, SpeedTestProvider provider) {
    final tr = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          state.result.downloadSpeed.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr.translate('speed_test.mbps'),
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        // Retry button
        GestureDetector(
          onTap: () => provider.startTest(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.cached_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(SpeedTestState state, SpeedTestProvider provider) {
    final tr = AppLocalizations.of(context);
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          color: Colors.red.withValues(alpha: 0.8),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          state.errorMessage ?? tr.translate('speed_test.error_message'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => provider.startTest(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: Text(
              tr.translate('speed_test.retry'),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMetricsDisplay(SpeedTestState state) {
    final tr = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left column - Download & Ping
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricItem(
                label: tr.translate('speed_test.download'),
                value: state.result.downloadSpeed,
                unit: tr.translate('speed_test.mbps'),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _buildMetricItemSmall(
                label: tr.translate('speed_test.ping'),
                value: state.result.ping.toDouble(),
                unit: tr.translate('speed_test.ms'),
              ),
            ],
          ),
          // Right column - Upload & Jitter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricItem(
                label: tr.translate('speed_test.upload'),
                value: state.result.uploadSpeed,
                unit: tr.translate('speed_test.mbps'),
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 12),
              _buildMetricItemSmall(
                label: tr.translate('speed_test.jitter'),
                value: state.result.jitter.toDouble(),
                unit: tr.translate('speed_test.ms'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required double value,
    required String unit,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItemSmall({
    required String label,
    required double value,
    required String unit,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${value.toStringAsFixed(0)} $unit',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


// ============================================================================
// Custom Painters
// ============================================================================

/// Semicircular progress arc painter
class SemicircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SemicircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - strokeWidth / 2;

    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;

    // Background arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    if (progress > 0) {
      // Shadow
      final shadowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        shadowPaint,
      );

      // Progress arc with gradient
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [color, color, color.withValues(alpha: 0.8)],
          startAngle: startAngle,
          endAngle: startAngle + (sweepAngle * progress),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );

      // Progress indicator dot
      final angle = startAngle + (sweepAngle * progress);
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      final dotPosition = Offset(dotX, dotY);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(dotPosition, 5.0, glowPaint);

      // Dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotPosition, 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(SemicircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}



