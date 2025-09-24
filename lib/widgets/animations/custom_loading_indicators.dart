import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Pulse loading animation
class PulseLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final int itemCount;

  const PulseLoadingIndicator({
    Key? key,
    this.size = 50,
    this.color,
    this.itemCount = 3,
  }) : super(key: key);

  @override
  State<PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<PulseLoadingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.itemCount,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.itemCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: widget.size / 3,
                height: widget.size / 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.color ?? Theme.of(context).primaryColor)
                      .withOpacity(0.3 + (_animations[index].value * 0.7)),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Wave loading animation
class WaveLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final int itemCount;

  const WaveLoadingIndicator({
    Key? key,
    this.size = 40,
    this.color,
    this.itemCount = 5,
  }) : super(key: key);

  @override
  State<WaveLoadingIndicator> createState() => _WaveLoadingIndicatorState();
}

class _WaveLoadingIndicatorState extends State<WaveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animations = List.generate(widget.itemCount, (index) {
      final delay = index * 0.1;
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay,
            0.7 + delay,
            curve: Curves.easeInOutSine,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 2,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.itemCount, (index) {
              return Transform.translate(
                offset: Offset(0, -widget.size * 0.5 * _animations[index].value),
                child: Container(
                  width: widget.size / widget.itemCount,
                  height: widget.size / 3,
                  decoration: BoxDecoration(
                    color: widget.color ?? Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(widget.size / 6),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Rotating arc loading indicator
class ArcLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const ArcLoadingIndicator({
    Key? key,
    this.size = 40,
    this.color,
    this.strokeWidth = 3,
  }) : super(key: key);

  @override
  State<ArcLoadingIndicator> createState() => _ArcLoadingIndicatorState();
}

class _ArcLoadingIndicatorState extends State<ArcLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ArcPainter(
              color: widget.color ?? Theme.of(context).primaryColor,
              strokeWidth: widget.strokeWidth,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double progress;

  _ArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw the arc
    final startAngle = progress * 2 * math.pi;
    final sweepAngle = math.pi * 0.75;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Morphing dots loading
class MorphingDotsIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const MorphingDotsIndicator({
    Key? key,
    this.size = 40,
    this.color,
  }) : super(key: key);

  @override
  State<MorphingDotsIndicator> createState() => _MorphingDotsIndicatorState();
}

class _MorphingDotsIndicatorState extends State<MorphingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 2,
          height: widget.size,
          child: CustomPaint(
            painter: _MorphingDotsPainter(
              color: widget.color ?? Theme.of(context).primaryColor,
              progress: _animation.value,
            ),
          ),
        );
      },
    );
  }
}

class _MorphingDotsPainter extends CustomPainter {
  final Color color;
  final double progress;

  _MorphingDotsPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final dotRadius = size.height / 6;
    final spacing = size.width / 4;

    for (int i = 0; i < 3; i++) {
      final x = spacing * (i + 0.5);
      final scale = 1.0 + (math.sin((progress + i * 0.2) * 2 * math.pi) * 0.3);
      
      canvas.save();
      canvas.translate(x, centerY);
      canvas.scale(scale, scale);
      canvas.drawCircle(Offset.zero, dotRadius, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MorphingDotsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
