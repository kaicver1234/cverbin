import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Parallax scrolling effect widget
class ParallaxContainer extends StatelessWidget {
  final Widget child;
  final double parallaxOffset;
  final ScrollController? scrollController;

  const ParallaxContainer({
    Key? key,
    required this.child,
    this.parallaxOffset = 0.3,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _ParallaxFlow(
      scrollController: scrollController,
      parallaxOffset: parallaxOffset,
      child: child,
    );
  }
}

class _ParallaxFlow extends SingleChildRenderObjectWidget {
  final ScrollController? scrollController;
  final double parallaxOffset;

  const _ParallaxFlow({
    required Widget child,
    this.scrollController,
    required this.parallaxOffset,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderParallaxFlow(
      scrollable: Scrollable.of(context),
      parallaxOffset: parallaxOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderParallaxFlow renderObject,
  ) {
    renderObject
      ..scrollable = Scrollable.of(context)
      ..parallaxOffset = parallaxOffset;
  }
}

class _RenderParallaxFlow extends RenderProxyBox {
  _RenderParallaxFlow({
    required ScrollableState scrollable,
    required double parallaxOffset,
  })  : _scrollable = scrollable,
        _parallaxOffset = parallaxOffset;

  ScrollableState _scrollable;
  double _parallaxOffset;

  set scrollable(ScrollableState value) {
    if (value != _scrollable) {
      if (attached) {
        _scrollable.position.removeListener(markNeedsLayout);
      }
      _scrollable = value;
      if (attached) {
        _scrollable.position.addListener(markNeedsLayout);
      }
    }
  }

  set parallaxOffset(double value) {
    if (value != _parallaxOffset) {
      _parallaxOffset = value;
      markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollable.position.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _scrollable.position.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final scrollableBox = _scrollable.context.findRenderObject() as RenderBox;
    final scrollableOffset = localToGlobal(
      Offset.zero,
      ancestor: scrollableBox,
    );
    final viewportHeight = _scrollable.position.viewportDimension;
    final scrollPosition = _scrollable.position.pixels;
    final parallaxMainOffset = scrollableOffset.dy * _parallaxOffset;

    context.pushTransform(
      true,
      offset,
      Matrix4.translationValues(0.0, parallaxMainOffset, 0.0),
      (context, offset) {
        context.paintChild(child!, offset);
      },
    );
  }
}

/// Animated parallax background
class AnimatedParallaxBackground extends StatefulWidget {
  final List<ParallaxLayer> layers;
  final Widget child;
  final ScrollController? scrollController;

  const AnimatedParallaxBackground({
    Key? key,
    required this.layers,
    required this.child,
    this.scrollController,
  }) : super(key: key);

  @override
  State<AnimatedParallaxBackground> createState() => _AnimatedParallaxBackgroundState();
}

class _AnimatedParallaxBackgroundState extends State<AnimatedParallaxBackground> {
  late ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_updateScrollOffset);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _updateScrollOffset() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...widget.layers.map((layer) {
          final offset = _scrollOffset * layer.speed;
          return Positioned(
            left: 0,
            right: 0,
            top: layer.yOffset - offset,
            child: Transform.translate(
              offset: Offset(layer.xOffset, 0),
              child: layer.child,
            ),
          );
        }).toList(),
        widget.child,
      ],
    );
  }
}

class ParallaxLayer {
  final Widget child;
  final double speed;
  final double xOffset;
  final double yOffset;

  ParallaxLayer({
    required this.child,
    this.speed = 0.5,
    this.xOffset = 0,
    this.yOffset = 0,
  });
}

/// Floating animation widget
class FloatingWidget extends StatefulWidget {
  final Widget child;
  final double floatingRange;
  final Duration duration;
  final Curve curve;

  const FloatingWidget({
    Key? key,
    required this.child,
    this.floatingRange = 10,
    this.duration = const Duration(seconds: 2),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -widget.floatingRange,
      end: widget.floatingRange,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}
