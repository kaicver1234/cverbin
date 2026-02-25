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

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF000000), // Pure black background
        ),
        child: child,
      ),
    );
  }
}
