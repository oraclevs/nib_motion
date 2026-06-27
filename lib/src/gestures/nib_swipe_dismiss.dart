import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../values/motion_value.dart';

/// Bridges the [MotionValue] owned by [NibSwipeDismiss] to
/// [_RenderNibSwipeDismiss].
class _NibSwipeDismissBox extends SingleChildRenderObjectWidget {
  const _NibSwipeDismissBox({required this.offset, required this.vertical, super.child});

  final MotionValue<double> offset;
  final bool vertical;

  @override
  _RenderNibSwipeDismiss createRenderObject(BuildContext context) {
    return _RenderNibSwipeDismiss(offset: offset, vertical: vertical);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderNibSwipeDismiss renderObject) {
    renderObject
      ..offset = offset
      ..vertical = vertical;
  }
}

/// Paints [child] translated along a single axis by [offset], reading it
/// directly during [paint] so swiping never triggers a widget rebuild.
class _RenderNibSwipeDismiss extends RenderProxyBox {
  _RenderNibSwipeDismiss({required MotionValue<double> offset, required bool vertical})
    : _offset = offset,
      _vertical = vertical {
    _offset.addListener(_onChanged);
  }

  MotionValue<double> _offset;
  bool _vertical;

  /// The current translation along the dismiss axis, in logical pixels.
  MotionValue<double> get offset => _offset;
  set offset(MotionValue<double> value) {
    if (_offset == value) return;
    _offset.removeListener(_onChanged);
    _offset = value;
    _offset.addListener(_onChanged);
    markNeedsPaint();
  }

  /// Whether [offset] translates vertically instead of horizontally.
  bool get vertical => _vertical;
  set vertical(bool value) {
    if (_vertical == value) return;
    _vertical = value;
    markNeedsPaint();
  }

  void _onChanged() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    final delta = _offset.value;
    if (delta == 0.0) {
      super.paint(context, offset);
      return;
    }
    final translation = _vertical ? Offset(0.0, delta) : Offset(delta, 0.0);
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(translation.dx, translation.dy, 0.0),
      (context, offset) => super.paint(context, offset),
    );
  }

  @override
  void dispose() {
    _offset.removeListener(_onChanged);
    super.dispose();
  }
}

/// The axis (and, for horizontal/vertical, the allowed direction) a
/// [NibSwipeDismiss] can be swiped in.
enum DismissDirection {
  /// Swiping left or right both trigger dismissal.
  horizontal,

  /// Swiping up or down both trigger dismissal.
  vertical,

  /// Only swiping left-to-right (i.e. a positive horizontal offset)
  /// triggers dismissal.
  startToEnd,

  /// Only swiping right-to-left (i.e. a negative horizontal offset)
  /// triggers dismissal.
  endToStart,
}

/// Swipes a widget horizontally (or vertically) to dismiss it, with a
/// threshold and spring-back.
///
/// Holds a single [MotionValue<double>] for the current offset along the
/// dismiss axis, written directly from `GestureDetector.onPanUpdate` and
/// read directly by a [RenderProxyBox] during `paint` — swiping never
/// triggers a widget rebuild. On release: if the offset exceeds
/// `dismissThreshold * extent`, the widget is animated off-screen via a raw
/// [Ticker]-driven decelerating tween and [onDismissed] is called; otherwise
/// it springs back to `0` using the release velocity.
class NibSwipeDismiss extends StatefulWidget {
  /// Creates a swipe-to-dismiss wrapper around [child].
  const NibSwipeDismiss({
    super.key,
    required this.child,
    required this.onDismissed,
    this.dismissThreshold = 0.5,
    this.dismissDirection = DismissDirection.horizontal,
    this.background,
    this.spring = NibSpringDescription.gentle,
  });

  /// The widget to make dismissible.
  final Widget child;

  /// Called once the widget has finished animating off-screen past
  /// [dismissThreshold].
  final VoidCallback onDismissed;

  /// The fraction of the widget's extent (width for horizontal directions,
  /// height for vertical) the swipe must cross before release triggers a
  /// dismissal instead of a spring-back.
  final double dismissThreshold;

  /// Which direction(s) of swipe are recognized.
  final DismissDirection dismissDirection;

  /// A widget shown behind [child] (via a [Stack]) while swiping.
  final Widget? background;

  /// The spring physics used to animate back to `0` when the swipe doesn't
  /// cross [dismissThreshold].
  final NibSpringDescription spring;

  @override
  State<NibSwipeDismiss> createState() => _NibSwipeDismissState();
}

class _NibSwipeDismissState extends State<NibSwipeDismiss> with TickerProviderStateMixin {
  final MotionValue<double> _offset = MotionValue<double>(0.0);

  SpringSolver? _springSolver;
  Ticker? _flingTicker;
  VelocityTracker? _velocityTracker;

  bool get _vertical => widget.dismissDirection == DismissDirection.vertical;

  @override
  void dispose() {
    _springSolver?.dispose();
    _flingTicker?.dispose();
    super.dispose();
  }

  double _axisDelta(DragUpdateDetails details) {
    return _vertical ? details.delta.dy : details.delta.dx;
  }

  void _handlePanStart(DragStartDetails details) {
    _springSolver?.stop();
    _flingTicker?.stop();
    _velocityTracker = VelocityTracker.withKind(details.kind ?? PointerDeviceKind.touch);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _velocityTracker?.addPosition(details.sourceTimeStamp ?? Duration.zero, details.globalPosition);

    var newOffset = _offset.value + _axisDelta(details);

    switch (widget.dismissDirection) {
      case DismissDirection.startToEnd:
        if (newOffset < 0.0) newOffset = 0.0;
      case DismissDirection.endToStart:
        if (newOffset > 0.0) newOffset = 0.0;
      case DismissDirection.horizontal:
      case DismissDirection.vertical:
        break;
    }

    _offset.value = newOffset;
  }

  void _handlePanEnd(DragEndDetails details) {
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    _velocityTracker = null;

    final size = context.size;
    final extent = size == null ? 0.0 : (_vertical ? size.height : size.width);
    final threshold = widget.dismissThreshold * extent;
    final axisVelocity = _vertical ? velocity.pixelsPerSecond.dy : velocity.pixelsPerSecond.dx;

    if (extent > 0 && _offset.value.abs() > threshold) {
      _animateOffscreen(extent, axisVelocity);
    } else {
      _springBack(axisVelocity);
    }
  }

  void _springBack(double initialVelocity) {
    final solver = _springSolver ??= SpringSolver(vsync: this, value: _offset, spring: widget.spring);
    solver.spring = widget.spring;
    solver.animateTo(target: 0.0, initialVelocity: initialVelocity);
  }

  void _animateOffscreen(double extent, double releaseVelocity) {
    final start = _offset.value;
    final direction = start >= 0 ? 1.0 : -1.0;
    final target = direction * extent * 1.5;

    // A simple decelerating tween driven by a raw Ticker (no
    // AnimationController): eases from the release position/velocity to
    // fully off-screen over a fixed duration using an ease-out curve.
    const duration = Duration(milliseconds: 240);
    final durationSeconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

    _flingTicker?.dispose();
    _flingTicker = createTicker((elapsed) {
      final t = (elapsed.inMicroseconds / Duration.microsecondsPerSecond / durationSeconds).clamp(0.0, 1.0);
      final eased = Curves.easeOut.transform(t);
      _offset.value = start + (target - start) * eased;
      if (t >= 1.0) {
        _flingTicker?.stop();
        widget.onDismissed();
      }
    });
    _flingTicker!.start();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.background;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: background == null
          ? _NibSwipeDismissBox(offset: _offset, vertical: _vertical, child: widget.child)
          : Stack(
              children: [
                Positioned.fill(child: background),
                _NibSwipeDismissBox(offset: _offset, vertical: _vertical, child: widget.child),
              ],
            ),
    );
  }
}
