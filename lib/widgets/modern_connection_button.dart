import 'package:flutter/material.dart';
import 'dart:math' as math;

class ModernConnectionButton extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback? onTap;
  final double size;

  const ModernConnectionButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    this.onTap,
    this.size = 155,
  });

  @override
  State<ModernConnectionButton> createState() => _ModernConnectionButtonState();
}

class _ModernConnectionButtonState extends State<ModernConnectionButton>
    with TickerProviderStateMixin {
  // Connecting: spinning arc
  late AnimationController _spinController;
  // Connected: expanding ripple rings
  late AnimationController _rippleController;
  // Connected: subtle breathing scale
  late AnimationController _breathController;
  // Tap press feedback
  late AnimationController _pressController;
  // State transition scale
  late AnimationController _transitionController;

  late Animation<double> _breathAnim;
  late Animation<double> _pressAnim;
  late Animation<double> _transitionAnim;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _breathAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _transitionAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.05).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_transitionController);

    _updateAnimations(false, false);
  }

  @override
  void didUpdateWidget(ModernConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasConnecting = oldWidget.isConnecting;
    final wasConnected = oldWidget.isConnected;
    final nowConnecting = widget.isConnecting;
    final nowConnected = widget.isConnected;

    if (wasConnecting != nowConnecting || wasConnected != nowConnected) {
      _transitionController.forward(from: 0);
      _updateAnimations(wasConnecting, wasConnected);
    }
  }

  void _updateAnimations(bool wasConnecting, bool wasConnected) {
    if (widget.isConnecting) {
      _spinController.repeat();
      _rippleController.stop();
      _rippleController.reset();
      _breathController.stop();
      _breathController.reset();
    } else if (widget.isConnected) {
      _spinController.stop();
      _spinController.reset();
      _rippleController.repeat();
      _breathController.repeat(reverse: true);
    } else {
      _spinController.stop();
      _spinController.reset();
      _rippleController.stop();
      _rippleController.reset();
      _breathController.stop();
      _breathController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _rippleController.dispose();
    _breathController.dispose();
    _pressController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _pressController.forward();
  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap?.call();
  }
  void _handleTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _spinController,
            _rippleController,
            _breathController,
            _pressController,
            _transitionController,
          ]),
          builder: (context, _) {
            final press = _pressAnim.value;
            final transition = _transitionController.isAnimating
                ? _transitionAnim.value
                : 1.0;
            final breath = widget.isConnected ? _breathAnim.value : 1.0;
            final scale = press * transition * breath;

            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: widget.size * 1.18,
                height: widget.size * 1.18,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripple rings (connected state)
                    if (widget.isConnected)
                      CustomPaint(
                        size: Size(widget.size * 1.18, widget.size * 1.18),
                        painter: _RipplePainter(
                          progress: _rippleController.value,
                          radius: widget.size / 2,
                        ),
                      ),

                    // Spinning arc (connecting state)
                    if (widget.isConnecting)
                      CustomPaint(
                        size: Size(widget.size * 1.18, widget.size * 1.18),
                        painter: _SpinnerPainter(
                          progress: _spinController.value,
                          radius: widget.size * 0.565,
                        ),
                      ),

                    // Main circle button
                    _buildCircle(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCircle() {
    final isConnected = widget.isConnected;
    final isConnecting = widget.isConnecting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConnected || isConnecting
            ? Colors.white
            : const Color(0xFF111111),
        border: Border.all(
          color: isConnected
              ? Colors.white.withValues(alpha: 0.6)
              : isConnecting
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12),
          width: 2,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 0,
                ),
              ]
            : isConnecting
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(
            Icons.power_settings_new_rounded,
            key: ValueKey(isConnected),
            size: widget.size * 0.36,
            color: isConnected || isConnecting
                ? Colors.black.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ─── Ripple Painter (connected state) ─────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final double radius;

  _RipplePainter({required this.progress, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Two rings staggered by 0.5
    for (int i = 0; i < 2; i++) {
      final t = ((progress + i * 0.5) % 1.0);
      final r = radius + t * radius * 0.55;
      final opacity = (1.0 - t) * 0.28;
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress;
}

// ─── Spinner Painter (connecting state) ───────────────────────────────────────

class _SpinnerPainter extends CustomPainter {
  final double progress;
  final double radius;

  _SpinnerPainter({required this.progress, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, trackPaint);

    // Spinning arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.9),
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2 - math.pi / 2,
      math.pi * 1.5,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.progress != progress;
}
