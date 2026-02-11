import 'package:flutter/material.dart';

class SplashLoadingScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashLoadingScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _zoomController;
  late AnimationController _lettersController;
  late AnimationController _waveController;
  late AnimationController _versionController;

  late Animation<double> _zoomAnim;
  late Animation<double> _versionAnim;

  final List<Animation<double>> _letterOpacityAnims = [];
  final List<Animation<double>> _letterTranslateAnims = [];

  static const Color green = Color(0xFF10B981);
  static const Color cyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    // Main zoom animation (Netflix style)
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _zoomAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOut),
    );

    // Letters bounce animation
    _lettersController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Letter timings: T(0.8s), I(0.85s), K(0.9s), S(0.95s), A(1s), R(1.05s), V(1.2s), P(1.25s), N(1.3s)
    final letterDelays = [800, 850, 900, 950, 1000, 1050, 1200, 1250, 1300];
    
    for (int i = 0; i < 9; i++) {
      final startMs = letterDelays[i];
      final start = startMs / 1300.0;
      final end = ((startMs + 600) / 1300.0).clamp(0.0, 1.0);
      
      _letterOpacityAnims.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _lettersController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      
      _letterTranslateAnims.add(
        Tween<double>(begin: -30, end: 0).animate(
          CurvedAnimation(
            parent: _lettersController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }

    // Wave animation (infinite)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Version animation
    _versionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _versionAnim = CurvedAnimation(parent: _versionController, curve: Curves.easeOut);
  }

  void _startAnimations() {
    // Start zoom immediately
    _zoomController.forward();

    // Start letters at 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _lettersController.forward();
    });

    // Start wave at 1800ms
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _waveController.repeat();
    });

    // Start version at 2200ms
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _versionController.forward();
    });

    // Navigate after 3500ms
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _navigateToNext();
    });
  }

  void _navigateToNext() {
    _waveController.stop();
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _lettersController.dispose();
    _waveController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;
    final isMediumScreen = size.width >= 400 && size.width < 600;
    
    // Responsive sizes - more moderate
    final textSize = isSmallScreen ? 32.0 : (isMediumScreen ? 42.0 : 52.0);
    final letterSpacing = isSmallScreen ? 2.0 : (isMediumScreen ? 3.0 : 6.0);
    final waveBottom = isSmallScreen ? 80.0 : 100.0;
    
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _zoomController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _zoomAnim.value > 0.5 ? 1.0 : _zoomAnim.value * 2,
                    child: Transform.scale(
                      scale: _zoomAnim.value,
                      child: child,
                    ),
                  );
                },
                child: _buildText(textSize, letterSpacing),
              ),
            ),
            
            // Sound wave at bottom
            Positioned(
              bottom: waveBottom,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _waveController.status == AnimationStatus.forward ||
                            _waveController.status == AnimationStatus.reverse
                        ? 1.0
                        : 0.0,
                    child: _buildSoundWave(isSmallScreen),
                  );
                },
              ),
            ),
            
            // Version at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _versionController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _versionAnim.value,
                    child: const Text(
                      'v1.1.4',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0x40FFFFFF),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(double fontSize, double letterSpacing) {
    const letters = ['T', 'I', 'K', 'S', 'A', 'R', ' ', 'V', 'P', 'N'];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (i) {
        if (letters[i] == ' ') {
          return SizedBox(width: fontSize * 0.3);
        }
        
        final isVPN = i >= 7;
        final color = isVPN ? cyan : green;
        final animIndex = i >= 7 ? i - 1 : i;
        
        return AnimatedBuilder(
          animation: _lettersController,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _letterTranslateAnims[animIndex].value),
              child: Opacity(
                opacity: _letterOpacityAnims[animIndex].value,
                child: Text(
                  letters[i],
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: letterSpacing,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSoundWave(bool isSmall) {
    final barWidth = isSmall ? 3.0 : 4.0;
    final barGap = isSmall ? 4.0 : 6.0;
    final heights = isSmall 
        ? [15.0, 22.0, 30.0, 26.0, 33.0, 22.0, 18.0]
        : [20.0, 30.0, 40.0, 35.0, 45.0, 30.0, 25.0];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            final delay = i * 0.1;
            final value = (_waveController.value + delay) % 1.0;
            final scale = value < 0.5 ? (value * 2) : (2 - value * 2);
            final currentHeight = heights[i] * (1 + scale * 0.5);
            
            return Container(
              width: barWidth,
              height: currentHeight,
              margin: EdgeInsets.symmetric(horizontal: barGap / 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [green, cyan],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
