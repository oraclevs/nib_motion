import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/reduced_motion_mixin.dart';
import '../values/motion_value.dart';

/// Imperative handle for controlling a [NibDrawPath]'s reveal animation.
///
/// Mirrors `NibPathMotion`'s `NibPathMotionController` — this widget does
/// not integrate with `NibMotionController`/`NibMotionAnimator` since that
/// interface is shaped around property targets/keyframes, not path reveal
/// progress. Attach a [NibDrawPathController] via [NibDrawPath.controller]
/// and call [play], [pause], or [restart] directly.
class NibDrawPathController extends ChangeNotifier {
  _NibDrawPathState? _state;

  void _attach(_NibDrawPathState state) {
    _state = state;
  }

  void _detach(_NibDrawPathState state) {
    if (_state == state) _state = null;
  }

  /// Starts (or resumes) the reveal animation from its current progress.
  void play() => _state?._play();

  /// Pauses the reveal animation, freezing progress at its current value.
  void pause() => _state?._pause();

  /// Restarts the reveal animation from progress `0.0`.
  void restart() => _state?._restart();
}

/// Animates the drawing of [path] — like a signature or SVG stroke
/// animation.
///
/// `NibDrawPath` drives a `MotionValue<double>` progress value (`0.0` to
/// `1.0`) with a Ticker-based tween over [duration]/[curve] — the same
/// per-frame-write-into-a-MotionValue pattern [SpringSolver] uses, just
/// curve-tweened instead of spring-simulated. The underlying `RenderBox`
/// reads [path]'s `PathMetrics` directly in `paint()`, calling
/// `extractPath(0, length * progress)` to draw only the revealed portion —
/// animating never triggers a widget rebuild.
class NibDrawPath extends StatefulWidget {
  /// Creates a `NibDrawPath`.
  const NibDrawPath({
    super.key,
    required this.path,
    this.strokeWidth = 2.0,
    this.color = const Color(0xFF000000),
    this.strokeCap = StrokeCap.round,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeOut,
    this.autoPlay = true,
    this.repeat = false,
    this.controller,
  });

  /// The path progressively revealed as the animation plays.
  final Path path;

  /// The width of the stroke used to draw [path].
  final double strokeWidth;

  /// The color of the stroke used to draw [path].
  final Color color;

  /// The cap style of the stroke used to draw [path].
  final StrokeCap strokeCap;

  /// How long a full reveal of [path] takes.
  final Duration duration;

  /// The easing curve applied to the reveal.
  final Curve curve;

  /// Whether the reveal starts automatically on first build.
  final bool autoPlay;

  /// Whether the reveal restarts from `0.0` after completing.
  final bool repeat;

  /// Imperative handle for [play]/[pause]/[restart]. See
  /// [NibDrawPathController].
  final NibDrawPathController? controller;

  @override
  State<NibDrawPath> createState() => _NibDrawPathState();
}

class _NibDrawPathState extends State<NibDrawPath>
    with SingleTickerProviderStateMixin, NibReducedMotionMixin {
  final MotionValue<double> _progress = MotionValue<double>(0.0);

  Ticker? _ticker;
  Duration _startTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (widget.autoPlay) {
      _play();
    }
  }

  @override
  void didUpdateWidget(NibDrawPath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void onReducedMotionChanged(bool reduced) {
    if (reduced && (_ticker?.isActive ?? false)) {
      _ticker?.stop();
      _progress.value = 1.0;
    }
  }

  void _play() {
    if (reduceMotion) {
      _ticker?.stop();
      _progress.value = 1.0;
      return;
    }
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      _startTime = Duration.zero;
      ticker.start();
    }
  }

  void _pause() {
    _ticker?.stop();
  }

  void _restart() {
    _ticker?.stop();
    if (reduceMotion) {
      _progress.value = 1.0;
      return;
    }
    _progress.value = 0.0;
    _startTime = Duration.zero;
    (_ticker ??= createTicker(_onTick)).start();
  }

  void _onTick(Duration elapsed) {
    final durationUs = widget.duration.inMicroseconds;
    final elapsedUs = (elapsed - _startTime).inMicroseconds;
    final rawT =
        durationUs <= 0 ? 1.0 : (elapsedUs / durationUs).clamp(0.0, 1.0);
    final curvedT = widget.curve.transform(rawT);
    _progress.value = curvedT;

    if (rawT >= 1.0) {
      if (widget.repeat) {
        _startTime = elapsed;
        _progress.value = widget.curve.transform(0.0);
      } else {
        _ticker?.stop();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _ticker?.stop();
    _ticker?.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DrawPathBox(
      path: widget.path,
      progress: _progress,
      strokeWidth: widget.strokeWidth,
      color: widget.color,
      strokeCap: widget.strokeCap,
    );
  }
}

/// Bridges [progress] to [RenderNibDrawPath].
class _DrawPathBox extends LeafRenderObjectWidget {
  const _DrawPathBox({
    required this.path,
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.strokeCap,
  });

  final Path path;
  final MotionValue<double> progress;
  final double strokeWidth;
  final Color color;
  final StrokeCap strokeCap;

  @override
  RenderNibDrawPath createRenderObject(BuildContext context) {
    return RenderNibDrawPath(
      path: path,
      progress: progress,
      strokeWidth: strokeWidth,
      color: color,
      strokeCap: strokeCap,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibDrawPath renderObject) {
    renderObject
      ..path = path
      ..progress = progress
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = strokeCap;
  }
}

/// Paints only the portion of [path] revealed by the current [progress].
///
/// Reads [progress] directly during [paint] and calls [markNeedsPaint] when
/// it changes — animating [progress] never triggers a widget rebuild.
class RenderNibDrawPath extends RenderBox {
  /// Creates a render object that paints [path] up to [progress].
  RenderNibDrawPath({
    required Path path,
    required MotionValue<double> progress,
    required double strokeWidth,
    required Color color,
    required StrokeCap strokeCap,
  })  : _path = path,
        _progress = progress,
        _strokeWidth = strokeWidth,
        _color = color,
        _strokeCap = strokeCap {
    _progress.addListener(_onProgressChanged);
  }

  Path _path;
  MotionValue<double> _progress;
  double _strokeWidth;
  Color _color;
  StrokeCap _strokeCap;

  /// The full path this render object reveals a portion of.
  Path get path => _path;
  set path(Path value) {
    if (_path == value) return;
    _path = value;
    markNeedsPaint();
  }

  /// The current reveal progress, from `0.0` to `1.0`.
  MotionValue<double> get progress => _progress;
  set progress(MotionValue<double> value) {
    if (_progress == value) return;
    _progress.removeListener(_onProgressChanged);
    _progress = value;
    _progress.addListener(_onProgressChanged);
    markNeedsPaint();
  }

  /// The width of the stroke used to draw [path].
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    if (_strokeWidth == value) return;
    _strokeWidth = value;
    markNeedsPaint();
  }

  /// The color of the stroke used to draw [path].
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  /// The cap style of the stroke used to draw [path].
  StrokeCap get strokeCap => _strokeCap;
  set strokeCap(StrokeCap value) {
    if (_strokeCap == value) return;
    _strokeCap = value;
    markNeedsPaint();
  }

  void _onProgressChanged() => markNeedsPaint();

  @override
  void performLayout() {
    size = constraints.biggest.isFinite
        ? constraints.biggest
        : constraints.constrain(_path.getBounds().size);
  }

  @override
  bool get sizedByParent => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    // PathMetrics only supports a single iteration pass — checking
    // `.isEmpty` first and then iterating separately would consume the
    // underlying iterator twice. Collect it once into a list instead.
    final metrics = _path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = _strokeCap
      ..color = _color;

    final clampedProgress = _progress.value.clamp(0.0, 1.0);
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    for (final metric in metrics) {
      if (metric.length <= 0) continue;
      final extracted = metric.extractPath(0, metric.length * clampedProgress);
      context.canvas.drawPath(extracted, paint);
    }
    context.canvas.restore();
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    super.dispose();
  }
}
