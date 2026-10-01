import 'dart:ui' as ui show Image;
import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/reduced_motion_mixin.dart';
import '../values/motion_value.dart';
import 'shader_loader.dart';

/// Which direction a [NibDissolve] animation runs.
enum NibDissolveDirection {
  /// Animates from fully dissolved to fully visible.
  inward,

  /// Animates from fully visible to fully dissolved.
  outward,
}

/// Dissolves [child] in or out using a noise-pattern fragment shader,
/// instead of a uniform opacity fade.
///
/// A drop-in replacement for [FadeTransition] in page/element transitions
/// that want a more textured, GPU-driven look. The dissolve progress is
/// driven by a raw [Ticker] writing into a [MotionValue<double>] — the same
/// pattern [SpringSolver] and `NibShimmer` use — so the running animation
/// never causes a widget rebuild.
///
/// If the bundled dissolve shader hasn't finished compiling (or fails to
/// compile in this environment), [child] is painted with a plain opacity
/// fade as a fallback so the transition still reads correctly.
class NibDissolve extends StatefulWidget {
  /// Creates a dissolve transition around [child].
  const NibDissolve({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.direction = NibDissolveDirection.outward,
    this.noiseScale = 0.02,
    this.onComplete,
  });

  /// The widget being dissolved in or out.
  final Widget child;

  /// How long the dissolve animation takes.
  final Duration duration;

  /// Whether the dissolve animates from invisible to visible
  /// ([NibDissolveDirection.inward]) or visible to invisible
  /// ([NibDissolveDirection.outward]).
  final NibDissolveDirection direction;

  /// The grain size of the dissolve noise pattern. Smaller values produce
  /// finer grain.
  final double noiseScale;

  /// Called once the dissolve animation finishes.
  final VoidCallback? onComplete;

  @override
  State<NibDissolve> createState() => _NibDissolveState();
}

class _NibDissolveState extends State<NibDissolve>
    with SingleTickerProviderStateMixin, NibReducedMotionMixin {
  final MotionValue<double> _progress = MotionValue<double>(0);
  Ticker? _ticker;
  FragmentProgram? _program;
  bool _completed = false;

  bool get _startsDissolved => widget.direction == NibDissolveDirection.inward;

  @override
  void initState() {
    super.initState();
    _progress.value = _startsDissolved ? 1.0 : 0.0;
    _loadProgram();
    _start();
  }

  Future<void> _loadProgram() async {
    try {
      final program = await NibShaderLoader.dissolve();
      if (!mounted) return;
      setState(() => _program = program);
    } catch (_) {
      // Shader unavailable — `build` falls back to a plain opacity fade.
    }
  }

  @override
  void onReducedMotionChanged(bool reduced) {
    if (reduced && !_completed) _jumpToEnd();
  }

  /// Reduced motion: skip straight to the end state and still report
  /// completion (after the frame, so callers never see it mid-build).
  void _jumpToEnd() {
    _ticker?.stop();
    _completed = true;
    _progress.value = _startsDissolved ? 0.0 : 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete?.call();
    });
  }

  void _start() {
    _completed = false;
    if (reduceMotion) {
      _jumpToEnd();
      return;
    }
    // A Ticker's callback receives elapsed time measured from the moment
    // `start()` is called, so `elapsed` is already relative to this
    // animation run — no separate "elapsed at start" bookkeeping needed.
    (_ticker ??= createTicker(_onTick)).start();
  }

  void _onTick(Duration elapsed) {
    final runDuration = widget.duration.inMicroseconds == 0
        ? 1
        : widget.duration.inMicroseconds;
    final t = (elapsed.inMicroseconds / runDuration).clamp(0.0, 1.0);
    final dissolved = _startsDissolved ? 1.0 - t : t;
    _progress.value = dissolved;
    if (t >= 1.0 && !_completed) {
      _completed = true;
      _ticker?.stop();
      widget.onComplete?.call();
    }
  }

  @override
  void didUpdateWidget(NibDissolve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction) {
      _start();
    }
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      // Fallback: a plain opacity fade driven by the same MotionValue.
      return ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (context, dissolved, child) {
          return Opacity(opacity: 1.0 - dissolved, child: child);
        },
        child: widget.child,
      );
    }

    return _NibDissolveLayer(
      progress: _progress,
      program: program,
      noiseScale: widget.noiseScale,
      child: widget.child,
    );
  }
}

class _NibDissolveLayer extends SingleChildRenderObjectWidget {
  const _NibDissolveLayer({
    required this.progress,
    required this.program,
    required this.noiseScale,
    required Widget child,
  }) : super(child: child);

  final MotionValue<double> progress;
  final FragmentProgram program;
  final double noiseScale;

  @override
  RenderNibDissolve createRenderObject(BuildContext context) {
    return RenderNibDissolve(
      progress: progress,
      program: program,
      noiseScale: noiseScale,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibDissolve renderObject) {
    renderObject
      ..progress = progress
      ..program = program
      ..noiseScale = noiseScale;
  }
}

/// Paints [child] dissolved by the noise shader described by [program],
/// with dissolve progress driven by [progress].
///
/// Snapshots [child] into a [ui.Image] via the inherited [RenderRepaintBoundary]
/// behaviour, then shades that snapshot with the dissolve [FragmentShader].
/// Like `RenderNibMotion` and `RenderNibShimmer`, [progress] is read
/// directly during [paint]; a listener calls [markNeedsPaint] on change so
/// no widget rebuild occurs per animation frame.
class RenderNibDissolve extends RenderRepaintBoundary {
  /// Creates a render object that dissolves [child] using the shader
  /// described by [program], with progress driven by [progress].
  RenderNibDissolve({
    required MotionValue<double> progress,
    required FragmentProgram program,
    required double noiseScale,
    super.child,
  })  : _progress = progress,
        _program = program,
        _noiseScale = noiseScale {
    _shader = _program.fragmentShader();
    _progress.addListener(_onProgressChanged);
  }

  MotionValue<double> _progress;
  FragmentProgram _program;
  double _noiseScale;
  late FragmentShader _shader;
  ui.Image? _snapshot;
  bool _capturingSnapshot = false;

  /// The [MotionValue] driving the dissolve progress uniform (`0.0` fully
  /// visible, `1.0` fully dissolved).
  MotionValue<double> get progress => _progress;
  set progress(MotionValue<double> value) {
    if (_progress == value) return;
    _progress.removeListener(_onProgressChanged);
    _progress = value;
    _progress.addListener(_onProgressChanged);
    markNeedsPaint();
  }

  /// The compiled dissolve shader program.
  FragmentProgram get program => _program;
  set program(FragmentProgram value) {
    if (_program == value) return;
    _program = value;
    _shader = _program.fragmentShader();
    markNeedsPaint();
  }

  /// The grain size of the dissolve noise pattern.
  double get noiseScale => _noiseScale;
  set noiseScale(double value) {
    if (_noiseScale == value) return;
    _noiseScale = value;
    markNeedsPaint();
  }

  void _onProgressChanged() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    final dissolved = _progress.value;
    if (dissolved <= 0.0) {
      // At rest: paint plainly and drop any stale snapshot from a previous
      // dissolve cycle, so the next cycle captures fresh content.
      super.paint(context, offset);
      _snapshot?.dispose();
      _snapshot = null;
      return;
    }
    if (dissolved >= 1.0) {
      return;
    }

    super.paint(context, offset);

    // `toImage`/`toImageSync` cannot be called synchronously from within
    // this render object's own `paint()` — the boundary's layer hasn't
    // finished compositing yet at this point in the frame, so the engine
    // has no picture to rasterize (this used to throw
    // "'picture != null': is not true" on every frame). Capture a snapshot
    // asynchronously, once, after the frame in which this paint happened
    // has fully committed, and reuse it for the rest of this dissolve
    // cycle — the dissolving content is expected to be static during a
    // single transition, so a single snapshot covers the whole animation.
    final snapshot = _snapshot;
    if (snapshot == null) {
      _scheduleSnapshotCapture();
      return;
    }

    _shader
      ..setImageSampler(0, snapshot)
      ..setFloat(0, dissolved)
      ..setFloat(1, _noiseScale)
      ..setFloat(2, size.width)
      ..setFloat(3, size.height);

    context.canvas.drawRect(offset & size, Paint()..shader = _shader);
  }

  void _scheduleSnapshotCapture() {
    if (_capturingSnapshot) return;
    _capturingSnapshot = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!attached) return;
        final image = await toImage();
        if (!attached) {
          image.dispose();
          return;
        }
        _snapshot?.dispose();
        _snapshot = image;
        markNeedsPaint();
      } finally {
        _capturingSnapshot = false;
      }
    });
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    _snapshot?.dispose();
    super.dispose();
  }
}
