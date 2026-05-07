import 'package:flutter/material.dart';
import 'dart:async';

/// Modern Splash Screen based on the approved HTML design
/// Features:
/// - Large "Tiksar" text with glow effect
/// - Small "VPN" text below
/// - 5-bar wave loading animation at bottom
/// - Version number below loading animation
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  
  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    
    // Wave animation for loading bars
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    // Navigate to next screen after 3 seconds
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0A0A),
              const Color(0xFF1A0A2E).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Radial glow effect in background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.0,
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // App name section
                    _buildAppName(),
                    
                    const Spacer(flex: 3),
                  ],
                ),
              ),

              // Bottom section with loading and version
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: _buildBottomSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Tiksar" - Large text with glow
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.white],
                  ).createShader(bounds),
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      // Pulsing glow effect
                      final glowIntensity = 0.5 + (0.3 * (0.5 + 0.5 * 
                        (1 + ((_waveController.value * 2) % 1.0) * 2 - 1)));
                      
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: glowIntensity * 0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: glowIntensity * 0.3),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Tiksar',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // "VPN" - Small text
                Text(
                  'VPN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 4,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 5-bar wave loading animation
              _buildWaveLoading(),
              
              const SizedBox(height: 25),
              
              // Version number
              Text(
                'v1.1.5',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveLoading() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            // Calculate wave animation with delay for each bar
            final delay = index * 0.15;
            final progress = (_waveController.value + delay) % 1.0;
            
            // Calculate vertical offset (bounce up and down)
            final offset = progress < 0.5
                ? -15.0 * (progress * 2)
                : -15.0 * (2 - progress * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF6366F1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
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
