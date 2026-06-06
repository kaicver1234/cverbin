import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A modern, minimal circular speed gauge with smooth animated arc,
/// gradient stroke, soft glow, and centered numeric readout.
class ModernSpeedGauge extends StatefulWidget {
  final double value;        // current measured value
  final double maxValue;     // scale max (e.g. 100 Mbps)
  final String unit;         // e.g. "Mbps"
  final String? label;       // e.g. "DOWNLOAD"
  final Color color;
  final double size;
  final bool isIdle;         // pulsing idle animation
  final Widget? centerOverlay; // optional widget shown instead of number (e.g. start button)

  const ModernSpeedGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.color,
    this.unit = 'Mbps',
    this.label,
    this.size = 280,
    this.isIdle = false,
    this.centerOverlay,
  });

  @override
  State<ModernSpeedGauge> createState() => _ModernSpeedGaugeState();
}

class _ModernSpeedGaugeState extends State<ModernSpeedGauge>
    with TickerProviderStateMixin {
  late AnimationController _arcController;
  late AnimationController _pulseController;
  late Animation<double> _arcAnim;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arcAnim = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _animateTo(_computeProgress());
  }

  double _computeProgress() {
    if (widget.maxValue <= 0) return 0.0;
    return (widget.value / widget.maxValue).clamp(0.0, 1.0);
  }

  void _animateTo(double target) {
    _arcAnim = Tween<double>(begin: _previousProgress, end: target).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeOutCubic),
    );
    _previousProgress = target;
    _arcController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant ModernSpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newProgress = _computeProgress();
    if ((newProgress - _previousProgress).abs() > 0.001 ||
        widget.maxValue != oldWidget.maxValue) {
      _animateTo(newProgress);
    }
  }

  @override
  void dispose() {
    _arcController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_arcAnim, _pulseController]),
        builder: (context, _) {
          final pulse = widget.isIdle
              ? 0.6 + (_pulseController.value * 0.4)
              : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer soft glow
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.10 * pulse),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Track + progress arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  progress: _arcAnim.value,
                  color: widget.color,
                ),
              ),
              // Center content
              if (widget.centerOverlay != null)
                widget.centerOverlay!
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.label != null) ...[
                      Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
                          color: widget.color.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      _formatValue(widget.value),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.unit,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.45),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = math.pi * 0.75; // bottom-left
    const sweepTotal = math.pi * 1.5;  // 270 degrees

    // Track (background ring)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);

    // Subtle tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const tickCount = 30;
    for (int i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = startAngle + sweepTotal * t;
      final outer = Offset(
        center.dx + (radius - 18) * math.cos(angle),
        center.dy + (radius - 18) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - 24) * math.cos(angle),
        center.dy + (radius - 24) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (progress <= 0) return;

    // Gradient progress arc
    final sweep = sweepTotal * progress;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [
          color.withValues(alpha: 0.4),
          color,
        ],
        tileMode: TileMode.clamp,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);

    // Glow head at arc tip
    final headAngle = startAngle + sweep;
    final headOffset = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(headOffset, 8, glowPaint);
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(headOffset, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
