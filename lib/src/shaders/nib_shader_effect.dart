import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/reduced_motion_mixin.dart';
import '../values/motion_value.dart';
import 'shader_loader.dart';

/// Paints any fragment shader over (or masked by) [child], with
/// [MotionValue]s as live uniforms.
///
/// Changing a uniform repaints the layer; it never rebuilds the widget tree.
///
/// **Uniform layout** (the order your GLSL `uniform float` declarations must
/// follow):
///
/// 1. `time` in seconds — only if [includeTime] (default `false`)
/// 2. `width`, `height` in pixels — only if [includeSize] (default `true`)
/// 3. one float per entry of [uniforms], in list order
///
/// Provide the shader either as a ready [program] or as an [asset] key loaded
/// through [NibShaderLoader.load] (declare it under `flutter: shaders:` in your
/// pubspec). While it loads, or if it fails to load or compile, [child] is
/// painted unchanged.
///
/// [blendMode] controls how the shader composites with the child: `srcOver`
/// (default) draws it on top; `srcIn` masks the shader to the child's alpha;
/// `multiply`, `screen` etc. tint it.
///
/// With [sampleChild] the shader *transforms the child's pixels* instead of
/// drawing over them: the child is rendered into a texture that the engine
/// binds to the shader's first `sampler2D`. This uses `ImageFilter.shader`, so
/// it needs Impeller; elsewhere (Skia, older engines) the child is painted
/// unchanged. The engine requires the shader's **first uniform to be a
/// `vec2`, which it overwrites with the texture size** — so [includeSize] must
/// stay `true`, and on the OpenGL ES backend the shader must flip the y axis
/// (see `ImageFilter.shader`). [blendMode] is ignored in this mode.
///
/// Reduced motion freezes [includeTime] at `0` (no ticker); uniforms you drive
/// yourself are unaffected.
///
/// ```dart
/// final glow = MotionValue<double>(0);
/// NibShaderEffect(
///   asset: 'shaders/glow.frag',
///   includeTime: true,
///   uniforms: [glow],
///   blendMode: BlendMode.screen,
///   child: card,
/// )
/// ```
class NibShaderEffect extends StatefulWidget {
  /// Creates a shader effect. Exactly one of [program] and [asset] is
  /// required.
  const NibShaderEffect({
    super.key,
    this.program,
    this.asset,
    this.uniforms = const <MotionValue<double>>[],
    this.includeTime = false,
    this.includeSize = true,
    this.blendMode = BlendMode.srcOver,
    this.sampleChild = false,
    this.enabled = true,
    this.onLoadError,
    required this.child,
  })  : assert((program == null) != (asset == null),
            'Provide exactly one of program or asset.'),
        assert(!sampleChild || includeSize,
            'sampleChild needs includeSize: the first uniform must be a vec2.');

  /// A ready fragment program.
  final FragmentProgram? program;

  /// Asset key of the shader to load with [NibShaderLoader.load].
  final String? asset;

  /// Live uniform floats, appended after time/size in list order.
  final List<MotionValue<double>> uniforms;

  /// Whether the first uniform is elapsed seconds.
  final bool includeTime;

  /// Whether width and height (pixels) are passed before [uniforms].
  final bool includeSize;

  /// How the shader composites with [child].
  final BlendMode blendMode;

  /// Whether the shader receives the child's pixels as its first sampler and
  /// replaces them (Impeller only). See the class documentation.
  final bool sampleChild;

  /// When `false`, only [child] is painted and the time ticker is stopped.
  final bool enabled;

  /// Called if [asset] fails to load (the child keeps painting unchanged).
  final void Function(Object error)? onLoadError;

  /// The widget the shader is applied to.
  final Widget child;

  /// The floats passed to the shader, in order. Exposed for tests.
  @visibleForTesting
  static List<double> floatsFor({
    required double time,
    required Size size,
    required List<MotionValue<double>> uniforms,
    required bool includeTime,
    required bool includeSize,
  }) =>
      [
        if (includeTime) time,
        if (includeSize) ...[size.width, size.height],
        for (final u in uniforms) u.value,
      ];

  @override
  State<NibShaderEffect> createState() => _NibShaderEffectState();
}

class _NibShaderEffectState extends State<NibShaderEffect>
    with SingleTickerProviderStateMixin, NibReducedMotionMixin {
  final MotionValue<double> _time = MotionValue<double>(0);
  Ticker? _ticker;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
    _load();
    _syncTicker();
  }

  Future<void> _load() async {
    final asset = widget.asset;
    if (asset == null) return;
    try {
      final program = await NibShaderLoader.load(asset);
      if (!mounted || widget.asset != asset) return;
      setState(() => _program = program);
    } catch (error) {
      widget.onLoadError?.call(error);
    }
  }

  bool get _wantsTicker =>
      widget.enabled && widget.includeTime && !reduceMotion;

  void _syncTicker() {
    if (_wantsTicker) {
      final ticker = _ticker ??= createTicker(_onTick);
      if (!ticker.isActive) ticker.start();
    } else {
      _ticker?.stop();
      if (widget.includeTime && reduceMotion) _time.value = 0;
    }
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void onReducedMotionChanged(bool reduced) => _syncTicker();

  @override
  void didUpdateWidget(NibShaderEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.program != oldWidget.program) _program = widget.program;
    if (widget.asset != oldWidget.asset) {
      _program = widget.program;
      _load();
    }
    _syncTicker();
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
    if (program == null || !widget.enabled) return widget.child;
    return _NibShaderLayer(
      program: program,
      time: _time,
      uniforms: widget.uniforms,
      includeTime: widget.includeTime,
      includeSize: widget.includeSize,
      blendMode: widget.blendMode,
      sampleChild: widget.sampleChild,
      child: widget.child,
    );
  }
}

class _NibShaderLayer extends SingleChildRenderObjectWidget {
  const _NibShaderLayer({
    required this.program,
    required this.time,
    required this.uniforms,
    required this.includeTime,
    required this.includeSize,
    required this.blendMode,
    required this.sampleChild,
    required Widget child,
  }) : super(child: child);

  final FragmentProgram program;
  final MotionValue<double> time;
  final List<MotionValue<double>> uniforms;
  final bool includeTime;
  final bool includeSize;
  final BlendMode blendMode;
  final bool sampleChild;

  @override
  RenderNibShaderEffect createRenderObject(BuildContext context) =>
      RenderNibShaderEffect(
        program: program,
        time: time,
        uniforms: uniforms,
        includeTime: includeTime,
        includeSize: includeSize,
        blendMode: blendMode,
        sampleChild: sampleChild,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderNibShaderEffect renderObject) {
    renderObject
      ..program = program
      ..time = time
      ..uniforms = uniforms
      ..includeTime = includeTime
      ..includeSize = includeSize
      ..blendMode = blendMode
      ..sampleChild = sampleChild;
  }
}

/// Render object behind `NibShaderEffect`: paints the child, then the shader,
/// repainting (never rebuilding) when a uniform changes.
class RenderNibShaderEffect extends RenderProxyBox {
  /// Creates the render object.
  RenderNibShaderEffect({
    required FragmentProgram program,
    required MotionValue<double> time,
    required List<MotionValue<double>> uniforms,
    required bool includeTime,
    required bool includeSize,
    required BlendMode blendMode,
    bool sampleChild = false,
    RenderBox? child,
  })  : _program = program,
        _sampleChild = sampleChild,
        _time = time,
        _uniforms = List.of(uniforms),
        _includeTime = includeTime,
        _includeSize = includeSize,
        _blendMode = blendMode,
        super(child) {
    _shader = program.fragmentShader();
    _attach();
  }

  FragmentProgram _program;
  MotionValue<double> _time;
  List<MotionValue<double>> _uniforms;
  bool _includeTime;
  bool _includeSize;
  BlendMode _blendMode;
  bool _sampleChild;
  late FragmentShader _shader;
  final LayerHandle<ImageFilterLayer> _filterLayer =
      LayerHandle<ImageFilterLayer>();

  void _attach() {
    if (_includeTime) _time.addListener(markNeedsPaint);
    for (final u in _uniforms) {
      u.addListener(markNeedsPaint);
    }
  }

  void _detach() {
    _time.removeListener(markNeedsPaint);
    for (final u in _uniforms) {
      u.removeListener(markNeedsPaint);
    }
  }

  /// The compiled program.
  FragmentProgram get program => _program;
  set program(FragmentProgram value) {
    if (_program == value) return;
    _program = value;
    _shader = value.fragmentShader();
    markNeedsPaint();
  }

  /// The time value (used only when [includeTime]).
  MotionValue<double> get time => _time;
  set time(MotionValue<double> value) {
    if (_time == value) return;
    _detach();
    _time = value;
    _attach();
    markNeedsPaint();
  }

  /// The live uniform values.
  List<MotionValue<double>> get uniforms => _uniforms;
  set uniforms(List<MotionValue<double>> value) {
    if (listEquals(_uniforms, value)) return;
    _detach();
    _uniforms = List.of(value);
    _attach();
    markNeedsPaint();
  }

  /// Whether time is passed as the first uniform.
  bool get includeTime => _includeTime;
  set includeTime(bool value) {
    if (_includeTime == value) return;
    _detach();
    _includeTime = value;
    _attach();
    markNeedsPaint();
  }

  /// Whether size is passed before the uniforms.
  bool get includeSize => _includeSize;
  set includeSize(bool value) {
    if (_includeSize == value) return;
    _includeSize = value;
    markNeedsPaint();
  }

  /// How the shader composites with the child.
  BlendMode get blendMode => _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  /// Whether the shader replaces the child's pixels (Impeller only).
  bool get sampleChild => _sampleChild;
  set sampleChild(bool value) {
    if (_sampleChild == value) return;
    _sampleChild = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) {
      super.paint(context, offset);
      return;
    }
    final floats = NibShaderEffect.floatsFor(
      time: _time.value,
      size: size,
      uniforms: _uniforms,
      includeTime: _includeTime,
      includeSize: _includeSize,
    );
    for (var i = 0; i < floats.length; i++) {
      _shader.setFloat(i, floats[i]);
    }
    if (_sampleChild) {
      if (!ImageFilter.isShaderFilterSupported) {
        _filterLayer.layer = null;
        super.paint(context, offset);
        return;
      }
      final layer = (_filterLayer.layer ??= ImageFilterLayer());
      layer.imageFilter = ImageFilter.shader(_shader);
      context.pushLayer(layer, super.paint, offset);
      return;
    }
    _filterLayer.layer = null;
    final rect = offset & size;
    final canvas = context.canvas;
    canvas.saveLayer(rect, Paint());
    super.paint(context, offset);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = _shader
        ..blendMode = _blendMode,
    );
    canvas.restore();
  }

  @override
  bool get alwaysNeedsCompositing => _sampleChild;

  @override
  void dispose() {
    _filterLayer.layer = null;
    _detach();
    super.dispose();
  }
}
