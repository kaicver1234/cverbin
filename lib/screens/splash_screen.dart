import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _floatController;
  late AnimationController _lineController;
  late AnimationController _textController;
  late AnimationController _waveController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowIntensity;
  late Animation<double> _floatOffset;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
    _scheduleNavigation();
  }

  void _initAnimations() {
    // Logo entrance animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6),
      ),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _glowIntensity = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Float animation
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _floatOffset = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    // Line animation
    _lineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    _textSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Wave animation
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  void _startAnimations() {
    _logoController.forward();
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _textController.forward();
    });
  }

  void _scheduleNavigation() {
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    _lineController.dispose();
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: Stack(
        children: [
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  const Color(0xFF6366f1).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              const Spacer(flex: 2),

              // Logo with animations
              AnimatedBuilder(
                animation: Listenable.merge([
                  _logoController,
                  _glowController,
                  _floatController,
                ]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatOffset.value),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value * 3.14159,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: _buildLogoWithLines(),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              const Spacer(flex: 1),

              // App name
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: const Text(
                        'Tiksar VPN',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // Tagline
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Opacity(
                      opacity: _textOpacity.value * 0.4,
                      child: const Text(
                        'SECURE CONNECTION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Loading text
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value * 0.5,
                    child: const Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Wave loading animation
              _buildWaveLoading(),

              const SizedBox(height: 50),

              // Version
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value * 0.25,
                    child: const Text(
                      'v1.1.5',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWithLines() {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated lines
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _lineController,
              builder: (context, child) {
                final progress = (_lineController.value + (index * 0.15)) % 1.0;
                final opacity = progress < 0.3
                    ? progress / 0.3
                    : progress > 0.7
                        ? (1.0 - progress) / 0.3
                        : 0.8;

                return Positioned(
                  top: 60 + (index * 50.0),
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset((progress - 0.5) * 440, 0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF6366f1),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Big T letter with glow
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366f1)
                          .withValues(alpha: 0.4 * _glowIntensity.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: const Color(0xFF6366f1)
                          .withValues(alpha: 0.2 * _glowIntensity.value),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Text(
                  'T',
                  style: TextStyle(
                    fontSize: 150,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaveLoading() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.1;
            final progress = (_waveController.value + delay) % 1.0;
            final scale = progress < 0.5
                ? 0.3 + (progress * 1.4)
                : 1.0 - ((progress - 0.5) * 1.4);
            final opacity = progress < 0.5
                ? 0.4 + (progress * 1.2)
                : 1.0 - ((progress - 0.5) * 1.2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.scale(
                scaleY: scale.clamp(0.3, 1.0),
                child: Opacity(
                  opacity: opacity.clamp(0.4, 1.0),
                  child: Container(
                    width: 4,
                    height: 35,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF6366f1),
                          Color(0xFF8b5cf6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
