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
        final themeId = themeProvider.currentTheme.id;
        final baseColor = Color(colors.backgroundColor);
        
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: baseColor,
          ),
          child: Scaffold(
            backgroundColor: baseColor,
            body: Stack(
              children: [
                // Layer 1: Base background (pure black)
                const ColoredBox(
                  color: Color(0xFF000000),
                  child: SizedBox.expand(),
                ),
                
                // Layer 2: Bottom glow (theme-specific gradient from bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomGlow(context, colors, themeId),
                ),
                
                // Layer 3: Center fade (dark gradient to top)
                Positioned.fill(
                  child: _buildCenterFade(),
                ),
                
                // Layer 4: Top dim (solid dark)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopDim(context),
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

  Widget _buildBottomGlow(BuildContext context, colors, String themeId) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomHeight = screenHeight * 0.5;
    
    // Cyan theme gradient - subtle glow from bottom
    const gradientColors = [
      Color.fromRGBO(0, 217, 255, 0.12),  // Cyan glow
      Color.fromRGBO(0, 217, 255, 0.10),
      Color.fromRGBO(0, 217, 255, 0.08),
      Color.fromRGBO(0, 217, 255, 0.06),
      Color.fromRGBO(0, 217, 255, 0.04),
      Color.fromRGBO(0, 217, 255, 0.02),
      Color.fromRGBO(0, 217, 255, 0.01),
      Colors.transparent,
      Colors.transparent,
    ];
    
    return Container(
      height: bottomHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: gradientColors,
          stops: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
        ),
      ),
    );
  }

  Widget _buildCenterFade() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color.fromRGBO(0, 0, 0, 0.3),
            Color.fromRGBO(0, 0, 0, 0.6),
            Color.fromRGBO(0, 0, 0, 0.85),
            Color.fromRGBO(0, 0, 0, 1),
            Color.fromRGBO(0, 0, 0, 1),
          ],
          stops: [0.0, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopDim(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topHeight = screenHeight * 0.3;
    
    return Container(
      height: topHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color(0xFF000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}
