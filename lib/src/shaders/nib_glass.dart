import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'shader_loader.dart';

/// A "liquid glass" surface: a physically-modelled glass dome over the
/// backdrop — Apple's Liquid Glass material, rendered with the bundled
/// `liquid_glass.frag` backdrop shader. The glass is [thickness] px deep with
/// a quarter-circle dome profile: optically flat in the center (the backdrop
/// stays sharp and straight) and curving to horizontal at the rim, where real
/// Snell's-law refraction (driven by [refractiveIndex]) bends the backdrop
/// strongly inward. [chromaticAberration] adds red/blue dispersion at the
/// rim, [saturation] makes the backdrop's colors pop through the glass, and a
/// rim highlight derived from the background color tracks [lightDirection].
///
/// True edge refraction requires the **Impeller** rendering backend
/// ([ui.ImageFilter.isShaderFilterSupported]). On any other backend — or before
/// the shader has compiled, or when laid out without a bounded size — `NibGlass`
/// falls back to a frosted blur + tint + painted rim highlight, which still reads
/// as glass but without the lensing. It never throws.
///
/// `NibGlass` is a low-level engine widget: it takes a fully-resolved
/// [tint]/[lightDirection]/etc. `nib_components`' `NibLiquidGlass` wraps it with
/// theme tokens, gesture-driven light, and the animation contract.
class NibGlass extends StatefulWidget {
  /// Creates a liquid-glass surface painting [child] over a refracted,
  /// subtly tinted backdrop.
  const NibGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.clipper,
    this.blurSigma = 1,
    this.tint = const Color(0x14FFFFFF),
    this.thickness = 20,
    this.refractiveIndex = 1.2,
    this.chromaticAberration = 0.03,
    this.saturation = 1.3,
    this.highlight = 0.5,
    this.lightDirection = const Offset(-0.5, -1),
  });

  /// The content painted on top of the glass.
  final Widget child;

  /// Corner radius of the glass surface (ignored when [clipper] is set).
  final BorderRadius borderRadius;

  /// Custom shape for the glass. When non-null it clips the surface (capsule,
  /// blob, arbitrary path) instead of [borderRadius].
  final CustomClipper<Path>? clipper;

  /// Gaussian blur applied to the backdrop. Kept near zero by default — liquid
  /// glass is clear, not frosted; the edge refraction carries the effect.
  final double blurSigma;

  /// Tint painted over the backdrop; the alpha channel is the mix amount.
  /// Subtle by default — the glass is mostly clear.
  final Color tint;

  /// Depth of the glass dome, in logical pixels. The surface is flat deeper
  /// than [thickness] px inside the shape and curves down to the rim over
  /// that band — thicker glass refracts a wider, stronger band. Only used on
  /// the shader path.
  final double thickness;

  /// Index of refraction of the glass. 1.0 means no bending; Apple-style
  /// liquid glass sits around 1.2. Only used on the shader path.
  final double refractiveIndex;

  /// Chromatic aberration (dispersion) strength: how far the red and blue
  /// channels' refractions separate at the rim. 0 disables the extra texture
  /// taps. Only used on the shader path.
  final double chromaticAberration;

  /// Saturation boost applied to the backdrop seen through the glass —
  /// 1.0 leaves it unchanged, >1 makes colors pop. Only used on the shader
  /// path.
  final double saturation;

  /// Rim-highlight (edge lighting) intensity, 0..1.
  final double highlight;

  /// Direction the specular highlight comes from (points toward the light).
  final Offset lightDirection;

  @override
  State<NibGlass> createState() => _NibGlassState();

  /// Diagnostic: whether the real shader path can actually run on this device —
  /// i.e. the bundled `liquid_glass.frag` program compiles AND
  /// `ImageFilter.shader` is supported (Impeller). Returns `false` when the
  /// glass would fall back to a plain blur (shader asset not bundled, or a
  /// non-Impeller backend). Intended for debugging/diagnostics, not layout.
  static Future<bool> debugShaderPathAvailable() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return false;
    try {
      await NibShaderLoader.liquidGlass();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _NibGlassState extends State<NibGlass> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await NibShaderLoader.liquidGlass();
      if (mounted) setState(() => _program = program);
    } catch (_) {
      // Shader unavailable — the build falls back to a blur + painted rim.
    }
  }

  bool get _canUseShader =>
      _program != null && ui.ImageFilter.isShaderFilterSupported;

  double get _radius => widget.borderRadius.topLeft.x;

  /// [NibGlass.lightDirection] with non-finite components replaced by the
  /// default direction, shared by the shader and fallback paths.
  Offset get _light {
    final ld = widget.lightDirection;
    return Offset(ld.dx.isFinite ? ld.dx : -0.4, ld.dy.isFinite ? ld.dy : -1.0);
  }

  /// [size] is the logical widget size; [dpr] the device pixel ratio.
  /// `ImageFilter.shader` runs in physical pixels, so the size and every
  /// pixel-valued uniform (radius, thickness) are scaled by [dpr].
  ///
  /// The `setFloat` indices below MUST match `liquid_glass.frag`'s uniform
  /// declaration order exactly:
  /// 0-1 uSize, 2 uRadius, 3 uThickness, 4 uRefractiveIndex,
  /// 5 uChromaticAberration, 6 uSaturation, 7 uLightIntensity,
  /// 8-9 uLight, 10-13 uTint, 14-15 uOrigin, 16-17 uGlassSize.
  ///
  /// Indices 0-1 (`uSize`) are overwritten by Impeller with the size of the
  /// backdrop texture, which is the whole enclosing layer, not the glass; the
  /// glass's own size travels in `uGlassSize`.
  ///
  /// [origin] is the glass's top-left in the enclosing layer's logical
  /// coordinates: inside an `ImageFilter.shader`, `FlutterFragCoord()` and the
  /// backdrop texture are expressed in the *layer's* space, not relative to
  /// the widget, so the shader needs it to place the glass shape and to sample
  /// the backdrop.
  ui.ImageFilter? _shaderFilter(Size size, double dpr, Offset origin) {
    if (!_canUseShader || !size.isFinite || size.isEmpty) return null;
    final shader = _program!.fragmentShader();
    final t = widget.tint;
    final lx = _light.dx;
    final ly = _light.dy;
    shader
      ..setFloat(0, size.width * dpr)
      ..setFloat(1, size.height * dpr)
      ..setFloat(2, _radius * dpr)
      ..setFloat(3, widget.thickness * dpr)
      ..setFloat(4, widget.refractiveIndex)
      ..setFloat(5, widget.chromaticAberration)
      ..setFloat(6, widget.saturation)
      ..setFloat(7, widget.highlight)
      ..setFloat(8, lx)
      ..setFloat(9, ly)
      ..setFloat(10, t.r)
      ..setFloat(11, t.g)
      ..setFloat(12, t.b)
      ..setFloat(13, t.a)
      ..setFloat(14, origin.dx * dpr)
      ..setFloat(15, origin.dy * dpr)
      ..setFloat(16, size.width * dpr)
      ..setFloat(17, size.height * dpr);
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: ui.ImageFilter.blur(
          sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
    );
  }

  Widget _clip({required Widget child}) {
    if (widget.clipper != null) {
      return ClipPath(clipper: widget.clipper, child: child);
    }
    return ClipRRect(borderRadius: widget.borderRadius, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return _clip(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_canUseShader &&
              constraints.biggest.isFinite &&
              !constraints.biggest.isEmpty) {
            // Shader path: refraction + frost + tint + rim all live in the
            // backdrop filter; the child paints on top. The filter is built at
            // paint time because it needs the glass's position in its layer.
            return _GlassBackdrop(
              filterFor: (size, origin) => _shaderFilter(size, dpr, origin),
              child: widget.child,
            );
          }
          // Fallback: frosted blur, then a painted tint + rim, then the child.
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: widget.blurSigma,
                    sigmaY: widget.blurSigma,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GlassFallbackPainter(
                    tint: widget.tint,
                    highlight: widget.highlight,
                    lightDirection: _light,
                  ),
                ),
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

/// Paints the non-shader fallback: a tint wash, a soft top sheen, and a rim
/// highlight brightest on the side [lightDirection] points from.
class _GlassFallbackPainter extends CustomPainter {
  _GlassFallbackPainter({
    required this.tint,
    required this.highlight,
    required this.lightDirection,
  });

  final Color tint;
  final double highlight;
  final Offset lightDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Tint wash.
    canvas.drawRect(rect, Paint()..color = tint);

    // Directional sheen: brighter toward where the light comes from.
    final dir = lightDirection.distance == 0
        ? const Offset(0, -1)
        : lightDirection / lightDirection.distance;
    final from = size.center(Offset.zero) - dir * size.longestSide;
    final to = size.center(Offset.zero) + dir * size.longestSide;
    final sheen = Paint()
      ..shader = ui.Gradient.linear(from, to, [
        Color.fromRGBO(255, 255, 255, 0.22 * highlight),
        const Color(0x00FFFFFF),
      ]);
    canvas.drawRect(rect, sheen);

    // Rim highlight along the edge.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(from, to, [
        Color.fromRGBO(255, 255, 255, 0.6 * highlight),
        Color.fromRGBO(255, 255, 255, 0.1 * highlight),
      ]);
    canvas.drawRect(rect.deflate(0.75), rim);
  }

  @override
  bool shouldRepaint(_GlassFallbackPainter old) =>
      old.tint != tint ||
      old.highlight != highlight ||
      old.lightDirection != lightDirection;
}

/// A `BackdropFilter` whose [ui.ImageFilter] is built at paint time from the
/// box's size and its offset within the enclosing layer.
class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({required this.filterFor, super.child});

  final ui.ImageFilter? Function(Size size, Offset origin) filterFor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(filterFor);

  @override
  void updateRenderObject(
      BuildContext context, _RenderGlassBackdrop renderObject) {
    renderObject.filterFor = filterFor;
  }
}

class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this._filterFor);

  ui.ImageFilter? Function(Size size, Offset origin) _filterFor;
  final LayerHandle<BackdropFilterLayer> _layer =
      LayerHandle<BackdropFilterLayer>();

  set filterFor(ui.ImageFilter? Function(Size size, Offset origin) value) {
    _filterFor = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final filter = _filterFor(size, offset);
    if (filter == null) {
      _layer.layer = null;
      super.paint(context, offset);
      return;
    }
    final layer = (_layer.layer ??= BackdropFilterLayer());
    layer.filter = filter;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}
