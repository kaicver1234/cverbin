import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Monochrome gauge — pure white on the dark app background. No accent hues.
const Color _kBrand = Colors.white;

/// A clean, minimal circular speed gauge inspired by speedtest.net: a simple
/// 270° dial with evenly spaced ticks, a single-colour progress arc, and a
/// centered numeric readout.
///
/// The numeric readout follows the arc animation so the digits tick smoothly
/// instead of snapping to the latest sampled value.
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
  // Track the last interpolated progress so an in-flight animation that gets
  // interrupted continues smoothly from its CURRENT visual position rather
  // than snapping to the previous target.
  double _currentProgress = 0.0;

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
    _arcAnim = Tween<double>(begin: _currentProgress, end: target).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeOutCubic),
    )..addListener(() {
        _currentProgress = _arcAnim.value;
      });
    _arcController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant ModernSpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newProgress = _computeProgress();
    if ((newProgress - _arcAnim.value).abs() > 0.001 ||
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
          // Smoothly interpolate the displayed numeric value alongside the arc
          // so the digits don't pop on each provider sample.
          final animatedValue = _arcAnim.value * widget.maxValue;
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
                      color: _kBrand.withValues(alpha: 0.10 * pulse),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Track + ticks + progress arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(progress: _arcAnim.value),
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
                          color: _kBrand.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      _formatValue(animatedValue),
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

  _GaugePainter({required this.progress});

  static const _color = _kBrand;

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
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);

    if (progress <= 0) return;

    // Single-colour progress arc.
    final sweep = sweepTotal * progress;
    final progressPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);

    // Soft glowing head at the arc tip.
    final headAngle = startAngle + sweep;
    final headOffset = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    final glowPaint = Paint()
      ..color = _color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(headOffset, 7, glowPaint);
    canvas.drawCircle(headOffset, 4.5, Paint()..color = _color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
