import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cyber Glow Background - V7 Final Mix Style (Optimized)
/// High-performance background with minimal widget overhead
/// Three layers: center dark, top aurora, bottom seamless glow
class CyberGlowBackground extends StatelessWidget {
  final Widget child;
  final bool showBottomGlow;
  final bool enableBlur; // Option to enable blur (impacts performance)

  const CyberGlowBackground({
    super.key,
    required this.child,
    this.showBottomGlow = true,
    this.enableBlur = false, // Disabled by default for performance
  });

  // Pre-defined const colors for better performance
  static const _baseColor = Color(0xFF0a0a0a);
  static const _centerDarkColor = Color(0xFF0c0c12);
  static const _auroraColorLight = Color(0x1F6366F1); // alpha 0.12
  static const _auroraColorDark = Color(0x146366F1); // alpha 0.08
  
  // Cached gradients
  static const _centerGradient = RadialGradient(
    center: Alignment(0.0, -0.2),
    radius: 1.5,
    colors: [_centerDarkColor, _baseColor],
    stops: [0.0, 0.7],
  );

  // Bottom gradient - created once per instance
  static final _bottomGradient = _createBottomGradient();
  
  static RadialGradient _createBottomGradient() {
    return RadialGradient(
      center: const Alignment(0.0, 1.0),
      radius: 1.2,
      colors: [
        const Color(0xFF10B981).withValues(alpha: 0.08), // Green glow
        const Color(0xFF10B981).withValues(alpha: 0.05),
        const Color(0xFF06B6D4).withValues(alpha: 0.04), // Cyan blend
        const Color(0xFF10B981).withValues(alpha: 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _baseColor,
      ),
      child: Scaffold(
        backgroundColor: _baseColor,
        body: Stack(
          children: [
            // Layer 1: Base dark background
            const ColoredBox(
              color: _baseColor,
              child: SizedBox.expand(),
            ),
            
            // Layer 2: Center dark radial gradient
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: _centerGradient),
              ),
            ),
            
            // Layer 3: Top Aurora effect (optimized)
            Positioned(
              top: -150,
              left: 0,
              right: 0,
              child: _buildTopAurora(),
            ),
            
            // Layer 4: Bottom glow - seamless blend
            if (showBottomGlow)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomGlow(context),
              ),
            
            // Content
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTopAurora() {
    // Use pre-defined const colors based on blur setting
    final gradient = RadialGradient(
      center: const Alignment(0.0, -0.4),
      radius: 0.9,
      colors: [
        enableBlur ? _auroraColorDark : _auroraColorLight,
        Colors.transparent,
      ],
      stops: const [0.0, 0.6],
    );

    final auroraGradient = SizedBox(
      height: 450,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );

    // Only apply blur if enabled (expensive operation)
    if (enableBlur) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
            tileMode: TileMode.clamp,
          ),
          child: auroraGradient,
        ),
      );
    }

    return auroraGradient;
  }

  Widget _buildBottomGlow(BuildContext context) {
    // Use LayoutBuilder to avoid MediaQuery rebuild issues
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final bottomHeight = screenHeight * 0.45;
        
        return SizedBox(
          height: bottomHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: _bottomGradient),
          ),
        );
      },
    );
  }
}
