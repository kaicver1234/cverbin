import 'dart:math';
import 'package:flutter/material.dart';

class SplashLoadingScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashLoadingScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _glowController;
  late AnimationController _shineController;
  
  late Animation<double> _barTopAnim;
  late Animation<double> _barVerticalAnim;
  late Animation<double> _zoomAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _shineAnim;
  late Animation<double> _taglineAnim;
  
  final List<Animation<double>> _letterAnims = [];
  final List<_Particle> _particles = [];
  final Random _random = Random();

  // Golden color scheme
  static const Color _goldColor = Color(0xFFfbbf24);
  static const Color _goldDark = Color(0xFFf59e0b);

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _setupAnimations();
    _mainController.forward();
    _glowController.repeat(reverse: true);
    
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _shineController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _navigateToNext();
    });
  }

  void _generateParticles() {
    final colors = [_goldColor, _goldDark, Colors.white];
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle(
        x: 0.1 + _random.nextDouble() * 0.8,
        startY: 0.6 + _random.nextDouble() * 0.2,
        size: 3 + _random.nextDouble() * 4,
        color: colors[_random.nextInt(colors.length)],
        delay: _random.nextDouble() * 3,
        duration: 2.5 + _random.nextDouble() * 1.5,
      ));
    }
  }

  void _setupAnimations() {
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _shineAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // T Logo animations
    _barTopAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.09, curve: Curves.easeOut),
      ),
    );

    _barVerticalAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.04, 0.13, curve: Curves.easeOut),
      ),
    );

    // Letter animations
    for (int i = 0; i < 9; i++) {
      final start = 0.10 + (i * 0.02);
      final end = start + 0.10;
      _letterAnims.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: Interval(start, end.clamp(0, 0.5), curve: Curves.easeOut),
          ),
        ),
      );
    }

    // Tagline animation
    _taglineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.34, 0.45, curve: Curves.easeOut),
      ),
    );

    // Zoom and fade out
    _zoomAnim = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.8, 0.9, curve: Curves.easeOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  void _navigateToNext() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 28.0 : (screenWidth < 600 ? 36.0 : 46.0);
    final logoSize = screenWidth < 360 ? 30.0 : (screenWidth < 600 ? 40.0 : 50.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1629), Color(0xFF0A0E1A), Color(0xFF050709)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Particles
              ..._particles.map((p) => _ParticleWidget(particle: p)),
              
              // Main content
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_mainController, _glowController, _shineController]),
                  builder: (context, _) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: Transform.scale(
                        scale: _zoomAnim.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo with glow and shine
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow effect
                                Transform.scale(
                                  scale: _glowAnim.value,
                                  child: Container(
                                    width: 280,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          _goldColor.withOpacity(0.25 * _glowAnim.value),
                                          _goldColor.withOpacity(0.1 * _glowAnim.value),
                                          Colors.transparent,
                                        ],
                                        stops: const [0, 0.4, 1],
                                      ),
                                    ),
                                  ),
                                ),
                                // Logo text with shine
                                ClipRect(
                                  child: Stack(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _TLogo(
                                            size: logoSize,
                                            barTopValue: _barTopAnim.value,
                                            barVerticalValue: _barVerticalAnim.value,
                                          ),
                                          ..._buildLetters(fontSize),
                                        ],
                                      ),
                                      // Shine overlay
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Transform.translate(
                                            offset: Offset(_shineAnim.value * 300, 0),
                                            child: Transform(
                                              transform: Matrix4.skewX(-0.3),
                                              child: Container(
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.white.withOpacity(0.1),
                                                      _goldColor.withOpacity(0.3),
                                                      Colors.white.withOpacity(0.5),
                                                      _goldColor.withOpacity(0.3),
                                                      Colors.white.withOpacity(0.1),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Tagline
                            Opacity(
                              opacity: _taglineAnim.value,
                              child: Text(
                                'SECURE • FAST • FREE',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 3,
                                  color: _goldColor.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Version
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  'v1.1.2',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLetters(double fontSize) {
    const tiksar = ['I', 'K', 'S', 'A', 'R'];
    const vpn = ['V', 'P', 'N'];
    final widgets = <Widget>[];

    for (int i = 0; i < tiksar.length; i++) {
      widgets.add(_Letter(
        letter: tiksar[i],
        fontSize: fontSize,
        anim: _letterAnims[i],
        color: Colors.white,
        shadowColor: Colors.white.withOpacity(0.3),
      ));
    }
    
    widgets.add(_Space(fontSize: fontSize, anim: _letterAnims[5]));
    
    for (int i = 0; i < vpn.length; i++) {
      widgets.add(_Letter(
        letter: vpn[i],
        fontSize: fontSize,
        anim: _letterAnims[i + 6],
        color: _goldColor,
        shadowColor: _goldColor.withOpacity(0.5),
      ));
    }

    return widgets;
  }
}

// Particle data class
class _Particle {
  final double x;
  final double startY;
  final double size;
  final Color color;
  final double delay;
  final double duration;

  _Particle({
    required this.x,
    required this.startY,
    required this.size,
    required this.color,
    required this.delay,
    required this.duration,
  });
}

// Particle widget
class _ParticleWidget extends StatefulWidget {
  final _Particle particle;

  const _ParticleWidget({required this.particle});

  @override
  State<_ParticleWidget> createState() => _ParticleWidgetState();
}

class _ParticleWidgetState extends State<_ParticleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.particle.duration * 1000).toInt()),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    Future.delayed(Duration(milliseconds: (widget.particle.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        double opacity;
        if (progress < 0.2) {
          opacity = progress / 0.2 * 0.6;
        } else if (progress > 0.8) {
          opacity = (1 - progress) / 0.2 * 0.6;
        } else {
          opacity = 0.6;
        }

        return Positioned(
          left: widget.particle.x * size.width,
          bottom: (widget.particle.startY + progress * 0.3) * size.height,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: progress < 0.2 ? progress / 0.2 : 1,
              child: Container(
                width: widget.particle.size,
                height: widget.particle.size,
                decoration: BoxDecoration(
                  color: widget.particle.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// T Logo widget
class _TLogo extends StatelessWidget {
  final double size;
  final double barTopValue;
  final double barVerticalValue;

  const _TLogo({
    required this.size,
    required this.barTopValue,
    required this.barVerticalValue,
  });

  @override
  Widget build(BuildContext context) {
    final thickness = size * 0.28;
    final height = size * 2;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: size,
        height: height,
        child: Stack(
          children: [
            // Top bar with gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Transform.scale(
                scaleX: barTopValue,
                child: Container(
                  height: thickness,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFfbbf24)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFfbbf24).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Vertical bar with gradient
            Positioned(
              top: thickness,
              left: (size - thickness) / 2,
              child: Transform.scale(
                scaleY: barVerticalValue,
                alignment: Alignment.topCenter,
                child: Container(
                  width: thickness,
                  height: height - thickness,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFfbbf24), Color(0xFFf59e0b)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFfbbf24).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Letter widget
class _Letter extends StatelessWidget {
  final String letter;
  final double fontSize;
  final Animation<double> anim;
  final Color color;
  final Color shadowColor;

  const _Letter({
    required this.letter,
    required this.fontSize,
    required this.anim,
    required this.color,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - anim.value)),
          child: Opacity(
            opacity: anim.value,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: shadowColor,
                    blurRadius: 20,
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

// Space widget
class _Space extends StatelessWidget {
  final double fontSize;
  final Animation<double> anim;

  const _Space({required this.fontSize, required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => SizedBox(width: fontSize * 0.3 * anim.value),
    );
  }
}
