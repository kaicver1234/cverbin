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
  late AnimationController _needleController;
  late AnimationController _pulseController;
  double _currentNeedleAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _needleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Convert speed to angle (0-1000 Mbps range)
  double _speedToAngle(double speed) {
    // Logarithmic scale like speedtest.net
    // 0 -> -135°, 1000 -> 135°
    if (speed <= 0) return -135.0;
    
    // Use log scale for better visualization
    final logSpeed = math.log(speed + 1) / math.log(1001);
    return -135.0 + (logSpeed * 270.0);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C3C),
        body: VPNGradientBackground(
          child: SafeArea(
            child: Consumer<SpeedTestProvider>(
              builder: (context, provider, child) {
                final state = provider.state;
                
                // Update needle angle
                final targetAngle = _speedToAngle(state.currentSpeed);
                if (targetAngle != _currentNeedleAngle) {
                  _currentNeedleAngle = targetAngle;
                }
                
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
          Text(
            AppLocalizations.of(context).translate('speed_test.title_ready'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
          const Spacer(flex: 1),
          _buildSpeedometer(context, provider, state),
          const Spacer(flex: 1),
          _buildResultsRow(context, state),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSpeedometer(BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    final tr = AppLocalizations.of(context);
    final isRunning = state.step != SpeedTestStep.ready;
    final isCompleted = state.testCompleted && !isRunning;
    final hasError = state.hadError && state.errorMessage != null && !isRunning;

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gauge background with scale
          CustomPaint(
            size: const Size(300, 300),
            painter: _SpeedometerPainter(
              progress: isRunning ? state.progress : (isCompleted ? 1.0 : 0.0),
              isDownload: state.step == SpeedTestStep.download,
              isUpload: state.step == SpeedTestStep.upload,
            ),
          ),
          
          // Needle
          if (isRunning || isCompleted)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: -135, end: _speedToAngle(state.currentSpeed)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, angle, child) {
                return CustomPaint(
                  size: const Size(300, 300),
                  painter: _NeedlePainter(angle: angle),
                );
              },
            ),
          
          // Center content
          _buildCenterContent(context, provider, state, tr, isRunning, isCompleted, hasError),
        ],
      ),
    );
  }

  Widget _buildCenterContent(
    BuildContext context,
    SpeedTestProvider provider,
    SpeedTestState state,
    AppLocalizations tr,
    bool isRunning,
    bool isCompleted,
    bool hasError,
  ) {
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
          _buildGoButton(provider, tr, isRetry: true),
        ],
      );
    }

    // Running state
    if (isRunning) {
      final isDownload = state.step == SpeedTestStep.download;
      final isUpload = state.step == SpeedTestStep.upload;
      final isLoading = state.step == SpeedTestStep.loading;

      return GestureDetector(
        onTap: () => provider.stopTest(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed value
            Text(
              isLoading ? '---' : state.currentSpeed.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: -2,
              ),
            ),
            // Mbps label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  tr.translate('speed_test.mbps'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Current phase indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (isDownload ? const Color(0xFF00D4AA) : isUpload ? const Color(0xFF00B4D8) : Colors.grey)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLoading 
                    ? tr.translate('speed_test.ping')
                    : isDownload 
                        ? tr.translate('speed_test.download')
                        : tr.translate('speed_test.upload'),
                style: TextStyle(
                  color: isDownload ? const Color(0xFF00D4AA) : isUpload ? const Color(0xFF00B4D8) : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
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
            state.result.downloadSpeed.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                tr.translate('speed_test.mbps'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGoButton(provider, tr, isRetry: true),
        ],
      );
    }

    // Ready state - GO button
    return _buildGoButton(provider, tr);
  }

  Widget _buildGoButton(SpeedTestProvider provider, AppLocalizations tr, {bool isRetry = false}) {
    return GestureDetector(
      onTap: () => provider.startTest(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = isRetry ? 1.0 : 1.0 + (_pulseController.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: isRetry ? 60 : 120,
              height: isRetry ? 60 : 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF00D4AA).withValues(alpha: 0.9),
                    const Color(0xFF00B4D8).withValues(alpha: 0.9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: isRetry
                    ? const Icon(Icons.refresh_rounded, color: Colors.white, size: 28)
                    : Text(
                        tr.translate('speed_test.go'),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsRow(BuildContext context, SpeedTestState state) {
    final tr = AppLocalizations.of(context);
    final showResults = state.result.ping > 0 || state.testCompleted;

    if (!showResults) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Ping
          Expanded(
            child: _buildResultItem(
              icon: Icons.network_ping,
              label: tr.translate('speed_test.ping'),
              value: '${state.result.ping}',
              unit: tr.translate('speed_test.ms'),
              color: Colors.white,
            ),
          ),
          _buildDivider(),
          // Download
          Expanded(
            child: _buildResultItem(
              icon: Icons.download_rounded,
              label: tr.translate('speed_test.download'),
              value: state.result.downloadSpeed.toStringAsFixed(1),
              unit: tr.translate('speed_test.mbps'),
              color: const Color(0xFF00D4AA),
            ),
          ),
          _buildDivider(),
          // Upload
          Expanded(
            child: _buildResultItem(
              icon: Icons.upload_rounded,
              label: tr.translate('speed_test.upload'),
              value: state.result.uploadSpeed.toStringAsFixed(1),
              unit: tr.translate('speed_test.mbps'),
              color: const Color(0xFF00B4D8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Speedometer gauge painter (like speedtest.net)
class _SpeedometerPainter extends CustomPainter {
  final double progress;
  final bool isDownload;
  final bool isUpload;

  _SpeedometerPainter({
    required this.progress,
    required this.isDownload,
    required this.isUpload,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw scale marks and numbers
    _drawScale(canvas, center, radius);
    
    // Draw progress arc
    if (progress > 0) {
      _drawProgressArc(canvas, center, radius - 15);
    }
  }

  void _drawScale(Canvas canvas, Offset center, double radius) {
    final scaleValues = [0, 5, 10, 50, 100, 250, 500, 750, 1000];
    
    for (int i = 0; i < scaleValues.length; i++) {
      final value = scaleValues[i];
      // Calculate angle using log scale
      final logValue = value == 0 ? 0.0 : math.log(value + 1) / math.log(1001);
      final angle = -135.0 + (logValue * 270.0);
      final radians = angle * math.pi / 180;

      // Draw tick mark
      final innerRadius = radius - 10;
      final outerRadius = radius;
      
      final startX = center.dx + innerRadius * math.cos(radians);
      final startY = center.dy + innerRadius * math.sin(radians);
      final endX = center.dx + outerRadius * math.cos(radians);
      final endY = center.dy + outerRadius * math.sin(radians);

      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      // Draw number
      final textRadius = radius - 25;
      final textX = center.dx + textRadius * math.cos(radians);
      final textY = center.dy + textRadius * math.sin(radians);

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
      );
    }

    // Draw background arc
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 15),
      -135 * math.pi / 180,
      270 * math.pi / 180,
      false,
      arcPaint,
    );
  }

  void _drawProgressArc(Canvas canvas, Offset center, double radius) {
    final color = isDownload 
        ? const Color(0xFF00D4AA) 
        : isUpload 
            ? const Color(0xFF00B4D8) 
            : Colors.grey;

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -135 * math.pi / 180,
      270 * progress * math.pi / 180,
      false,
      glowPaint,
    );

    // Main arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -135 * math.pi / 180,
        endAngle: 135 * math.pi / 180,
        colors: [
          color.withValues(alpha: 0.6),
          color,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -135 * math.pi / 180,
      270 * progress * math.pi / 180,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_SpeedometerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDownload != isDownload ||
        oldDelegate.isUpload != isUpload;
  }
}

/// Needle painter
class _NeedlePainter extends CustomPainter {
  final double angle;

  _NeedlePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radians = angle * math.pi / 180;
    final needleLength = size.width / 2 - 50;

    // Needle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final shadowEnd = Offset(
      center.dx + needleLength * math.cos(radians) + 2,
      center.dy + needleLength * math.sin(radians) + 2,
    );
    canvas.drawLine(center, shadowEnd, shadowPaint);

    // Needle
    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + needleLength * math.cos(radians),
      center.dy + needleLength * math.sin(radians),
    );
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, dotPaint);

    final innerDotPaint = Paint()
      ..color = const Color(0xFF1C1C3C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, innerDotPaint);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
