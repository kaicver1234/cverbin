import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedVPNBackground extends StatefulWidget {
  final bool isConnected;
  
  const AnimatedVPNBackground({
    super.key,
    this.isConnected = false,
  });

  @override
  State<AnimatedVPNBackground> createState() => _AnimatedVPNBackgroundState();
}

class _AnimatedVPNBackgroundState extends State<AnimatedVPNBackground>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  final List<Particle> particles = [];
  final math.Random random = math.Random();

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    // Create particles
    for (int i = 0; i < 20; i++) {
      particles.add(Particle(
        position: Offset(
          random.nextDouble(),
          random.nextDouble(),
        ),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 0.02 + 0.01,
        opacity: random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveController,
        _particleController,
        _pulseController,
      ]),
      builder: (context, child) {
        return CustomPaint(
          painter: VPNBackgroundPainter(
            waveAnimation: _waveController.value,
            particleAnimation: _particleController.value,
            pulseAnimation: _pulseController.value,
            particles: particles,
            isConnected: widget.isConnected,
          ),
          child: Container(),
        );
      },
    );
  }
}

class Particle {
  Offset position;
  final double size;
  final double speed;
  final double opacity;

  Particle({
    required this.position,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class VPNBackgroundPainter extends CustomPainter {
  final double waveAnimation;
  final double particleAnimation;
  final double pulseAnimation;
  final List<Particle> particles;
  final bool isConnected;

  VPNBackgroundPainter({
    required this.waveAnimation,
    required this.particleAnimation,
    required this.pulseAnimation,
    required this.particles,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isConnected
          ? [
              const Color(0xFF0A1628),
              const Color(0xFF1E3A5F),
              const Color(0xFF0F2847),
            ]
          : [
              const Color(0xFF0D1117),
              const Color(0xFF161B22),
              const Color(0xFF0D1117),
            ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, paint);
    
    // Draw network grid
    _drawNetworkGrid(canvas, size);
    
    // Draw flowing waves
    _drawFlowingWaves(canvas, size);
    
    // Draw particles
    _drawParticles(canvas, size);
    
    // Draw pulse effect if connected
    if (isConnected) {
      _drawPulseEffect(canvas, size);
    }
  }

  void _drawNetworkGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isConnected 
          ? const Color(0xFF10B981).withOpacity(0.1)
          : Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += 50) {
      final offsetX = x + (waveAnimation * 20);
      canvas.drawLine(
        Offset(offsetX % size.width, 0),
        Offset(offsetX % size.width, size.height),
        paint,
      );
    }

    // Draw horizontal lines with wave effect
    for (double y = 0; y < size.height; y += 50) {
      final path = Path();
      path.moveTo(0, y);
      
      for (double x = 0; x < size.width; x += 10) {
        final waveY = y + math.sin((x / 100) + (waveAnimation * 2 * math.pi)) * 5;
        path.lineTo(x, waveY);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  void _drawFlowingWaves(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = isConnected
            ? const Color(0xFF10B981).withOpacity(0.05 + i * 0.02)
            : const Color(0xFF6366F1).withOpacity(0.03 + i * 0.01)
        ..style = PaintingStyle.fill;

      final path = Path();
      final yOffset = size.height * (0.3 + i * 0.2);
      
      path.moveTo(0, yOffset);
      
      for (double x = 0; x <= size.width; x++) {
        final y = yOffset + 
            math.sin((x / size.width * 4 * math.pi) + 
                    (waveAnimation * 2 * math.pi) + 
                    (i * math.pi / 3)) * 
            (30 + i * 10);
        path.lineTo(x, y);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update particle position
      particle.position = Offset(
        particle.position.dx,
        (particle.position.dy - particle.speed + particleAnimation * particle.speed) % 1.0,
      );

      final paint = Paint()
        ..color = isConnected
            ? const Color(0xFF10B981).withOpacity(particle.opacity)
            : Colors.white.withOpacity(particle.opacity * 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          particle.position.dx * size.width,
          particle.position.dy * size.height,
        ),
        particle.size,
        paint,
      );
    }
  }

  void _drawPulseEffect(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3 * (1 + pulseAnimation * 0.2);
    
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.1 * (1 - pulseAnimation)),
          const Color(0xFF10B981).withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
