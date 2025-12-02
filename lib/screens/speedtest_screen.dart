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
  late AnimationController _downloadArcController;
  late AnimationController _uploadArcController;
  late AnimationController _pulseController;
  late AnimationController _gridController;

  late Animation<double> _downloadArcAnimation;
  late Animation<double> _uploadArcAnimation;

  double _targetDownloadProgress = 0.0;
  double _targetUploadProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _downloadArcController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _uploadArcController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _gridController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _downloadArcAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _downloadArcController, curve: Curves.easeInOut),
    );
    _uploadArcAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _uploadArcController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _downloadArcController.dispose();
    _uploadArcController.dispose();
    _pulseController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  void _updateProgress(SpeedTestState state) {
    double newDownload = 0.0;
    double newUpload = 0.0;

    if (state.step == SpeedTestStep.download) {
      newDownload = state.progress;
      newUpload = 0.0;
    } else if (state.step == SpeedTestStep.upload) {
      newDownload = 0.0;
      newUpload = state.progress;
    } else if (state.testCompleted) {
      newDownload = 1.0;
      newUpload = 1.0;
    }

    if (newDownload != _targetDownloadProgress) {
      _downloadArcAnimation = Tween<double>(
        begin: _downloadArcAnimation.value,
        end: newDownload,
      ).animate(CurvedAnimation(
        parent: _downloadArcController,
        curve: newDownload < _targetDownloadProgress ? Curves.easeOutCubic : Curves.easeInOut,
      ));
      _downloadArcController.duration = Duration(
        milliseconds: newDownload < _targetDownloadProgress ? 1200 : 400,
      );
      _downloadArcController.forward(from: 0);
      _targetDownloadProgress = newDownload;
    }

    if (newUpload != _targetUploadProgress) {
      _uploadArcAnimation = Tween<double>(
        begin: _uploadArcAnimation.value,
        end: newUpload,
      ).animate(CurvedAnimation(
        parent: _uploadArcController,
        curve: newUpload < _targetUploadProgress ? Curves.easeOutCubic : Curves.easeInOut,
      ));
      _uploadArcController.duration = Duration(
        milliseconds: newUpload < _targetUploadProgress ? 1200 : 400,
      );
      _uploadArcController.forward(from: 0);
      _targetUploadProgress = newUpload;
    }
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
                _updateProgress(state);

                return Column(
                  children: [
                    _buildHeader(context, state),
                    Expanded(
                      child: _buildContent(context, provider, state),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SpeedTestState state) {
    final tr = AppLocalizations.of(context);

    final isRunning = state.step != SpeedTestStep.ready;
    final hasError = state.hadError && state.errorMessage != null;
    final isCompleted = state.testCompleted && state.step == SpeedTestStep.ready;

    String title;
    String subtitle;

    if (isRunning) {
      title = tr.translate('speed_test.title_testing');
      subtitle = tr.translate('speed_test.subtitle_testing');
    } else if (hasError) {
      title = tr.translate('speed_test.title_error');
      subtitle = tr.translate('speed_test.subtitle_error');
    } else if (isCompleted) {
      title = tr.translate('speed_test.title_completed');
      subtitle = tr.translate('speed_test.subtitle_completed');
    } else {
      title = tr.translate('speed_test.title_ready');
      subtitle = tr.translate('speed_test.subtitle_ready');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 30),
          _buildProgressIndicator(state, provider),
          const Spacer(),
          if (state.result.ping > 0 || state.testCompleted)
            _buildMetricsDisplay(state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(SpeedTestState state, SpeedTestProvider provider) {
    return SizedBox(
      width: 320,
      height: 280,
      child: AnimatedBuilder(
        animation: Listenable.merge([_downloadArcAnimation, _uploadArcAnimation, _gridController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // Upload Arc (inner - blue)
              CustomPaint(
                size: const Size(230, 160),
                painter: _SemicircularProgressPainter(
                  progress: _uploadArcAnimation.value,
                  color: const Color(0xFF3B82F6),
                  strokeWidth: 3,
                ),
              ),
              // Download Arc (outer - green)
              CustomPaint(
                size: const Size(270, 180),
                painter: _SemicircularProgressPainter(
                  progress: _downloadArcAnimation.value,
                  color: const Color(0xFF10B981),
                  strokeWidth: 4,
                ),
              ),
              // Animated Grid
              Positioned(
                top: 200,
                child: CustomPaint(
                  size: const Size(300, 40),
                  painter: _AnimatedGridPainter(
                    animation: _gridController.value,
                  ),
                ),
              ),
              // Center Content
              Positioned(
                top: 80,
                child: _buildCenterContent(state, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterContent(SpeedTestState state, SpeedTestProvider provider) {
    final tr = AppLocalizations.of(context);
    final isRunning = state.step == SpeedTestStep.download || state.step == SpeedTestStep.upload;
    final isLoading = state.step == SpeedTestStep.loading;
    final isCompleted = state.testCompleted && state.step == SpeedTestStep.ready;
    final hasError = state.hadError && state.errorMessage != null && state.step == SpeedTestStep.ready;

    // Error state
    if (hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.8), size: 40),
          const SizedBox(height: 8),
          Text(
            state.errorMessage ?? tr.translate('speed_test.error_message'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _buildRetryButton(provider),
        ],
      );
    }

    // Loading state (ping test)
    if (isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${tr.translate('speed_test.ping')}: ${state.result.ping} ${tr.translate('speed_test.ms')}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      );
    }

    // Running state (download/upload)
    if (isRunning) {
      final isDownload = state.step == SpeedTestStep.download;
      final color = isDownload ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
      final label = isDownload
          ? tr.translate('speed_test.download')
          : tr.translate('speed_test.upload');

      return GestureDetector(
        onTap: () => provider.stopTest(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.currentSpeed.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr.translate('speed_test.mbps'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    // Completed state
    if (isCompleted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.result.downloadSpeed.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr.translate('speed_test.mbps'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          _buildRetryButton(provider),
        ],
      );
    }

    // Ready state - Start button
    return _buildStartButton(provider, tr);
  }

  Widget _buildStartButton(SpeedTestProvider provider, AppLocalizations tr) {
    return GestureDetector(
      onTap: () => provider.startTest(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr.translate('speed_test.tap_here'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(60, 60),
                painter: _RadialLinesPainter(
                  progress: _pulseController.value,
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: 0.5,
                    child: const Icon(
                      Icons.near_me_outlined,
                      color: Colors.white,
                      size: 22,
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

  Widget _buildRetryButton(SpeedTestProvider provider) {
    return GestureDetector(
      onTap: () => provider.startTest(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.cached_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildMetricsDisplay(SpeedTestState state) {
    final tr = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Download
          Expanded(
            child: _buildMetricItem(
              icon: Icons.download_rounded,
              label: tr.translate('speed_test.download'),
              value: state.result.downloadSpeed.toStringAsFixed(1),
              unit: tr.translate('speed_test.mbps'),
              color: const Color(0xFF10B981),
            ),
          ),
          _buildDivider(),
          // Upload
          Expanded(
            child: _buildMetricItem(
              icon: Icons.upload_rounded,
              label: tr.translate('speed_test.upload'),
              value: state.result.uploadSpeed.toStringAsFixed(1),
              unit: tr.translate('speed_test.mbps'),
              color: const Color(0xFF3B82F6),
            ),
          ),
          _buildDivider(),
          // Ping
          Expanded(
            child: _buildMetricItem(
              icon: Icons.network_ping,
              label: tr.translate('speed_test.ping'),
              value: state.result.ping.toString(),
              unit: tr.translate('speed_test.ms'),
              color: Colors.white,
            ),
          ),
          _buildDivider(),
          // Jitter
          Expanded(
            child: _buildMetricItem(
              icon: Icons.swap_vert,
              label: tr.translate('speed_test.jitter'),
              value: state.result.jitter.toString(),
              unit: tr.translate('speed_test.ms'),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Custom Painters
// ============================================================================

class _SemicircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _SemicircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - strokeWidth / 2;

    const startAngle = math.pi * 0.85;
    const sweepAngle = math.pi * 1.3;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
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

      // Progress arc
      final progressPaint = Paint()
        ..color = color
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

      // Dot at end
      final angle = startAngle + (sweepAngle * progress);
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(dotX, dotY), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SemicircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _AnimatedGridPainter extends CustomPainter {
  final double animation;

  _AnimatedGridPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    // Horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines with animation
    final numLines = 12;
    for (int i = 0; i <= numLines; i++) {
      final baseX = size.width * i / numLines;
      final offset = math.sin((animation * 2 * math.pi) + (i * 0.3)) * 3;
      final x = baseX + offset;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_AnimatedGridPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

class _RadialLinesPainter extends CustomPainter {
  final double progress;

  _RadialLinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 + (progress * 0.4))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final angles = [
      math.pi * 0.875,
      math.pi,
      math.pi * 1.125,
      math.pi * 1.25,
      math.pi * 1.375,
      math.pi * 1.5,
      math.pi * 1.625,
    ];

    for (final angle in angles) {
      final startRadius = radius * 0.6 + (progress * radius * 0.15);
      final endRadius = radius * 0.75 + (progress * radius * 0.2);

      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + endRadius * math.cos(angle);
      final endY = center.dy + endRadius * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(_RadialLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
