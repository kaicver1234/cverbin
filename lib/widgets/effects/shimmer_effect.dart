import 'package:flutter/material.dart';

/// Shimmer loading effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final ShimmerDirection direction;

  const ShimmerEffect({
    Key? key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    this.direction = ShimmerDirection.ltr,
  }) : super(key: key);

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ?? 
        (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDarkMode ? Colors.grey[500]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: widget.direction == ShimmerDirection.ltr
                  ? Alignment(-1.0 + _animation.value, 0)
                  : Alignment(0, -1.0 + _animation.value),
              end: widget.direction == ShimmerDirection.ltr
                  ? Alignment(-0.5 + _animation.value, 0)
                  : Alignment(0, -0.5 + _animation.value),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

enum ShimmerDirection { ltr, ttb }

/// Glow effect widget
class GlowEffect extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final Duration duration;
  final bool animate;

  const GlowEffect({
    Key? key,
    required this.child,
    required this.glowColor,
    this.glowRadius = 10,
    this.duration = const Duration(seconds: 2),
    this.animate = true,
  }) : super(key: key);

  @override
  State<GlowEffect> createState() => _GlowEffectState();
}

class _GlowEffectState extends State<GlowEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
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
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.glowRadius),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.6 * _animation.value),
                blurRadius: widget.glowRadius * _animation.value,
                spreadRadius: widget.glowRadius * 0.5 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Neon text effect
class NeonText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color neonColor;
  final double blurRadius;
  final bool animate;

  const NeonText({
    Key? key,
    required this.text,
    this.style,
    required this.neonColor,
    this.blurRadius = 15,
    this.animate = false,
  }) : super(key: key);

  @override
  State<NeonText> createState() => _NeonTextState();
}

class _NeonTextState extends State<NeonText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
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
        return Stack(
          children: [
            // Glow layer
            Text(
              widget.text,
              style: (widget.style ?? const TextStyle()).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = widget.neonColor.withOpacity(0.5 * _animation.value),
              ),
            ),
            // Shadow layers
            for (int i = 1; i <= 3; i++)
              Text(
                widget.text,
                style: (widget.style ?? const TextStyle()).copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1
                    ..color = widget.neonColor.withOpacity(0.3 * _animation.value / i)
                    ..maskFilter = MaskFilter.blur(
                      BlurStyle.outer,
                      widget.blurRadius * i * _animation.value,
                    ),
                ),
              ),
            // Main text
            Text(
              widget.text,
              style: (widget.style ?? const TextStyle()).copyWith(
                color: widget.neonColor,
              ),
            ),
          ],
        );
      },
    );
  }
}
