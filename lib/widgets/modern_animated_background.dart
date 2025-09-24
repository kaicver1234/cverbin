import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class ModernAnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isConnected;
  
  const ModernAnimatedBackground({
    super.key,
    required this.child,
    this.isConnected = false,
  });

  @override
  State<ModernAnimatedBackground> createState() => _ModernAnimatedBackgroundState();
}

class _ModernAnimatedBackgroundState extends State<ModernAnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    
    _controller1 = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _controller2 = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _controller3 = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
    
    _animation1 = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller1,
      curve: Curves.linear,
    ));
    
    _animation2 = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller2,
      curve: Curves.linear,
    ));
    
    _animation3 = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller3,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isConnected
                  ? [
                      const Color(0xFF0D2E4B),
                      const Color(0xFF1A3A52),
                      const Color(0xFF0F1F3A),
                    ]
                  : [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F1123),
                    ],
            ),
          ),
        ),
        
        // Animated Mesh Background
        AnimatedBuilder(
          animation: Listenable.merge([_animation1, _animation2, _animation3]),
          builder: (context, child) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: MeshBackgroundPainter(
                animation1: _animation1.value,
                animation2: _animation2.value,
                animation3: _animation3.value,
                isConnected: widget.isConnected,
              ),
            );
          },
        ),
        
        // Glass Morphism Overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
          child: Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class MeshBackgroundPainter extends CustomPainter {
  final double animation1;
  final double animation2;
  final double animation3;
  final bool isConnected;

  MeshBackgroundPainter({
    required this.animation1,
    required this.animation2,
    required this.animation3,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.5;

    // Draw animated gradient orbs
    _drawGradientOrb(
      canvas,
      size,
      Offset(
        size.width * 0.3 + math.cos(animation1) * 50,
        size.height * 0.2 + math.sin(animation1) * 50,
      ),
      150,
      isConnected ? const Color(0xFF00D4FF) : const Color(0xFF6C63FF),
      0.15,
    );

    _drawGradientOrb(
      canvas,
      size,
      Offset(
        size.width * 0.7 + math.sin(animation2) * 60,
        size.height * 0.5 + math.cos(animation2) * 60,
      ),
      200,
      isConnected ? const Color(0xFF00FFB3) : const Color(0xFFFF6B9D),
      0.12,
    );

    _drawGradientOrb(
      canvas,
      size,
      Offset(
        size.width * 0.5 + math.cos(animation3) * 40,
        size.height * 0.8 + math.sin(animation3) * 40,
      ),
      180,
      isConnected ? const Color(0xFF7FFF00) : const Color(0xFFFECA57),
      0.10,
    );

    // Draw geometric patterns
    _drawGeometricPattern(canvas, size);
    
    // Draw floating particles
    _drawFloatingParticles(canvas, size);
  }

  void _drawGradientOrb(Canvas canvas, Size size, Offset center, 
      double radius, Color color, double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.5),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  void _drawGeometricPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isConnected ? const Color(0xFF00D4FF) : const Color(0xFF6C63FF))
          .withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw hexagon grid
    const hexSize = 60.0;
    for (double y = 0; y < size.height + hexSize; y += hexSize * 1.5) {
      for (double x = 0; x < size.width + hexSize; x += hexSize * 2) {
        final offset = (y % (hexSize * 3) == 0) ? 0.0 : hexSize;
        final center = Offset(x + offset, y);
        
        // Animate hexagon size based on distance from center
        final distance = (center - Offset(size.width / 2, size.height / 2)).distance;
        final scale = 1.0 + 0.1 * math.sin(animation1 + distance * 0.01);
        
        _drawHexagon(canvas, center, hexSize * 0.5 * scale, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i + animation1 * 0.1;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFloatingParticles(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = (isConnected ? const Color(0xFF00FFB3) : const Color(0xFFFF6B9D))
          .withOpacity(0.3);

    final random = math.Random(42); // Fixed seed for consistent particles
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = random.nextDouble() * 0.5 + 0.5;
      final yOffset = ((animation1 * speed * 100) % size.height);
      final y = (baseY - yOffset) % size.height;
      
      final particleSize = random.nextDouble() * 2 + 1;
      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Animated gradient wave widget for additional effects
class AnimatedWave extends StatelessWidget {
  final double height;
  final Color color;
  final Duration duration;
  
  const AnimatedWave({
    super.key,
    this.height = 100,
    this.color = const Color(0xFF00D4FF),
    this.duration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return CustomPaint(
          size: Size(MediaQuery.of(context).size.width, height),
          painter: WavePainter(
            waveAnimation: value,
            color: color,
          ),
        );
      },
      onEnd: () {
        // Loop animation
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double waveAnimation;
  final Color color;

  WavePainter({
    required this.waveAnimation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          math.sin((x / size.width * 2 * math.pi) +
                  (waveAnimation * 2 * math.pi)) *
              size.height * 0.2;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
