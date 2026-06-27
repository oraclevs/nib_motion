import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';
import 'shader_loader.dart';

/// Paints a GPU-accelerated diagonal shimmer sweep over [child].
///
/// `NibShimmer` is a drop-in, GPU-optimal replacement for the CSS-style
/// shimmer effect skeleton loaders typically build out of an
/// [AnimatedContainer]/gradient combo. The sweep position (`uTime`) is
/// driven by a raw [Ticker] writing into a [MotionValue<double>] — exactly
/// the pattern [SpringSolver] uses — so the running animation never causes
/// a widget rebuild; only [RenderNibShimmer.paint] is re-invoked.
///
/// If the bundled shimmer shader hasn't finished compiling yet (or fails to
/// compile, e.g. because the host app doesn't declare `nib_motion`'s
/// shaders as assets), [child] is painted as-is with no shimmer overlay.
class NibShimmer extends StatefulWidget {
  /// Creates a shimmer overlay around [child].
  const NibShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.shimmerColor,
    this.speed = 1.5,
    this.angle = -0.3,
    this.enabled = true,
  });

  /// The widget the shimmer sweep is painted over.
  final Widget child;

  /// The background color the shimmer band is mixed over.
  ///
  /// Defaults to the ambient theme's surface color when `null` (resolved as
  /// `Theme.of(context).colorScheme.surface` is not available without a
  /// Material dependency, so this resolves to a neutral light grey).
  final Color? baseColor;

  /// The highlight color of the sweeping band.
  ///
  /// Defaults to a lighter tint of [baseColor] when `null`.
  final Color? shimmerColor;

  /// How fast the shimmer band sweeps across [child], in sweeps per second.
  final double speed;

  /// The sweep angle, in radians.
  final double angle;

  /// Whether the shimmer animation is active.
  ///
  /// When `false`, [child] is painted with no shimmer overlay and the
  /// underlying [Ticker] is stopped.
  final bool enabled;

  @override
  State<NibShimmer> createState() => _NibShimmerState();
}

class _NibShimmerState extends State<NibShimmer>
    with SingleTickerProviderStateMixin {
  final MotionValue<double> _time = MotionValue<double>(0);
  Ticker? _ticker;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadProgram();
    if (widget.enabled) _startTicker();
  }

  Future<void> _loadProgram() async {
    try {
      final program = await NibShaderLoader.shimmer();
      if (!mounted) return;
      setState(() => _program = program);
    } catch (_) {
      // Shader unavailable (not bundled, or compilation failed in this
      // environment) — `build` falls back to painting `child` directly.
    }
  }

  void _startTicker() {
    (_ticker ??= createTicker(_onTick)).start();
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void didUpdateWidget(NibShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _startTicker();
    } else if (!widget.enabled && oldWidget.enabled) {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null || !widget.enabled) {
      return widget.child;
    }

    final baseColor = widget.baseColor ?? const Color(0xFFE0E0E0);
    final shimmerColor = widget.shimmerColor ?? const Color(0xFFF5F5F5);

    return _NibShimmerLayer(
      time: _time,
      program: program,
      baseColor: baseColor,
      shimmerColor: shimmerColor,
      speed: widget.speed,
      angle: widget.angle,
      child: widget.child,
    );
  }
}

class _NibShimmerLayer extends SingleChildRenderObjectWidget {
  const _NibShimmerLayer({
    required this.time,
    required this.program,
    required this.baseColor,
    required this.shimmerColor,
    required this.speed,
    required this.angle,
    required Widget child,
  }) : super(child: child);

  final MotionValue<double> time;
  final FragmentProgram program;
  final Color baseColor;
  final Color shimmerColor;
  final double speed;
  final double angle;

  @override
  RenderNibShimmer createRenderObject(BuildContext context) {
    return RenderNibShimmer(
      time: time,
      program: program,
      baseColor: baseColor,
      shimmerColor: shimmerColor,
      speed: speed,
      angle: angle,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderNibShimmer renderObject) {
    renderObject
      ..time = time
      ..program = program
      ..baseColor = baseColor
      ..shimmerColor = shimmerColor
      ..speed = speed
      ..angle = angle;
  }
}

/// Paints [child] with the shimmer [FragmentShader] composited over it.
///
/// Follows the same reactive-paint pattern as `RenderNibMotion`: [time] is
/// read directly during [paint], and a listener calls [markNeedsPaint]
/// whenever it changes — no widget rebuild occurs per animation frame.
class RenderNibShimmer extends RenderProxyBox {
  /// Creates a render object that paints the shimmer shader described by
  /// [program] over [child], with its sweep position driven by [time].
  RenderNibShimmer({
    required MotionValue<double> time,
    required FragmentProgram program,
    required Color baseColor,
    required Color shimmerColor,
    required double speed,
    required double angle,
    RenderBox? child,
  })  : _time = time,
        _program = program,
        _baseColor = baseColor,
        _shimmerColor = shimmerColor,
        _speed = speed,
        _angle = angle,
        super(child) {
    _shader = _program.fragmentShader();
    _time.addListener(_onTimeChanged);
  }

  MotionValue<double> _time;
  FragmentProgram _program;
  Color _baseColor;
  Color _shimmerColor;
  double _speed;
  double _angle;
  late FragmentShader _shader;

  /// The [MotionValue] driving the shimmer sweep's elapsed-time uniform.
  MotionValue<double> get time => _time;
  set time(MotionValue<double> value) {
    if (_time == value) return;
    _time.removeListener(_onTimeChanged);
    _time = value;
    _time.addListener(_onTimeChanged);
    markNeedsPaint();
  }

  /// The compiled shimmer shader program.
  FragmentProgram get program => _program;
  set program(FragmentProgram value) {
    if (_program == value) return;
    _program = value;
    _shader = _program.fragmentShader();
    markNeedsPaint();
  }

  /// The background color painted behind the shimmer band.
  Color get baseColor => _baseColor;
  set baseColor(Color value) {
    if (_baseColor == value) return;
    _baseColor = value;
    markNeedsPaint();
  }

  /// The highlight color of the sweeping band.
  Color get shimmerColor => _shimmerColor;
  set shimmerColor(Color value) {
    if (_shimmerColor == value) return;
    _shimmerColor = value;
    markNeedsPaint();
  }

  /// Sweeps per second.
  double get speed => _speed;
  set speed(double value) {
    if (_speed == value) return;
    _speed = value;
    markNeedsPaint();
  }

  /// Sweep angle, in radians.
  double get angle => _angle;
  set angle(double value) {
    if (_angle == value) return;
    _angle = value;
    markNeedsPaint();
  }

  void _onTimeChanged() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    _shader
      ..setFloat(0, _time.value)
      ..setFloat(1, _speed)
      ..setFloat(2, _baseColor.r)
      ..setFloat(3, _baseColor.g)
      ..setFloat(4, _baseColor.b)
      ..setFloat(5, _baseColor.a)
      ..setFloat(6, _shimmerColor.r)
      ..setFloat(7, _shimmerColor.g)
      ..setFloat(8, _shimmerColor.b)
      ..setFloat(9, _shimmerColor.a)
      ..setFloat(10, size.width)
      ..setFloat(11, size.height)
      ..setFloat(12, _angle);

    context.canvas.saveLayer(offset & size, Paint());
    super.paint(context, offset);
    context.canvas.restore();
    context.canvas.drawRect(offset & size, Paint()..shader = _shader);
  }

  @override
  void dispose() {
    _time.removeListener(_onTimeChanged);
    super.dispose();
  }
}
