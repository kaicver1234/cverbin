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
                // Layer 1: Base background (very dark)
                const ColoredBox(
                  color: Color(0xFF050505),
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
    
    // Different gradient colors based on theme
    List<Color> gradientColors;
    
    switch (themeId) {
      case 'default': // Dark Green
        gradientColors = const [
          Color.fromRGBO(3, 30, 18, 0.55),
          Color.fromRGBO(4, 36, 24, 0.45),
          Color.fromRGBO(5, 42, 28, 0.36),
          Color.fromRGBO(6, 48, 32, 0.28),
          Color.fromRGBO(7, 54, 36, 0.20),
          Color.fromRGBO(8, 60, 40, 0.12),
          Color.fromRGBO(9, 66, 44, 0.06),
          Color.fromRGBO(10, 72, 48, 0.03),
          Colors.transparent,
        ];
        break;
      case 'ocean': // Dark Blue
        gradientColors = const [
          Color.fromRGBO(3, 12, 30, 0.55),
          Color.fromRGBO(4, 15, 36, 0.45),
          Color.fromRGBO(5, 18, 42, 0.36),
          Color.fromRGBO(6, 20, 48, 0.28),
          Color.fromRGBO(7, 23, 54, 0.20),
          Color.fromRGBO(8, 26, 60, 0.12),
          Color.fromRGBO(9, 28, 66, 0.06),
          Color.fromRGBO(10, 30, 72, 0.03),
          Colors.transparent,
        ];
        break;
      case 'sunset': // Dark Purple
        gradientColors = const [
          Color.fromRGBO(20, 3, 28, 0.55),
          Color.fromRGBO(25, 4, 34, 0.45),
          Color.fromRGBO(30, 5, 40, 0.36),
          Color.fromRGBO(35, 6, 46, 0.28),
          Color.fromRGBO(40, 7, 52, 0.20),
          Color.fromRGBO(45, 8, 58, 0.12),
          Color.fromRGBO(50, 9, 64, 0.06),
          Color.fromRGBO(55, 10, 70, 0.03),
          Colors.transparent,
        ];
        break;
      case 'forest': // Dark Red
        gradientColors = const [
          Color.fromRGBO(30, 3, 8, 0.55),
          Color.fromRGBO(36, 4, 10, 0.45),
          Color.fromRGBO(42, 5, 12, 0.36),
          Color.fromRGBO(48, 6, 14, 0.28),
          Color.fromRGBO(54, 7, 16, 0.20),
          Color.fromRGBO(60, 8, 18, 0.12),
          Color.fromRGBO(66, 9, 20, 0.06),
          Color.fromRGBO(72, 10, 22, 0.03),
          Colors.transparent,
        ];
        break;
      default: // Dark Green (fallback)
        gradientColors = const [
          Color.fromRGBO(3, 30, 18, 0.55),
          Color.fromRGBO(4, 36, 24, 0.45),
          Color.fromRGBO(5, 42, 28, 0.36),
          Color.fromRGBO(6, 48, 32, 0.28),
          Color.fromRGBO(7, 54, 36, 0.20),
          Color.fromRGBO(8, 60, 40, 0.12),
          Color.fromRGBO(9, 66, 44, 0.06),
          Color.fromRGBO(10, 72, 48, 0.03),
          Colors.transparent,
        ];
    }
    
    return Container(
      height: bottomHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: gradientColors,
          stops: const [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
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
            Color.fromRGBO(5, 5, 5, 0.4),
            Color.fromRGBO(5, 5, 5, 0.75),
            Color.fromRGBO(5, 5, 5, 0.92),
            Color.fromRGBO(5, 5, 5, 1),
            Color.fromRGBO(5, 5, 5, 1),
          ],
          stops: [0.0, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopDim(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topHeight = screenHeight * 0.5;
    
    return Container(
      height: topHeight,
      color: const Color(0xFF050505),
    );
  }
}
