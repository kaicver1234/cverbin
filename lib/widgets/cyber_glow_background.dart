import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cyber Glow Background - New UI Design
/// Static gradient with subtle glow effects
class CyberGlowBackground extends StatelessWidget {
  final Widget child;
  final bool showBottomGlow;

  const CyberGlowBackground({
    super.key,
    required this.child,
    this.showBottomGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0a0a0a),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a0a),
        body: Stack(
          children: [
            // Base gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0),
                    radius: 1.2,
                    colors: [
                      Color(0xFF12121a), // Subtle purple tint in center
                      Color(0xFF0a0a0a), // Dark edges
                    ],
                  ),
                ),
              ),
            ),
            
            // Top-center purple glow
            Positioned(
              top: -100,
              left: 0,
              right: 0,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      const Color(0xFF6366f1).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom-left green glow
            if (showBottomGlow)
              Positioned(
                bottom: -50,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10b981).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            
            // Bottom-right cyan glow
            if (showBottomGlow)
              Positioned(
                bottom: -50,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF06b6d4).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            
            // Bottom gradient overlay
            if (showBottomGlow)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 250,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF10b981).withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            
            // Content
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}
