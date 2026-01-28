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
  // Animation controllers
  late AnimationController _tTopController;      // T top bar: 0-300ms
  late AnimationController _tVerticalController; // T vertical: 150-450ms
  late AnimationController _lettersController;   // Letters staggered
  late AnimationController _taglineController;   // Tagline: 1200ms, 500ms duration
  late AnimationController _shineController;     // Shine: 1300ms start, 2000ms duration
  late AnimationController _glowController;      // Glow pulse: 2000ms infinite
  late AnimationController _zoomFadeController;  // ZoomFade: 2800ms start, 800ms duration

  // Animations
  late Animation<double> _tTopAnim;
  late Animation<double> _tVerticalAnim;
  late Animation<double> _taglineAnim;
  late Animation<double> _shineAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _zoomAnim;
  late Animation<double> _fadeAnim;

  // Letter animations (I, K, S, A, R, V, P, N)
  final List<Animation<double>> _letterOpacityAnims = [];
  final List<Animation<double>> _letterTranslateAnims = [];

  // Colors from HTML
  static const Color gold = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFFF59E0B);
  
  // Pre-build next screen to prevent lag
  bool _isNextScreenReady = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _prebuildNextScreen();
  }
  
  // Pre-build the next screen in background to eliminate lag
  void _prebuildNextScreen() {
    // Start building next screen at 2000ms (before zoom/fade starts at 2800ms)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        // Trigger a build of the next screen widget tree
        // This warms up the widget and makes transition instant
        setState(() {
          _isNextScreenReady = true;
        });
      }
    });
  }

  void _setupAnimations() {
    // T top bar: 0-300ms
    _tTopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tTopAnim = CurvedAnimation(parent: _tTopController, curve: Curves.easeOut);

    // T vertical: starts at 150ms, duration 300ms
    _tVerticalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tVerticalAnim = CurvedAnimation(parent: _tVerticalController, curve: Curves.easeOut);

    // Letters controller - we'll use intervals
    _lettersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1240), // 350ms to 890ms+350ms
    );

    // Letter timings from HTML (relative to animation start):
    // I: 350ms, K: 420ms, S: 490ms, A: 560ms, R: 630ms
    // V: 750ms, P: 820ms, N: 890ms
    // Each letter animation is 350ms
    final letterStartTimes = [0, 70, 140, 210, 280, 400, 470, 540]; // relative to 350ms base
    
    for (int i = 0; i < 8; i++) {
      final startMs = letterStartTimes[i];
      final start = startMs / 890.0; // normalize to controller duration
      final end = ((startMs + 350) / 890.0).clamp(0.0, 1.0);
      
      _letterOpacityAnims.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _lettersController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      
      _letterTranslateAnims.add(
        Tween<double>(begin: 30, end: 0).animate(
          CurvedAnimation(
            parent: _lettersController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }

    // Tagline: starts at 1200ms, duration 500ms
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineAnim = CurvedAnimation(parent: _taglineController, curve: Curves.easeOut);

    // Shine: starts at 1300ms, duration 2000ms
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _shineAnim = Tween<double>(begin: -1.0, end: 2.8).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // Glow pulse: 2000ms infinite
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ZoomFade: starts at 2800ms, duration 800ms
    _zoomFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _zoomAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _zoomFadeController, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomFadeController, curve: Curves.easeOut),
    );
  }

  void _startAnimations() {
    // Start T top immediately
    _tTopController.forward();
    
    // Start glow pulse immediately and repeat
    _glowController.repeat(reverse: true);

    // T vertical at 150ms
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _tVerticalController.forward();
    });

    // Letters at 350ms
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _lettersController.forward();
    });

    // Tagline at 1200ms
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _taglineController.forward();
    });

    // Shine at 1300ms
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _shineController.forward();
    });

    // ZoomFade at 2800ms
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) _zoomFadeController.forward();
    });

    // Navigate at 3600ms (2800 + 800)
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) _navigateToNext();
    });
  }

  void _navigateToNext() {
    // Stop all animations before navigating to prevent lag
    _glowController.stop();
    _shineController.stop();
    
    // Use instant replacement since screen is already pre-built
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Faster fade transition (200ms instead of 400ms)
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  void dispose() {
    _tTopController.dispose();
    _tVerticalController.dispose();
    _lettersController.dispose();
    _taglineController.dispose();
    _shineController.dispose();
    _glowController.dispose();
    _zoomFadeController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            // Pre-build next screen offscreen (invisible) to warm it up
            if (_isNextScreenReady)
              Positioned(
                left: -10000, // Way offscreen
                top: -10000,
                child: Opacity(
                  opacity: 0,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: widget.nextScreen,
                    ),
                  ),
                ),
              ),
            
            // Splash screen content
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F1629), // 0%
                    Color(0xFF0A0E1A), // 50%
                    Color(0xFF050709), // 100%
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Particles - isolated repaint boundary
                  const RepaintBoundary(
                    child: _ParticlesWidget(),
                  ),
                  
                  // Main content with zoom/fade
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_zoomFadeController, _glowController]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _fadeAnim.value,
                          child: Transform.scale(
                            scale: _zoomAnim.value,
                            child: _buildLogoContent(),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Version at bottom: 40px from bottom
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Text(
                      'v1.1.2',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoContent() {
    // Font size 40px from HTML
    const double fontSize = 40.0;
    // T logo: 44x88px
    const double tWidth = 44.0;
    const double tHeight = 88.0;
    // Space: 12px
    const double spaceWidth = 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with glow
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Glow behind logo - simple gradient without ImageFilter (much lighter)
            Positioned(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  final opacity = 0.6 + (_glowAnim.value * 0.4);
                  final scale = 1.0 + (_glowAnim.value * 0.1);
                  
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 280,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            gold.withValues(alpha: 0.3 * opacity),
                            gold.withValues(alpha: 0.15 * opacity),
                            gold.withValues(alpha: 0.05 * opacity),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Logo text row with shine
            Stack(
              children: [
                // Logo row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // T Logo
                    _buildTLogo(tWidth, tHeight),
                    // Letters IKSAR
                    ..._buildTiksarLetters(fontSize),
                    // Space 12px
                    SizedBox(width: spaceWidth),
                    // Letters VPN
                    ..._buildVpnLetters(fontSize),
                  ],
                ),
                
                // Shine effect overlay
                Positioned.fill(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _ShinePainter(
                            progress: _shineAnim.value,
                            color: gold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Tagline: margin-top 20px
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _taglineController,
          builder: (context, _) {
            return Opacity(
              opacity: _taglineAnim.value,
              child: Text(
                'SECURE • FAST • FREE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  color: gold.withValues(alpha: 0.6),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTLogo(double width, double height) {
    // T top: height 12px
    // T vertical: width 12px, height 76px (88-12)
    const double topHeight = 12.0;
    const double verticalWidth = 12.0;
    final double verticalHeight = height - topHeight;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Top bar with gradient and glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _tTopController,
              builder: (context, _) {
                return Transform.scale(
                  scaleX: _tTopAnim.value,
                  alignment: Alignment.center,
                  child: Container(
                    height: topHeight,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, gold],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Vertical bar with gradient and glow
          Positioned(
            top: topHeight,
            left: (width - verticalWidth) / 2,
            child: AnimatedBuilder(
              animation: _tVerticalController,
              builder: (context, _) {
                return Transform.scale(
                  scaleY: _tVerticalAnim.value,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: verticalWidth,
                    height: verticalHeight,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [gold, goldDark],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTiksarLetters(double fontSize) {
    const letters = ['I', 'K', 'S', 'A', 'R'];
    return List.generate(letters.length, (i) {
      return AnimatedBuilder(
        animation: _lettersController,
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, _letterTranslateAnims[i].value),
            child: Opacity(
              opacity: _letterOpacityAnims[i].value,
              child: Text(
                letters[i],
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildVpnLetters(double fontSize) {
    const letters = ['V', 'P', 'N'];
    return List.generate(letters.length, (i) {
      final animIndex = i + 5; // V=5, P=6, N=7
      return AnimatedBuilder(
        animation: _lettersController,
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, _letterTranslateAnims[animIndex].value),
            child: Opacity(
              opacity: _letterOpacityAnims[animIndex].value,
              child: Text(
                letters[i],
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: gold,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: gold.withValues(alpha: 0.5),
                      blurRadius: 25,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}


// Shine effect painter - skewX(-20deg) gradient moving left to right
class _ShinePainter extends CustomPainter {
  final double progress; // -1 to 2.8
  final Color color;

  _ShinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < -0.6 || progress > 1.8) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.1),
          color.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.6),
          color.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0, 0.1, 0.3, 0.5, 0.7, 0.9, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.6, size.height));

    canvas.save();
    
    // Position based on progress
    final xOffset = size.width * progress;
    canvas.translate(xOffset, 0);
    
    // Skew -20 degrees
    final skewMatrix = Matrix4.identity()..setEntry(0, 1, -0.36); // tan(-20°) ≈ -0.36
    canvas.transform(skewMatrix.storage);

    // Draw the shine rectangle
    final rect = Rect.fromLTWH(-size.width * 0.3, -10, size.width * 0.6, size.height + 20);
    canvas.drawRect(rect, paint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Particles widget - 30 particles floating up
class _ParticlesWidget extends StatefulWidget {
  const _ParticlesWidget();

  @override
  State<_ParticlesWidget> createState() => _ParticlesWidgetState();
}

class _ParticlesWidgetState extends State<_ParticlesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  late double _startTime;

  // Colors from HTML: #fbbf24, #f59e0b, #fff
  static const colors = [
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Longer duration, smoother
    )..repeat();

    // Create 20 particles (reduced from 30)
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: 0.1 + _random.nextDouble() * 0.8,
        startY: 0.8 - _random.nextDouble() * 0.2,
        delay: _random.nextDouble() * 3.0,
        duration: 2.5 + _random.nextDouble() * 1.5,
        size: 3 + _random.nextDouble() * 4,
        colorIndex: _random.nextInt(3),
      ));
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
      animation: _controller,
      builder: (context, _) {
        final elapsed = _controller.value * 4.0; // 4 seconds cycle
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlesPainter(
            particles: _particles,
            time: _startTime + elapsed,
            colors: colors,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x;        // 0-1 horizontal position
  final double startY;   // 0-1 starting vertical position (0=top, 1=bottom)
  final double delay;    // seconds
  final double duration; // seconds
  final double size;     // pixels
  final int colorIndex;

  _Particle({
    required this.x,
    required this.startY,
    required this.delay,
    required this.duration,
    required this.size,
    required this.colorIndex,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final List<Color> colors;

  _ParticlesPainter({
    required this.particles,
    required this.time,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Calculate cycle time with delay
      final cycleTime = (time + p.delay) % p.duration;
      final progress = cycleTime / p.duration;

      // HTML animation:
      // 0%: opacity 0, translateY(0), scale(0)
      // 20%: opacity 0.6
      // 80%: opacity 0.6
      // 100%: opacity 0, translateY(-150px), scale(1)
      
      double opacity;
      if (progress < 0.2) {
        opacity = (progress / 0.2) * 0.6;
      } else if (progress < 0.8) {
        opacity = 0.6;
      } else {
        opacity = (1.0 - progress) / 0.2 * 0.6;
      }

      // Scale: 0 -> 1 over the animation
      final scale = progress;
      
      // Y movement: 0 -> -150px (relative to screen, let's use 18% of height)
      final yOffset = progress * size.height * 0.18;

      final x = p.x * size.width;
      final y = p.startY * size.height - yOffset;

      final paint = Paint()
        ..color = colors[p.colorIndex].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        (p.size * scale) / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}
