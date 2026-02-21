import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showBackground;
  final bool useSecondaryBackground;

  const AppBackground({
    super.key,
    required this.child,
    this.showBackground = true,
    this.useSecondaryBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBackground) {
      return child;
    }

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/back.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Dark overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
