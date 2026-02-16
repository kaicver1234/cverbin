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

    final backgroundImage = useSecondaryBackground 
        ? 'assets/images/background2.png'
        : 'assets/images/background.png';

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            backgroundImage,
            fit: BoxFit.cover,
          ),
        ),
        // Semi-transparent overlay for better readability
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}
