import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Color? color;
  final BorderRadius? customBorderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GlassmorphismCard({
    Key? key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius = 20,
    this.color,
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: customBorderRadius ?? BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(opacity),
              borderRadius: customBorderRadius ?? BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                width: 1.5,
                color: Colors.white.withOpacity(0.2),
              ),
              boxShadow: boxShadow ?? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Animated glassmorphism card with hover effect
class AnimatedGlassmorphismCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsets? padding;
  final Duration animationDuration;

  const AnimatedGlassmorphismCard({
    Key? key,
    required this.child,
    this.onTap,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius = 20,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  State<AnimatedGlassmorphismCard> createState() => _AnimatedGlassmorphismCardState();
}

class _AnimatedGlassmorphismCardState extends State<AnimatedGlassmorphismCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: widget.opacity,
      end: widget.opacity + 0.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.blur + (_isHovered ? 2 : 0),
                      sigmaY: widget.blur + (_isHovered ? 2 : 0),
                    ),
                    child: Container(
                      padding: widget.padding ?? const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_opacityAnimation.value),
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        border: Border.all(
                          width: _isHovered ? 2 : 1.5,
                          color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(_isHovered ? 0.15 : 0.1),
                            blurRadius: _isHovered ? 25 : 20,
                            offset: Offset(0, _isHovered ? 12 : 10),
                          ),
                        ],
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
