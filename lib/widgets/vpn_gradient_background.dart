import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// VPN Gradient Background - V7 Final Mix Style
/// Multi-layer gradient with aurora top and seamless bottom glow
class VPNGradientBackground extends StatelessWidget {
  final Widget child;
  final VPNBackgroundStatus status;

  const VPNGradientBackground({
    super.key,
    required this.child,
    this.status = VPNBackgroundStatus.disconnected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: status == VPNBackgroundStatus.connected
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              toolbarHeight: 0,
            )
          : null,
      body: Stack(
        children: [
          // Base dark background
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF000000),
          ),
          
          // Center dark radial gradient layer (ellipse at 50% 40%)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2), // 50% 40%
                  radius: 1.5,
                  colors: const [
                    Color(0xFF000000),
                    Color(0xFF000000),
                  ],
                  stops: const [0.0, 0.7],
                  transform: const GradientRotation(0), // Keep it elliptical
                ),
              ),
            ),
          ),
          
          // Top Aurora effect with blur
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: _buildTopAurora(),
          ),
          
          // Bottom glow - seamless blend
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomGlow(),
          ),
          
          // Content
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _buildTopAurora() {
    final Color auroraColor = _getTopAuroraColor();
    
    // Matches: radial-gradient(ellipse 80% 50% at 50% 30%, ...)
    // with filter: blur(30px)
    return Container(
      height: 450,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.4),
          radius: 1.2,
          colors: [
            auroraColor,
            auroraColor.withValues(alpha: auroraColor.a * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7],
        ),
      ),
    );
  }

  Widget _buildBottomGlow() {
    final colors = _getBottomGlowColors();
    
    // Matches HTML: height: 45%
    // Three layers blended seamlessly
    return SizedBox(
      height: 380, // ~45% of 812px mobile frame
      child: Stack(
        children: [
          // Layer 1: linear-gradient(180deg, transparent 0%, rgba(16, 185, 129, 0.03) 60%, rgba(16, 185, 129, 0.06) 100%)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.primary.withValues(alpha: 0.03),
                    colors.primary.withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          
          // Layer 2: radial-gradient(ellipse at 30% 100%, rgba(16, 185, 129, 0.08) 0%, transparent 45%)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, 1.0), // at 30% 100%
                  radius: 0.7,
                  colors: [
                    colors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
          
          // Layer 3: radial-gradient(ellipse at 70% 100%, rgba(6, 182, 212, 0.06) 0%, transparent 45%)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.4, 1.0), // at 70% 100%
                  radius: 0.7,
                  colors: [
                    colors.secondary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTopAuroraColor() {
    switch (status) {
      case VPNBackgroundStatus.disconnected:
        return const Color(0xFF00D9FF).withValues(alpha: 0.08); // Cyan
      case VPNBackgroundStatus.connected:
        return const Color(0xFF00FFA3).withValues(alpha: 0.10); // Green-cyan
      case VPNBackgroundStatus.connecting:
      case VPNBackgroundStatus.analyzing:
        return const Color(0xFF00D9FF).withValues(alpha: 0.10); // Cyan
      case VPNBackgroundStatus.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.08); // Red
      case VPNBackgroundStatus.noInternet:
        return const Color(0xFFEF4444).withValues(alpha: 0.08); // Red
    }
  }

  _BottomGlowColors _getBottomGlowColors() {
    switch (status) {
      case VPNBackgroundStatus.disconnected:
        return const _BottomGlowColors(
          primary: Color(0xFF00D9FF),   // Cyan
          secondary: Color(0xFF00FFA3), // Green-cyan
        );
      case VPNBackgroundStatus.connected:
        return const _BottomGlowColors(
          primary: Color(0xFF00FFA3),   // Green-cyan
          secondary: Color(0xFF00D9FF), // Cyan
        );
      case VPNBackgroundStatus.connecting:
      case VPNBackgroundStatus.analyzing:
        return const _BottomGlowColors(
          primary: Color(0xFF00D9FF),   // Cyan
          secondary: Color(0xFF00FFA3), // Green-cyan
        );
      case VPNBackgroundStatus.error:
        return const _BottomGlowColors(
          primary: Color(0xFFEF4444),   // Red
          secondary: Color(0xFFF97316), // Orange
        );
      case VPNBackgroundStatus.noInternet:
        return const _BottomGlowColors(
          primary: Color(0xFFEF4444),   // Red
          secondary: Color(0xFFF87171), // Lighter red
        );
    }
  }
}

class _BottomGlowColors {
  final Color primary;
  final Color secondary;
  
  const _BottomGlowColors({
    required this.primary,
    required this.secondary,
  });
}

/// Background status enum for VPN states
enum VPNBackgroundStatus {
  disconnected,
  connecting,
  connected,
  analyzing,
  error,
  noInternet,
}
