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
  late AnimationController _mainController;
  
  late Animation<double> _barTopAnim;
  late Animation<double> _barVerticalAnim;
  late Animation<double> _tMoveAnim;
  late Animation<double> _zoomAnim;
  late Animation<double> _fadeAnim;
  
  final List<Animation<double>> _letterAnims = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _mainController.forward();
    
    // Navigate after animation completes
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _navigateToNext();
    });
  }

  void _setupAnimations() {
    // Single controller for everything - more efficient
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // T Logo: 0-400ms
    _barTopAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.12, curve: Curves.easeOut),
      ),
    );

    _barVerticalAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.06, 0.18, curve: Curves.easeOut),
      ),
    );

    _tMoveAnim = Tween<double>(begin: 0, end: 5).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.18, 0.28, curve: Curves.easeOut),
      ),
    );

    // Letters: 400ms-1600ms (staggered)
    for (int i = 0; i < 9; i++) {
      final start = 0.12 + (i * 0.03);
      final end = start + 0.1;
      _letterAnims.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: Interval(start, end.clamp(0, 0.6), curve: Curves.easeOut),
          ),
        ),
      );
    }

    // Zoom: 2500ms-3500ms
    _zoomAnim = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 0.8, curve: Curves.easeOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  void _navigateToNext() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 28.0 : (screenWidth < 600 ? 36.0 : 46.0);
    final logoSize = screenWidth < 360 ? 30.0 : (screenWidth < 600 ? 40.0 : 50.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1629), Color(0xFF0A0E1A), Color(0xFF050709)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, _) {
                  return FadeTransition(
                    opacity: _fadeAnim,
                    child: Transform.scale(
                      scale: _zoomAnim.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TLogo(
                            size: logoSize,
                            barTopValue: _barTopAnim.value,
                            barVerticalValue: _barVerticalAnim.value,
                            moveValue: _tMoveAnim.value,
                          ),
                          ..._buildLetters(fontSize),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Version at bottom
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                'v1.1.1',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  List<Widget> _buildLetters(double fontSize) {
    const tiksar = ['I', 'K', 'S', 'A', 'R'];
    const vpn = ['V', 'P', 'N'];
    final widgets = <Widget>[];

    for (int i = 0; i < tiksar.length; i++) {
      widgets.add(_Letter(letter: tiksar[i], fontSize: fontSize, anim: _letterAnims[i], isGreen: true));
    }
    
    widgets.add(_Space(fontSize: fontSize, anim: _letterAnims[5]));
    
    for (int i = 0; i < vpn.length; i++) {
      widgets.add(_Letter(letter: vpn[i], fontSize: fontSize, anim: _letterAnims[i + 6], isGreen: false));
    }

    return widgets;
  }
}

// Separate stateless widgets for better performance
class _TLogo extends StatelessWidget {
  final double size;
  final double barTopValue;
  final double barVerticalValue;
  final double moveValue;

  const _TLogo({
    required this.size,
    required this.barTopValue,
    required this.barVerticalValue,
    required this.moveValue,
  });

  @override
  Widget build(BuildContext context) {
    final thickness = size * 0.28;
    final height = size * 2;

    return Padding(
      padding: EdgeInsets.only(right: moveValue),
      child: SizedBox(
        width: size,
        height: height,
        child: Stack(
          children: [
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Transform.scale(
                scaleX: barTopValue,
                child: Container(
                  height: thickness,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Vertical bar
            Positioned(
              top: thickness,
              left: (size - thickness) / 2,
              child: Transform.scale(
                scaleY: barVerticalValue,
                alignment: Alignment.topCenter,
                child: Container(
                  width: thickness,
                  height: height - thickness,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  final String letter;
  final double fontSize;
  final Animation<double> anim;
  final bool isGreen;

  const _Letter({
    required this.letter,
    required this.fontSize,
    required this.anim,
    required this.isGreen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - anim.value)),
          child: Opacity(
            opacity: anim.value,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: isGreen ? const Color(0xFF10B981) : Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Space extends StatelessWidget {
  final double fontSize;
  final Animation<double> anim;

  const _Space({required this.fontSize, required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => SizedBox(width: fontSize * 0.25 * anim.value),
    );
  }
}
