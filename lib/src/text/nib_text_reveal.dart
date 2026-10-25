import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/nib_motion_controller.dart';
import '../core/reduced_motion_mixin.dart';
import '../values/motion_value.dart';

/// The edge from which a [NibTextReveal] wipes its child into view.
enum NibTextRevealDirection {
  /// Reveals left-to-right, clipping from the left edge.
  left,

  /// Reveals right-to-left, clipping from the right edge.
  right,

  /// Reveals bottom-to-top, clipping from the top edge.
  up,

  /// Reveals top-to-bottom, clipping from the bottom edge.
  down,
}

/// Reveals [child] (typically a block of text) by animating a clip mask that
/// wipes in from [direction] — the whole block reveals at once, with no
/// per-character splitting.
///
/// The clip's size factor is driven by a `MotionValue<double>` (`0.0` fully
/// clipped, `1.0` fully revealed) ticked by a `SpringSolver` (or a plain
/// `AnimationController`-driven tween when no spring is requested), and read
/// directly by `RenderNibTextReveal.paint` — the same zero-setState pattern
/// `RenderNibMotion` uses elsewhere in this package.
class NibTextReveal extends StatefulWidget {
  /// Creates a `NibTextReveal` that wipes [child] into view from [direction].
  const NibTextReveal({
    super.key,
    required this.child,
    this.direction = NibTextRevealDirection.left,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeInOut,
    this.controller,
  });

  /// The content being revealed.
  final Widget child;

  /// The edge the reveal wipes in from.
  final NibTextRevealDirection direction;

  /// How long the reveal animation takes.
  final Duration duration;

  /// How long to wait before the reveal starts.
  final Duration delay;

  /// The easing curve for the reveal.
  final Curve curve;

  /// An optional external handle for replaying the reveal via
  /// [NibMotionController.start].
  final NibMotionController? controller;

  @override
  State<NibTextReveal> createState() => _NibTextRevealState();
}

class _NibTextRevealState extends State<NibTextReveal>
    with SingleTickerProviderStateMixin, NibReducedMotionMixin {
  late final MotionValue<double> _factor = MotionValue<double>(0.0);
  AnimationController? _tweenController;
  VoidCallback? _tweenListener;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void onReducedMotionChanged(bool reduced) {
    if (reduced) {
      _tweenController?.stop();
      _factor.value = 1.0;
    }
  }

  void _scheduleReveal() {
    if (reduceMotion) {
      _factor.value = 1.0;
      return;
    }
    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, _runReveal);
    } else {
      _runReveal();
    }
  }

  void _runReveal() {
    if (!mounted) return;
    final controller =
        AnimationController(vsync: this, duration: widget.duration);
    _tweenController = controller;

    void listener() {
      _factor.value = widget.curve.transform(controller.value);
    }

    _tweenListener = listener;
    controller.addListener(listener);
    controller.forward(from: 0.0);
  }

  /// Resets the clip to fully hidden and replays the reveal from the start.
  void replay() {
    _tweenController?.stop();
    _factor.value = 0.0;
    _scheduleReveal();
  }

  @override
  void dispose() {
    final listener = _tweenListener;
    if (listener != null) _tweenController?.removeListener(listener);
    _tweenController?.dispose();
    _factor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NibTextRevealBox(
      direction: widget.direction,
      factor: _factor,
      child: widget.child,
    );
  }
}

/// Bridges [factor] to [RenderNibTextReveal].
class _NibTextRevealBox extends SingleChildRenderObjectWidget {
  const _NibTextRevealBox({
    required this.direction,
    required this.factor,
    super.child,
  });

  final NibTextRevealDirection direction;
  final MotionValue<double> factor;

  @override
  RenderNibTextReveal createRenderObject(BuildContext context) {
    return RenderNibTextReveal(direction: direction, factor: factor);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibTextReveal renderObject) {
    renderObject
      ..direction = direction
      ..factor = factor;
  }
}

/// Clips its child according to [factor] (`0.0` fully clipped away, `1.0`
/// fully visible), wiping in from [direction].
///
/// [factor] is read directly during [paint] and this render object listens
/// for its changes via [markNeedsPaint] — animating never triggers a widget
/// rebuild, matching `RenderNibMotion`'s pattern.
class RenderNibTextReveal extends RenderProxyBox {
  /// Creates a render object that clips [child] according to [factor].
  RenderNibTextReveal({
    required NibTextRevealDirection direction,
    required MotionValue<double> factor,
    RenderBox? child,
  })  : _direction = direction,
        _factor = factor,
        super(child) {
    _factor.addListener(_onFactorChanged);
  }

  NibTextRevealDirection _direction;
  MotionValue<double> _factor;

  /// The edge the reveal wipes in from.
  NibTextRevealDirection get direction => _direction;
  set direction(NibTextRevealDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsPaint();
  }

  /// The reveal progress, from `0.0` (fully clipped) to `1.0` (fully
  /// visible).
  MotionValue<double> get factor => _factor;
  set factor(MotionValue<double> value) {
    if (_factor == value) return;
    _factor.removeListener(_onFactorChanged);
    _factor = value;
    _factor.addListener(_onFactorChanged);
    markNeedsPaint();
  }

  void _onFactorChanged() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    final t = _factor.value.clamp(0.0, 1.0);
    if (t <= 0.0) return;
    if (t >= 1.0) {
      super.paint(context, offset);
      return;
    }

    final fullRect = offset & size;
    final clipRect = switch (_direction) {
      NibTextRevealDirection.left => Rect.fromLTWH(
          fullRect.left,
          fullRect.top,
          fullRect.width * t,
          fullRect.height,
        ),
      NibTextRevealDirection.right => Rect.fromLTWH(
          fullRect.right - fullRect.width * t,
          fullRect.top,
          fullRect.width * t,
          fullRect.height,
        ),
      NibTextRevealDirection.up => Rect.fromLTWH(
          fullRect.left,
          fullRect.bottom - fullRect.height * t,
          fullRect.width,
          fullRect.height * t,
        ),
      NibTextRevealDirection.down => Rect.fromLTWH(
          fullRect.left,
          fullRect.top,
          fullRect.width,
          fullRect.height * t,
        ),
    };

    context.pushClipRect(needsCompositing, offset, clipRect, super.paint);
  }

  @override
  void dispose() {
    _factor.removeListener(_onFactorChanged);
    super.dispose();
  }
}
