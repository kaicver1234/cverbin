import 'package:flutter/material.dart';

/// Smooth fade transition for page routes
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  FadePageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 600),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: child,
            );
          },
        );
}

/// Slide up transition with fade effect
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  SlideUpPageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.3);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end);
            final offsetAnimation = animation.drive(
              tween.chain(
                CurveTween(curve: Curves.easeOutQuart),
              ),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Zoom scale transition
class ZoomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  ZoomPageRoute({
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.85,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Shared axis transition for tab changes
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final SharedAxisTransitionType transitionType;
  final Duration duration;

  SharedAxisPageRoute({
    required this.child,
    this.transitionType = SharedAxisTransitionType.horizontal,
    this.duration = const Duration(milliseconds: 450),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            late Offset begin;
            const end = Offset.zero;

            switch (transitionType) {
              case SharedAxisTransitionType.horizontal:
                begin = const Offset(0.05, 0.0);
                break;
              case SharedAxisTransitionType.vertical:
                begin = const Offset(0.0, 0.05);
                break;
              case SharedAxisTransitionType.scaled:
                return _buildScaledTransition(animation, child);
            }

            return SlideTransition(
              position: Tween(begin: begin, end: end).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        );

  static Widget _buildScaledTransition(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.95,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}

enum SharedAxisTransitionType {
  horizontal,
  vertical,
  scaled,
}
