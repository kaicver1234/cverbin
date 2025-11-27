import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_colors.dart';
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Row(
            children: [
              Text(
                'Tiksar ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bottomGradientConnected,
                ),
              ),
              Text(
                _getHeaderText(state),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            _getSubHeaderText(context, state),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderText(SpeedTestState state) {
    switch (state.step) {
      case SpeedTestStep.loading:
      case SpeedTestStep.testing:
        return 'is';
      case SpeedTestStep.completed:
      case SpeedTestStep.error:
        return 'has';
      default:
        return 'is ready';
    }
  }

  String _getSubHeaderText(BuildContext context, SpeedTestState state) {
    switch (state.step) {
      case SpeedTestStep.testing:
      case SpeedTestStep.loading:
        return AppLocalizations.of(context).translate('speed_test.testing_speed');
      case SpeedTestStep.completed:
        return AppLocalizations.of(context).translate('speed_test.completed_test');
      case SpeedTestStep.error:
        return AppLocalizations.of(context).translate('speed_test.encountered_error');
      default:
        return AppLocalizations.of(context).translate('speed_test.to_speed_test');
    }
  }

  Widget _buildContent(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSpeedGauge(state),
          const SizedBox(height: 30),
          if (state.step != SpeedTestStep.ready) _buildMetrics(state),
          const SizedBox(height: 30),
          _buildActionButton(context, provider, state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorMessage(state.errorMessage!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(SpeedTestState state) {
    return SizedBox(
      width: 280,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background arc
          CustomPaint(
            size: const Size(280, 200),
            painter: _SpeedArcPainter(
              progress: 0,
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 8,
            ),
          ),
          // Download progress arc (outer)
          if ((state.step == SpeedTestStep.testing || state.step == SpeedTestStep.loading) &&
              state.currentPhase == TestPhase.download)
            CustomPaint(
              size: const Size(280, 200),
              painter: _SpeedArcPainter(
                progress: state.progress,
                color: AppColors.downloadColor,
                strokeWidth: 8,
              ),
            ),
          // Upload progress arc (inner)
          if ((state.step == SpeedTestStep.testing || state.step == SpeedTestStep.loading) &&
              state.currentPhase == TestPhase.upload)
            CustomPaint(
              size: const Size(250, 180),
              painter: _SpeedArcPainter(
                progress: state.progress,
                color: AppColors.uploadColor,
                strokeWidth: 6,
              ),
            ),
          // Center content
          Positioned(
            top: 60,
            child: Column(
              children: [
                Text(
                  _getSpeedValue(state),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getSpeedUnit(state),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Pulse animation when ready
          if (state.step == SpeedTestStep.ready)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1 + (_pulseController.value * 0.1),
                  child: Opacity(
                    opacity: 1 - _pulseController.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bottomGradientConnected,
                          width: 2,
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

  String _getSpeedValue(SpeedTestState state) {
    if (state.step == SpeedTestStep.ready) {
      return 'GO';
    } else if (state.step == SpeedTestStep.testing) {
      if (state.currentPhase == TestPhase.loading) {
        return '${state.result.ping}';
      }
      return state.currentSpeed.toStringAsFixed(1);
    } else {
      return state.result.downloadSpeed.toStringAsFixed(1);
    }
  }

  String _getSpeedUnit(SpeedTestState state) {
    if (state.step == SpeedTestStep.ready) {
      return AppLocalizations.of(context).translate('speed_test.tap_to_start');
    } else if (state.step == SpeedTestStep.testing) {
      if (state.currentPhase == TestPhase.loading) {
        return 'ms - Ping';
      } else if (state.currentPhase == TestPhase.download) {
        return 'Mbps - Download';
      }
      return 'Mbps - Upload';
    }
    return 'Mbps';
  }

  Widget _buildMetrics(SpeedTestState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            icon: Icons.download,
            label: AppLocalizations.of(context).translate('speed_test.download'),
            value: state.result.downloadSpeed.toStringAsFixed(1),
            unit: 'Mbps',
            color: AppColors.downloadColor,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildMetricItem(
            icon: Icons.upload,
            label: AppLocalizations.of(context).translate('speed_test.upload'),
            value: state.result.uploadSpeed.toStringAsFixed(1),
            unit: 'Mbps',
            color: AppColors.uploadColor,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildMetricItem(
            icon: Icons.speed,
            label: AppLocalizations.of(context).translate('speed_test.ping'),
            value: '${state.result.ping}',
            unit: 'ms',
            color: AppColors.warningColor,
          ),
        ],
      ),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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

  Widget _buildActionButton(
      BuildContext context, SpeedTestProvider provider, SpeedTestState state) {
    final isTesting = state.step == SpeedTestStep.testing || state.step == SpeedTestStep.loading;

    return GestureDetector(
      onTap: () {
        if (isTesting) {
          provider.stopTest();
        } else {
          provider.startTest();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isTesting
                ? [Colors.red.shade600, Colors.red.shade800]
                : [
                    AppColors.bottomGradientConnected,
                    AppColors.middleGradientConnected
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isTesting
                ? AppLocalizations.of(context).translate('speed_test.stop_test')
                : state.step == SpeedTestStep.completed
                    ? AppLocalizations.of(context)
                        .translate('speed_test.start_test')
                    : AppLocalizations.of(context)
                        .translate('speed_test.start_test'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for speed arc
class _SpeedArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _SpeedArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    final startAngle = math.pi;
    final sweepAngle = math.pi * progress;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeedArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
