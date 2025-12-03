import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/speed_test_provider.dart';
import '../models/speed_test_state.dart';
import '../widgets/vpn_gradient_background.dart';
import '../utils/app_localizations.dart';
import 'dart:math' as math;

class SpeedTestScreen extends StatelessWidget {
  const SpeedTestScreen({super.key});

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
                return Column(
                  children: [
                    _buildHeader(context, provider.state),
                    Expanded(
                      child: _buildContent(context, provider),
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
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.translate('speed_test.title_ready'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusText(state, tr),
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SpeedTestState state, AppLocalizations tr) {
    if (state.step == SpeedTestStep.loading) return tr.translate('speed_test.measuring_latency');
    if (state.step == SpeedTestStep.download) return tr.translate('speed_test.download_test');
    if (state.step == SpeedTestStep.upload) return tr.translate('speed_test.upload_test');
    if (state.testCompleted) return tr.translate('speed_test.test_completed');
    if (state.hadError) return tr.translate('speed_test.subtitle_error');
    return tr.translate('speed_test.subtitle_ready');
  }

  Widget _buildContent(BuildContext context, SpeedTestProvider provider) {
    final state = provider.state;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          _SpeedGauge(state: state, provider: provider),
          const Spacer(),
          if (state.result.ping > 0 || state.testCompleted) _ResultsCard(state: state),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SpeedGauge extends StatefulWidget {
  final SpeedTestState state;
  final SpeedTestProvider provider;

  const _SpeedGauge({required this.state, required this.provider});

  @override
  State<_SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<_SpeedGauge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isIdle = state.step == SpeedTestStep.ready && !state.testCompleted && !state.hadError;
    final isRunning = state.step != SpeedTestStep.ready;
    final isCompleted = state.testCompleted && state.step == SpeedTestStep.ready;
    final hasError = state.hadError;
    final tr = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () {
        if (isRunning) {
          widget.provider.stopTest();
        } else {
          widget.provider.startTest();
        }
      },
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring with gradient
            if (isRunning) _buildProgressRing(state),
            
            // Main circle
            _buildMainCircle(isRunning, isCompleted, hasError, state),
            
            // Center content
            _buildCenterContent(state, isIdle, isRunning, isCompleted, hasError, tr),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(SpeedTestState state) {
    final isDownload = state.step == SpeedTestStep.download;
    final color = isDownload ? const Color(0xFF10B981) : const Color(0xFF3B82F6);

    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: state.progress,
          color: color,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildMainCircle(bool isRunning, bool isCompleted, bool hasError, SpeedTestState state) {
    Color bgColor;
    if (hasError) {
      bgColor = Colors.red.withValues(alpha: 0.1);
    } else if (isRunning) {
      bgColor = state.step == SpeedTestStep.download
          ? const Color(0xFF10B981).withValues(alpha: 0.12)
          : const Color(0xFF3B82F6).withValues(alpha: 0.12);
    } else if (isCompleted) {
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
    } else {
      bgColor = Colors.white.withValues(alpha: 0.05);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
    );
  }

  Widget _buildCenterContent(SpeedTestState state, bool isIdle, bool isRunning, bool isCompleted, bool hasError, AppLocalizations tr) {
    if (hasError) {
      return _buildErrorContent(state, tr);
    }
    if (state.step == SpeedTestStep.loading) {
      return _buildLoadingContent(state, tr);
    }
    if (isRunning) {
      return _buildRunningContent(state, tr);
    }
    if (isCompleted) {
      return _buildCompletedContent(state, tr);
    }
    return _buildIdleContent(tr);
  }

  Widget _buildIdleContent(AppLocalizations tr) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.06);
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFF10B981).withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 45, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                tr.translate('speed_test.go'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingContent(SpeedTestState state, AppLocalizations tr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text(
          '${state.result.ping} ${tr.translate('speed_test.ms')}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white),
        ),
        Text(
          tr.translate('speed_test.ping'),
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildRunningContent(SpeedTestState state, AppLocalizations tr) {
    final isDownload = state.step == SpeedTestStep.download;
    final color = isDownload ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final label = isDownload ? tr.translate('speed_test.download') : tr.translate('speed_test.upload');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state.currentSpeed.toStringAsFixed(1),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300, color: Colors.white, height: 1),
        ),
        Text(
          tr.translate('speed_test.mbps'),
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isDownload ? Icons.download_rounded : Icons.upload_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedContent(SpeedTestState state, AppLocalizations tr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 50, color: Color(0xFF10B981)),
        const SizedBox(height: 12),
        Text(
          state.result.downloadSpeed.toStringAsFixed(1),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Colors.white),
        ),
        Text(
          tr.translate('speed_test.mbps'),
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => widget.provider.startTest(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(SpeedTestState state, AppLocalizations tr) {
    final errorKey = state.errorMessage ?? 'test_failed';
    final errorMsg = tr.translate('speed_test.$errorKey');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 40, color: Colors.red.withValues(alpha: 0.8)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            errorMsg,
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => widget.provider.startTest(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tr.translate('speed_test.retry'),
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ArcPainter({required this.progress, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -math.pi / 2;
    const sweepAngle = 2 * math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ResultsCard extends StatelessWidget {
  final SpeedTestState state;

  const _ResultsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _ResultItem(
            icon: Icons.download_rounded,
            label: tr.translate('speed_test.download'),
            value: state.result.downloadSpeed.toStringAsFixed(1),
            unit: tr.translate('speed_test.mbps'),
            color: const Color(0xFF10B981),
          ),
          _buildDivider(),
          _ResultItem(
            icon: Icons.upload_rounded,
            label: tr.translate('speed_test.upload'),
            value: state.result.uploadSpeed.toStringAsFixed(1),
            unit: tr.translate('speed_test.mbps'),
            color: const Color(0xFF3B82F6),
          ),
          _buildDivider(),
          _ResultItem(
            icon: Icons.network_ping,
            label: tr.translate('speed_test.ping'),
            value: state.result.ping.toString(),
            unit: tr.translate('speed_test.ms'),
            color: Colors.white,
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
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700)),
          Text(unit, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        ],
      ),
    );
  }
}
