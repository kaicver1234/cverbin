import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/responsive_helper.dart';

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
              const Color(0xFF1A1A1A).withValues(alpha: 0.8),
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
                        const Color(0xFF2A2A2A).withValues(alpha: 0.3),
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
                bottom: ResponsiveHelper(context).scale(40).clamp(24.0, 64.0),
                child: _buildBottomSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppName() {
    final r = ResponsiveHelper(context);
    final titleSize = r.scale(48).clamp(34.0, 72.0);
    final taglineSize = r.scale(14).clamp(11.0, 19.0);
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
                // "TIKSAR VPN" - Large text without glow
                Text(
                  'TIKSAR VPN',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),

                SizedBox(height: r.scale(12).clamp(8.0, 18.0)),

                // Features text - Small text
                Text(
                  'Fast, Secure, Private',
                  style: TextStyle(
                    fontSize: taglineSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1.5,
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
    final r = ResponsiveHelper(context);
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

              SizedBox(height: r.scale(25).clamp(16.0, 34.0)),

              // Version number
              Text(
                'v1.1.5',
                style: TextStyle(
                  fontSize: r.scale(11).clamp(9.0, 14.0),
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
    final r = ResponsiveHelper(context);
    final barW = r.scale(4).clamp(3.0, 6.0);
    final barH = r.scale(30).clamp(22.0, 44.0);
    final hPad = r.scale(3).clamp(2.0, 5.0);
    final bounce = r.scale(15).clamp(10.0, 22.0);
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
                ? -bounce * (progress * 2)
                : -bounce * (2 - progress * 2);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: barW,
                  height: barH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF5A5A5A),
                        Color(0xFF3A3A3A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A4A4A).withValues(alpha: 0.3),
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
