import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accentCyan = Color(0xFF00D9FF);

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    // Shorter splash so the home screen (with the correct connect state)
    // appears quickly when the user reopens the app after a VPN connection.
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildAppName(),
                  const Spacer(flex: 3),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: ResponsiveHelper(context).scale(40).clamp(24.0, 64.0),
              child: _buildBottomSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppName() {
    final r = ResponsiveHelper(context);
    final titleSize = r.scale(48).clamp(34.0, 72.0);
    final taglineSize = r.scale(13).clamp(10.0, 18.0);
    final dividerWidth = r.scale(56).clamp(40.0, 80.0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1,
                    ),
                    children: const [
                      TextSpan(
                        text: 'TIKSAR ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'VPN',
                        style: TextStyle(color: _accentCyan),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.scale(16).clamp(10.0, 22.0)),

                Container(
                  width: dividerWidth,
                  height: 1.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _accentCyan,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                SizedBox(height: r.scale(14).clamp(10.0, 20.0)),

                Text(
                  'Fast, Secure, Private',
                  style: TextStyle(
                    fontSize: taglineSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 2.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    final r = ResponsiveHelper(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWaveLoading(),

              SizedBox(height: r.scale(25).clamp(16.0, 34.0)),

              Text(
                'v1.1.7',
                style: TextStyle(
                  fontSize: r.scale(11).clamp(9.0, 14.0),
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveLoading() {
    final r = ResponsiveHelper(context);
    final barW = r.scale(4).clamp(3.0, 6.0);
    final barH = r.scale(30).clamp(22.0, 44.0);
    final hPad = r.scale(3).clamp(2.0, 5.0);
    final bounce = r.scale(15).clamp(10.0, 22.0);
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.15;
            final progress = (_waveController.value + delay) % 1.0;

            final offset = progress < 0.5
                ? -bounce * (progress * 2)
                : -bounce * (2 - progress * 2);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: barW,
                  height: barH,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
