import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';

/// A 3D card-flip widget that reveals [back] in place of [front] (or vice
/// versa) when [isFlipped] changes.
///
/// ```dart
/// bool _isFlipped = false;
///
/// NibFlip(
///   isFlipped: _isFlipped,
///   front: const Card(child: Text('Question')),
///   back: const Card(child: Text('Answer')),
/// )
///
/// // Elsewhere, e.g. on tap:
/// setState(() => _isFlipped = !_isFlipped);
/// ```
///
/// The flip progress is driven by a raw [Ticker] writing to a
/// [MotionValue<double>] that a custom [RenderObject] reads directly during
/// paint — consistent with the rest of this package, no
/// [AnimationController] is used as the driver for this non-`NibMotion`
/// property. At progress `>= 0.5` the visible face switches from [front] to
/// [back] (or back again).
class NibFlip extends StatefulWidget {
  /// Creates a `NibFlip`.
  const NibFlip({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.duration = const Duration(milliseconds: 600),
    this.flipAxis = Axis.horizontal,
  });

  /// The widget shown while the flip progress is below `0.5`.
  final Widget front;

  /// The widget shown while the flip progress is at or above `0.5`.
  final Widget back;

  /// Which face should be facing forward. Toggling this animates the flip.
  final bool isFlipped;

  /// How long the flip animation takes to play out.
  final Duration duration;

  /// The axis the card rotates around: [Axis.horizontal] rotates around the
  /// vertical (Y) axis, [Axis.vertical] rotates around the horizontal (X)
  /// axis.
  final Axis flipAxis;

  @override
  State<NibFlip> createState() => _NibFlipState();
}

class _NibFlipState extends State<NibFlip> with SingleTickerProviderStateMixin {
  late final MotionValue<double> _progress;
  Ticker? _ticker;
  double _from = 0.0;
  double _to = 0.0;

  @override
  void initState() {
    super.initState();
    _progress = MotionValue<double>(widget.isFlipped ? 1.0 : 0.0);
  }

  @override
  void didUpdateWidget(NibFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      _animateTo(widget.isFlipped ? 1.0 : 0.0);
    }
  }

  /// Starts (or restarts) a [Ticker]-driven tween of [_progress] from its
  /// current value to [target], easing with [Curves.easeInOut] over
  /// [NibFlip.duration]. Mirrors the manual elapsed-time tracking pattern
  /// `SpringSolver`/`InertiaSolver` use, since [_progress] is not one of
  /// `NibMotion`'s own animatable properties.
  void _animateTo(double target) {
    _from = _progress.value;
    _to = target;
    _ticker?.stop();
    (_ticker ??= createTicker(_onTick)).start();
  }

  void _onTick(Duration elapsed) {
    final durationMicros = widget.duration.inMicroseconds;
    final elapsedMicros = elapsed.inMicroseconds;
    final rawT = durationMicros <= 0
        ? 1.0
        : (elapsedMicros / durationMicros).clamp(0.0, 1.0);
    final curvedT = Curves.easeInOut.transform(rawT);
    _progress.value = _from + (_to - _from) * curvedT;
    if (rawT >= 1.0) {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NibFlipBox(
      progress: _progress,
      flipAxis: widget.flipAxis,
      front: widget.front,
      back: widget.back,
    );
  }
}

/// Lays out [front] and [back] stacked on top of each other (sized to fit
/// both), and paints only whichever is the current visible face according to
/// [progress], rotated in 3D around the center of the stack.
class _NibFlipBox extends StatelessWidget {
  const _NibFlipBox(
      {required this.progress,
      required this.flipAxis,
      required this.front,
      required this.back});

  final MotionValue<double> progress;
  final Axis flipAxis;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        _NibFlipFace(
            progress: progress,
            flipAxis: flipAxis,
            showBack: false,
            child: front),
        _NibFlipFace(
            progress: progress,
            flipAxis: flipAxis,
            showBack: true,
            child: back),
      ],
    );
  }
}

/// One face (front or back) of a [NibFlip]. Paints [child] with the
/// continuous 3D rotation matrix for [progress], but only while this face is
/// the currently-visible one — otherwise it paints nothing and does not hit
/// test, so both faces can be stacked without either blocking the other.
class _NibFlipFace extends SingleChildRenderObjectWidget {
  const _NibFlipFace(
      {required this.progress,
      required this.flipAxis,
      required this.showBack,
      required Widget child})
      : super(child: child);

  final MotionValue<double> progress;
  final Axis flipAxis;
  final bool showBack;

  @override
  _RenderNibFlipFace createRenderObject(BuildContext context) {
    return _RenderNibFlipFace(
        progress: progress, flipAxis: flipAxis, showBack: showBack);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderNibFlipFace renderObject) {
    renderObject
      ..progress = progress
      ..flipAxis = flipAxis
      ..showBack = showBack;
  }
}

class _RenderNibFlipFace extends RenderProxyBox {
  _RenderNibFlipFace(
      {required MotionValue<double> progress,
      required Axis flipAxis,
      required bool showBack})
      : _progress = progress,
        _flipAxis = flipAxis,
        _showBack = showBack {
    _progress.addListener(_onProgressChanged);
  }

  MotionValue<double> _progress;
  MotionValue<double> get progress => _progress;
  set progress(MotionValue<double> value) {
    if (_progress == value) return;
    _progress.removeListener(_onProgressChanged);
    _progress = value;
    _progress.addListener(_onProgressChanged);
    markNeedsPaint();
  }

  Axis _flipAxis;
  Axis get flipAxis => _flipAxis;
  set flipAxis(Axis value) {
    if (_flipAxis == value) return;
    _flipAxis = value;
    markNeedsPaint();
  }

  bool _showBack;
  bool get showBack => _showBack;
  set showBack(bool value) {
    if (_showBack == value) return;
    _showBack = value;
    markNeedsPaint();
  }

  void _onProgressChanged() => markNeedsPaint();

  bool get _isVisibleFace => _showBack == (_progress.value >= 0.5);

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_isVisibleFace) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_isVisibleFace) return;

    final t = _progress.value;
    // The visible face rotates from 0 -> 90deg as it leaves view, and the
    // other face continues that same rotation from 90 -> 180deg (mod 180)
    // as it arrives, so the matrix is continuous across the swap.
    final angle = (_showBack ? (t - 1.0) : t) * math.pi;

    final center = size.center(Offset.zero);
    final matrix = Matrix4.translationValues(center.dx, center.dy, 0.0)
      ..setEntry(3, 2, 0.001)
      ..multiply(_flipAxis == Axis.horizontal
          ? Matrix4.rotationY(angle)
          : Matrix4.rotationX(angle))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0.0));

    context.pushTransform(needsCompositing, offset, matrix, super.paint);
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    super.dispose();
  }
}
