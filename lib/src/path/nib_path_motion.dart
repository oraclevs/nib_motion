import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';

/// Imperative handle for controlling a [NibPathMotion]'s traversal.
///
/// Unlike most animated primitives in this package, [NibPathMotion] does not
/// integrate with `NibMotionController`/`NibMotionAnimator` — that interface
/// is shaped around [NibAnim] property targets, keyframes, and exit/replay
/// semantics that don't map cleanly onto "where along this path am I."
/// Instead, attach a [NibPathMotionController] via [NibPathMotion.controller]
/// and call [play], [pause], or [restart] directly:
///
/// ```dart
/// final controller = NibPathMotionController();
///
/// NibPathMotion(
///   controller: controller,
///   path: myPath,
///   child: const Icon(Icons.flight),
/// );
///
/// controller.restart(); // restarts traversal from progress 0.0
/// ```
class NibPathMotionController extends ChangeNotifier {
  _NibPathMotionState? _state;

  void _attach(_NibPathMotionState state) {
    _state = state;
  }

  void _detach(_NibPathMotionState state) {
    if (_state == state) _state = null;
  }

  /// Starts (or resumes) the path traversal from its current progress.
  void play() => _state?._play();

  /// Pauses the path traversal, freezing progress at its current value.
  void pause() => _state?._pause();

  /// Restarts the path traversal from progress `0.0`, as if the widget had
  /// just been built for the first time (i.e. replays its "entrance").
  void restart() => _state?._restart();
}

/// Animates [child]'s position (and optionally rotation) along a custom
/// [Path].
///
/// `NibPathMotion` drives a `MotionValue<double>` progress value (`0.0` to
/// `1.0`) with a Ticker-based tween over [duration]/[curve] — the same
/// per-frame-write-into-a-MotionValue pattern [SpringSolver] uses, just
/// curve-tweened instead of spring-simulated. `RenderProxyBox` reads
/// [path]'s `PathMetrics` directly in `paint()` and translates (and, if
/// [rotate] is true, rotates) [child] to the tangent point at the current
/// progress — animating never triggers a widget rebuild.
///
/// If [progress] is supplied, this widget reads that external
/// [MotionValue<double>] instead of driving its own — the same "external
/// MotionValue override" pattern `NibMotion` itself uses for `motionValues`.
class NibPathMotion extends StatefulWidget {
  /// Creates a `NibPathMotion`.
  const NibPathMotion({
    super.key,
    required this.child,
    required this.path,
    this.progress,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeInOut,
    this.repeat = false,
    this.autoPlay = true,
    this.rotate = false,
    this.controller,
  });

  /// The widget moved along [path].
  final Widget child;

  /// The path [child] travels along, in this widget's local coordinate
  /// space.
  final Path path;

  /// An external progress value (`0.0` to `1.0`) to read instead of driving
  /// an internal ticker. When supplied, [duration], [curve], [repeat], and
  /// [autoPlay] are ignored — the caller is fully responsible for driving
  /// this value.
  final MotionValue<double>? progress;

  /// How long a single traversal of [path] takes, when [progress] is not
  /// supplied.
  final Duration duration;

  /// The easing curve applied to traversal, when [progress] is not supplied.
  final Curve curve;

  /// Whether traversal restarts from `0.0` after completing, when
  /// [progress] is not supplied.
  final bool repeat;

  /// Whether traversal starts automatically on first build, when
  /// [progress] is not supplied.
  final bool autoPlay;

  /// Whether [child] is rotated to align with [path]'s tangent direction at
  /// the current progress.
  final bool rotate;

  /// Imperative handle for [play]/[pause]/[restart]. See
  /// [NibPathMotionController].
  final NibPathMotionController? controller;

  @override
  State<NibPathMotion> createState() => _NibPathMotionState();
}

class _NibPathMotionState extends State<NibPathMotion>
    with SingleTickerProviderStateMixin {
  late MotionValue<double> _progress;
  bool _ownsProgress = false;

  Ticker? _ticker;
  Duration _startTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bindProgress();
    widget.controller?._attach(this);
    if (_ownsProgress && widget.autoPlay) {
      _play();
    }
  }

  void _bindProgress() {
    final external = widget.progress;
    if (external != null) {
      if (_ownsProgress) _progress.dispose();
      _progress = external;
      _ownsProgress = false;
    } else if (!_ownsProgress) {
      _progress = MotionValue<double>(0.0);
      _ownsProgress = true;
    }
  }

  @override
  void didUpdateWidget(NibPathMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.progress != widget.progress) {
      _ticker?.stop();
      _bindProgress();
      if (_ownsProgress && widget.autoPlay) {
        _play();
      }
    }
  }

  void _play() {
    if (!_ownsProgress) return; // external progress: caller drives it.
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
    if (!_ownsProgress) return;
    _progress.value = 0.0;
    _ticker?.stop();
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
    if (_ownsProgress) {
      _progress.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PathMotionBox(
      path: widget.path,
      progress: _progress,
      rotate: widget.rotate,
      child: widget.child,
    );
  }
}

/// Bridges [progress] to [RenderNibPathMotion].
class _PathMotionBox extends SingleChildRenderObjectWidget {
  const _PathMotionBox({
    required this.path,
    required this.progress,
    required this.rotate,
    super.child,
  });

  final Path path;
  final MotionValue<double> progress;
  final bool rotate;

  @override
  RenderNibPathMotion createRenderObject(BuildContext context) {
    return RenderNibPathMotion(path: path, progress: progress, rotate: rotate);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibPathMotion renderObject) {
    renderObject
      ..path = path
      ..progress = progress
      ..rotate = rotate;
  }
}

/// Translates (and optionally rotates) [child] to the point on [path] at
/// the current [progress].
///
/// Reads [progress] directly during [paint] and calls [markNeedsPaint] when
/// it changes — animating [progress] never triggers a widget rebuild.
class RenderNibPathMotion extends RenderProxyBox {
  /// Creates a render object that positions [child] along [path].
  RenderNibPathMotion({
    required Path path,
    required MotionValue<double> progress,
    required bool rotate,
    RenderBox? child,
  })  : _path = path,
        _progress = progress,
        _rotate = rotate,
        super(child) {
    _progress.addListener(_onProgressChanged);
  }

  Path _path;
  MotionValue<double> _progress;
  bool _rotate;

  /// The path [child] is positioned along.
  Path get path => _path;
  set path(Path value) {
    if (_path == value) return;
    _path = value;
    markNeedsPaint();
  }

  /// The current traversal progress, from `0.0` to `1.0`.
  MotionValue<double> get progress => _progress;
  set progress(MotionValue<double> value) {
    if (_progress == value) return;
    _progress.removeListener(_onProgressChanged);
    _progress = value;
    _progress.addListener(_onProgressChanged);
    markNeedsPaint();
  }

  /// Whether [child] is rotated to align with the path's tangent direction.
  bool get rotate => _rotate;
  set rotate(bool value) {
    if (_rotate == value) return;
    _rotate = value;
    markNeedsPaint();
  }

  void _onProgressChanged() => markNeedsPaint();

  /// Computes the current path-following transform, or `null` if [path] has
  /// no measurable contour (in which case [child] paints at its natural
  /// position with no transform).
  ///
  /// Shared by [paint] and [applyPaintTransform] so hit-testing and
  /// `RenderBox.getTransformTo`/`WidgetTester.getTopLeft` agree with what's
  /// actually painted — `pushTransform` alone only affects painting, not the
  /// transform ancestors report for hit-testing or global-coordinate lookups.
  Matrix4? _currentTransform() {
    // PathMetrics is a single-pass Iterable — calling `.isEmpty` then
    // `.first` separately would consume the underlying iterator twice and
    // throw "Bad state: No element" on the second access. Use a single
    // iterator pass instead.
    final iterator = _path.computeMetrics().iterator;
    if (!iterator.moveNext()) return null;
    final metric = iterator.current;
    if (metric.length <= 0) return null;

    final clampedProgress = _progress.value.clamp(0.0, 1.0);
    final tangent = metric.getTangentForOffset(metric.length * clampedProgress);
    if (tangent == null) return null;

    final matrix = Matrix4.translationValues(
      tangent.position.dx,
      tangent.position.dy,
      0.0,
    );
    if (_rotate) {
      matrix.multiply(Matrix4.rotationZ(tangent.angle));
    }
    return matrix;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final matrix = _currentTransform();
    if (matrix == null) {
      super.paint(context, offset);
      return;
    }
    context.pushTransform(needsCompositing, offset, matrix, super.paint);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final matrix = _currentTransform();
    if (matrix != null) transform.multiply(matrix);
    super.applyPaintTransform(child, transform);
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    super.dispose();
  }
}
