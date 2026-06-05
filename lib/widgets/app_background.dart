import 'package:flutter/material.dart';

/// Wraps content with a max-width constraint so screens that weren't
/// individually adapted for tablets don't stretch full-width on large
/// displays. Centers the child and adds symmetric padding on big screens.
class ResponsivePageWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsivePageWrapper({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    if (shortest < 600) return child; // phones get full width
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

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
