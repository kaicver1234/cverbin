import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated button with multiple effects
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? shadowColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration animationDuration;
  final bool enableRipple;
  final bool enableScale;
  final bool enableGlow;

  const AnimatedButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.shadowColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 200),
    this.enableRipple = true,
    this.enableScale = true,
    this.enableGlow = false,
  }) : super(key: key);

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    if (widget.enableGlow && widget.onPressed != null) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    
    setState(() => _isPressed = true);
    if (widget.enableScale) {
      _scaleController.forward();
    }
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    
    setState(() => _isPressed = false);
    if (widget.enableScale) {
      _scaleController.reverse();
    }
    
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    if (widget.enableScale) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.primaryColor;
    final foregroundColor = widget.foregroundColor ?? Colors.white;
    final shadowColor = widget.shadowColor ?? backgroundColor.withOpacity(0.3);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null 
        ? SystemMouseCursors.click 
        : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: widget.enableScale ? _scaleAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                  color: widget.onPressed == null
                      ? backgroundColor.withOpacity(0.5)
                      : backgroundColor,
                  boxShadow: [
                    if (widget.onPressed != null) ...[
                      BoxShadow(
                        color: shadowColor.withOpacity(_isHovered ? 0.4 : 0.2),
                        blurRadius: _isHovered ? 20 : 15,
                        offset: Offset(0, _isHovered ? 8 : 5),
                        spreadRadius: widget.enableGlow ? _glowAnimation.value * 2 : 0,
                      ),
                      if (_isPressed)
                        BoxShadow(
                          color: shadowColor.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onPressed,
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                    splashColor: widget.enableRipple 
                        ? foregroundColor.withOpacity(0.2)
                        : Colors.transparent,
                    highlightColor: widget.enableRipple 
                        ? foregroundColor.withOpacity(0.1)
                        : Colors.transparent,
                    child: Container(
                      padding: widget.padding ?? const EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: 12,
                      ),
                      child: Center(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                          child: widget.child,
                        ),
                      ),
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

/// Gradient animated button
class GradientAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  
  const GradientAnimatedButton({
    Key? key,
    required this.child,
    required this.gradient,
    this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<GradientAnimatedButton> createState() => _GradientAnimatedButtonState();
}

class _GradientAnimatedButtonState extends State<GradientAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: widget.gradient,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Animated gradient overlay
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment(-1 - _animation.value * 2, 0),
                          end: Alignment(1 - _animation.value * 2, 0),
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Container(
                    padding: widget.padding ?? const EdgeInsets.symmetric(
                      horizontal: 24, 
                      vertical: 12,
                    ),
                    child: Center(
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
