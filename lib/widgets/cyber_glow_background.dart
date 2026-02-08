import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Cyber Glow Background - Theme-Aware Version
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;
        final baseColor = Color(colors.backgroundColor);
        final centerDarkColor = Color(colors.backgroundColor).withValues(alpha: 0.95);
        final isLightTheme = themeProvider.currentTheme.id == 'light';
        
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isLightTheme 
              ? SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: baseColor,
                )
              : SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: baseColor,
                ),
          child: Scaffold(
            backgroundColor: baseColor,
            body: Stack(
              children: [
                // Layer 1: Base background
                ColoredBox(
                  color: baseColor,
                  child: const SizedBox.expand(),
                ),
                
                // Layer 2: Center gradient (lighter for light theme)
                if (!isLightTheme)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.2),
                          radius: 1.5,
                          colors: [centerDarkColor, baseColor],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                
                // Layer 3: Top glow (subtle for light theme)
                Positioned(
                  top: -150,
                  left: 0,
                  right: 0,
                  child: _buildTopGlow(colors, isLightTheme),
                ),
                
                // Layer 4: Bottom glow (very subtle for light theme)
                if (showBottomGlow)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomGlow(context, colors, isLightTheme),
                  ),
                
                // Content
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopGlow(colors, bool isLightTheme) {
    final glowColor = isLightTheme
        ? Color(colors.primaryColor).withValues(alpha: 0.03)
        : Color(colors.secondaryColor).withValues(
            alpha: enableBlur ? 0.08 : 0.12,
          );
    
    final gradient = RadialGradient(
      center: const Alignment(0.0, -0.4),
      radius: 0.9,
      colors: [glowColor, Colors.transparent],
      stops: const [0.0, 0.6],
    );

    final glowGradient = SizedBox(
      height: 450,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );

    // Only apply blur if enabled (expensive operation)
    if (enableBlur && !isLightTheme) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
            tileMode: TileMode.clamp,
          ),
          child: glowGradient,
        ),
      );
    }

    return glowGradient;
  }

  Widget _buildBottomGlow(BuildContext context, colors, bool isLightTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final bottomHeight = screenHeight * 0.45;
        
        final bottomGradient = isLightTheme
            ? RadialGradient(
                center: const Alignment(0.0, 1.0),
                radius: 1.2,
                colors: [
                  Color(colors.primaryColor).withValues(alpha: 0.02),
                  Color(colors.secondaryColor).withValues(alpha: 0.015),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              )
            : RadialGradient(
                center: const Alignment(0.0, 1.0),
                radius: 1.2,
                colors: [
                  Color(colors.primaryColor).withValues(alpha: 0.08),
                  Color(colors.primaryColor).withValues(alpha: 0.05),
                  Color(colors.accentColor).withValues(alpha: 0.04),
                  Color(colors.primaryColor).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              );
        
        return SizedBox(
          height: bottomHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: bottomGradient),
          ),
        );
      },
    );
  }
}
