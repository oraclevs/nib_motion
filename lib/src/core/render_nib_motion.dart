import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flutter/scheduler.dart';

import '../layout/nib_layout.dart';
import '../layout/nib_layout_frame_hook.dart';
import '../layout/nib_layout_scope.dart';
import '../values/motion_value.dart';
import '../values/motion_value_types.dart';
import 'paint_transform_hit_test.dart';

/// Paints a child with reactive transform, opacity, color, and clip
/// properties driven by [MotionValue]s.
///
/// Every property is read directly from its [MotionValue] during [paint].
/// When a [MotionValue] notifies, this render object calls
/// [markNeedsPaint] (and [markNeedsCompositingBitsUpdate] for [opacity])
/// — it never triggers a widget rebuild.
class RenderNibMotion extends RenderProxyBox
    with PaintTransformHitTest
    implements NibLayoutMeasurable {
  /// Creates a render object that paints [child] using the given
  /// [MotionValue]s.
  RenderNibMotion({
    required MotionValue<double> opacity,
    required MotionValue<double> translateX,
    required MotionValue<double> translateY,
    required MotionValue<double> scaleX,
    required MotionValue<double> scaleY,
    required MotionValue<double> rotate,
    required MotionValue<double> skewX,
    required MotionValue<double> skewY,
    MotionValue<double>? rotateX,
    MotionValue<double>? rotateY,
    MotionValue<double>? blur,
    MotionValue<Color?>? tint,
    required MotionValue<Color?> color,
    required MotionValue<BorderRadius?> borderRadius,
    required BoxShadowMotionValue boxShadow,
    NibLayout layout = NibLayout.none,
    NibLayoutSizeMode layoutSizeMode = NibLayoutSizeMode.scale,
    NibLayoutChannelMode layoutChannelMode = NibLayoutChannelMode.channels,
    NibLayoutChannels? layoutChannels,
    this.layoutId,
    this.layoutScope,
    this.onLayoutFlip,
    RenderBox? child,
  })  : _layoutMode = layout,
        _layoutSizeMode = layoutSizeMode,
        _layoutChannelMode = layoutChannelMode,
        _layoutChannels = layoutChannels,
        _opacity = opacity,
        _translateX = translateX,
        _translateY = translateY,
        _scaleX = scaleX,
        _scaleY = scaleY,
        _rotate = rotate,
        _skewX = skewX,
        _skewY = skewY,
        _rotateX = rotateX ?? MotionValue<double>(0.0),
        _ownsRotateX = rotateX == null,
        _rotateY = rotateY ?? MotionValue<double>(0.0),
        _ownsRotateY = rotateY == null,
        _blur = blur ?? MotionValue<double>(0.0),
        _ownsBlur = blur == null,
        _tint = tint ?? MotionValue<Color?>(null),
        _ownsTint = tint == null,
        _color = color,
        _borderRadius = borderRadius,
        _boxShadow = boxShadow,
        super(child) {
    _opacity.addListener(_onOpacityChanged);
    _translateX.addListener(_onPaintValueChanged);
    _translateY.addListener(_onPaintValueChanged);
    _scaleX.addListener(_onPaintValueChanged);
    _scaleY.addListener(_onPaintValueChanged);
    _rotate.addListener(_onPaintValueChanged);
    _skewX.addListener(_onPaintValueChanged);
    _skewY.addListener(_onPaintValueChanged);
    _rotateX.addListener(_onPaintValueChanged);
    _rotateY.addListener(_onPaintValueChanged);
    _blur.addListener(_onFilterChanged);
    _tint.addListener(_onFilterChanged);
    _color.addListener(_onPaintValueChanged);
    _borderRadius.addListener(_onPaintValueChanged);
    _boxShadow.addListener(_onPaintValueChanged);
    _attachChannels(layoutChannels);
  }

  NibLayout _layoutMode;
  NibLayoutSizeMode _layoutSizeMode;
  NibLayoutChannelMode _layoutChannelMode;

  /// Where the position part of a layout FLIP is stored.
  NibLayoutChannelMode get layoutChannelMode => _layoutChannelMode;
  set layoutChannelMode(NibLayoutChannelMode value) {
    if (_layoutChannelMode == value) return;
    _layoutChannelMode = value;
    markNeedsPaint();
  }

  bool get _flipInTranslate =>
      _layoutChannelMode == NibLayoutChannelMode.translate;

  /// How size changes are played: scaled or revealed through a clip.
  NibLayoutSizeMode get layoutSizeMode => _layoutSizeMode;
  set layoutSizeMode(NibLayoutSizeMode value) {
    if (_layoutSizeMode == value) return;
    _layoutSizeMode = value;
    markNeedsPaint();
  }

  bool get _clipsSize =>
      _layoutSizeMode == NibLayoutSizeMode.clip &&
      (_layoutMode == NibLayout.size || _layoutMode == NibLayout.both);

  /// While a `NibLayoutSizeMode.clip` size animation is in flight, the visible
  /// region of this box in its own (pre-transform) coordinates: the clip
  /// anchored at the top-left. `null` when nothing is clipped.
  Rect? get layoutClipRect {
    if (!_clipsSize || !hasSize) return null;
    final sx = _flipScaleX, sy = _flipScaleY;
    if (sx >= 1.0 - 1e-6 && sy >= 1.0 - 1e-6) return null;
    return Rect.fromLTWH(0, 0, size.width * sx, size.height * sy);
  }

  NibLayoutChannels? _layoutChannels;

  /// Identity shared across the tree for shared-layout transitions.
  Object? layoutId;

  /// Registry of shared ids in the enclosing `NibLayoutScope`, if any.
  NibLayoutScopeData? layoutScope;

  /// Called (post-frame) with the FLIP that inverts a layout change. The
  /// callback must write the flip into the layout channels; until it returns
  /// the render object paints the flip itself, so there is no flash frame.
  void Function(NibLayoutFlip flip)? onLayoutFlip;

  Rect? _committed;
  NibLayoutFlip? _pending;

  /// The layout mode; changing it forgets the last measured rectangle.
  NibLayout get layoutMode => _layoutMode;
  set layoutMode(NibLayout value) {
    if (_layoutMode == value) return;
    _layoutMode = value;
    _committed = null;
    _pending = null;
    _syncRegistration();
    markNeedsPaint();
  }

  @override
  int lastMeasuredFrame = -1;

  bool _registered = false;

  /// Registers while this box animates layout so scopes can measure before
  /// paint and the frame hook can catch changes that skip scope layout.
  void _syncRegistration() {
    final want = attached && _layoutMode != NibLayout.none;
    if (want == _registered) return;
    _registered = want;
    if (want) {
      NibLayoutFrameHook.register(this);
    } else {
      NibLayoutFrameHook.unregister(this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncRegistration();
  }

  @override
  void detach() {
    super.detach();
    // After `super.detach()` so `attached` is false and the box leaves the
    // static frame-hook registry (it used to stay there forever).
    _syncRegistration();
  }

  @override
  void remeasureLayout() {
    if (!attached || !hasSize || _layoutMode == NibLayout.none) return;
    _measureLayout();
    if (_pending != null) markNeedsPaint();
  }

  /// The FLIP channels painted on top of the widget's own transform.
  NibLayoutChannels? get layoutChannels => _layoutChannels;
  set layoutChannels(NibLayoutChannels? value) {
    if (identical(_layoutChannels, value)) return;
    _detachChannels();
    _layoutChannels = value;
    _attachChannels(value);
    markNeedsPaint();
  }

  void _attachChannels(NibLayoutChannels? channels) {
    if (channels == null) return;
    for (final c in channels.all) {
      c.addListener(_onPaintValueChanged);
    }
  }

  void _detachChannels() {
    final channels = _layoutChannels;
    if (channels == null) return;
    for (final c in channels.all) {
      c.removeListener(_onPaintValueChanged);
    }
  }

  // In translate mode the FLIP *is* the widget's translation, so the current
  // in-flight offset is `translateX/Y` itself.
  double get _flipX =>
      _pending?.x ??
      (_flipInTranslate ? _translateX.value : _layoutChannels?.x.value ?? 0.0);
  double get _flipY =>
      _pending?.y ??
      (_flipInTranslate ? _translateY.value : _layoutChannels?.y.value ?? 0.0);
  double get _flipScaleX =>
      _pending?.scaleX ?? _layoutChannels?.scaleX.value ?? 1.0;
  double get _flipScaleY =>
      _pending?.scaleY ?? _layoutChannels?.scaleY.value ?? 1.0;

  /// This box's position in layout space: the sum of `parentData` offsets up
  /// to the enclosing `RenderNibLayoutScope`, or as far as plain box parents
  /// go. Paint transforms (including other FLIPs in flight) and scrolling are
  /// deliberately *not* part of it, so only real layout movement registers.
  Offset _layoutOrigin() {
    var origin = Offset.zero;
    RenderObject node = this;
    while (true) {
      final parent = node.parent;
      final data = node.parentData;
      if (parent == null) break;
      if (parent is RenderSliver && data is SliverLogicalParentData) {
        // Item of a lazy list/grid: its scroll-space position (scroll offset
        // of the sliver plus its own offset in it), which does not change when
        // the list merely scrolls.
        final constraints = parent.constraints;
        final main =
            constraints.precedingScrollExtent + (data.layoutOffset ?? 0);
        final cross =
            data is SliverGridParentData ? data.crossAxisOffset ?? 0 : 0.0;
        return origin +
            _sliverContentOffset(constraints, main, cross.toDouble(), node);
      }
      if (parent is RenderSliver && data is SliverPhysicalParentData) {
        // Box inside a SliverToBoxAdapter and friends: content-space start of
        // the sliver.
        final constraints = parent.constraints;
        return origin +
            _sliverContentOffset(
                constraints, constraints.precedingScrollExtent, 0.0, node);
      }
      if (data is BoxParentData) {
        origin += data.offset;
      } else if (parent is! RenderProxyBox) {
        // Proxy boxes (opacity, ignore-pointer, transforms, …) keep their
        // child at offset zero; anything else without box parent data (a
        // sliver, the render view) ends the layout space.
        break;
      }
      if (parent is RenderNibLayoutScope || parent is! RenderBox) break;
      node = parent;
    }
    return origin;
  }

  /// The top-left of [item] in screen-oriented content space (x right, y down,
  /// origin at the viewport's centre line), given its [main] offset along the
  /// sliver's growth direction and [cross] offset along its cross axis.
  ///
  /// Slivers measure `layoutOffset` from their leading edge, which is the
  /// bottom/right in a reversed list (`reverse: true`) or a reverse-growth
  /// sliver before a `center`. Without this mapping the FLIP of such items
  /// would be mirrored.
  static Offset _sliverContentOffset(SliverConstraints constraints, double main,
      double cross, RenderObject item) {
    final dir = applyGrowthDirectionToAxisDirection(
        constraints.axisDirection, constraints.growthDirection);
    final vertical = axisDirectionToAxis(dir) == Axis.vertical;
    final size = item is RenderBox && item.hasSize ? item.size : Size.zero;
    final mainExtent = vertical ? size.height : size.width;
    final m = axisDirectionIsReversed(dir) ? -(main + mainExtent) : main;
    // `SliverGridParentData.crossAxisOffset` is already physical (measured
    // from the left/top edge even in RTL), so the cross axis needs no mapping.
    return vertical ? Offset(cross, m) : Offset(m, cross);
  }

  // Ancestor layout cannot read this box's size under Flutter's size contract.
  Size? _lastLayoutSize;

  @override
  void performLayout() {
    super.performLayout();
    _lastLayoutSize = size;
  }

  void _measureLayout() {
    if (!hasSize) return;
    lastMeasuredFrame = NibLayoutFrameHook.frame;
    final rect = _layoutOrigin() & (_lastLayoutSize ?? size);
    final previous = _committed;
    Rect? from = previous;
    final id = layoutId;
    final scope = layoutScope;
    if (previous == null && id != null && scope != null) {
      from = scope.claim(id, this);
    }
    _committed = rect;
    if (id != null && scope != null) scope.record(id, rect, this);
    if (from == null) return;
    if (_sameRect(from, rect)) return;

    final flip = _flipFrom(from, rect);
    _pending = flip;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || _pending != flip) return;
      onLayoutFlip?.call(flip);
      _pending = null;
      markNeedsPaint();
    });
  }

  static bool _sameRect(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.01 &&
      (a.top - b.top).abs() < 0.01 &&
      (a.width - b.width).abs() < 0.01 &&
      (a.height - b.height).abs() < 0.01;

  /// The channel values that make [next] look like [previous] was painted,
  /// starting from whatever flip is currently in flight.
  NibLayoutFlip _flipFrom(Rect previous, Rect next) {
    final tx = _flipX, ty = _flipY, sx = _flipScaleX, sy = _flipScaleY;
    if (_layoutMode == NibLayout.position || _clipsSize) {
      // Position only, or clip mode: the box is translated so its top-left
      // stays put; in clip mode the scale channels carry the clip ratio.
      final base = _layoutMode == NibLayout.size
          ? previous.shift(next.topLeft - previous.topLeft)
          : previous;
      if (_layoutMode != NibLayout.position) {
        return NibLayoutFlip(
          x: base.left + tx - next.left,
          y: base.top + ty - next.top,
          scaleX: next.width == 0 ? 1.0 : previous.width * sx / next.width,
          scaleY: next.height == 0 ? 1.0 : previous.height * sy / next.height,
        );
      }
      return NibLayoutFlip(
        x: previous.left + tx - next.left,
        y: previous.top + ty - next.top,
        scaleX: sx,
        scaleY: sy,
      );
    }
    // Size flips scale about the centre; `size` alone holds the position.
    final from = _layoutMode == NibLayout.size
        ? previous.shift(next.topLeft - previous.topLeft)
        : previous;
    final paintedCenter = from.center + Offset(tx, ty);
    return NibLayoutFlip(
      x: paintedCenter.dx - next.center.dx,
      y: paintedCenter.dy - next.center.dy,
      scaleX: next.width == 0 ? 1.0 : from.width * sx / next.width,
      scaleY: next.height == 0 ? 1.0 : from.height * sy / next.height,
    );
  }

  MotionValue<double> _opacity;
  MotionValue<double> _translateX;
  MotionValue<double> _translateY;
  MotionValue<double> _scaleX;
  MotionValue<double> _scaleY;
  MotionValue<double> _rotate;
  MotionValue<double> _skewX;
  MotionValue<double> _skewY;
  MotionValue<double> _rotateX;
  MotionValue<double> _rotateY;
  MotionValue<double> _blur;
  MotionValue<Color?> _tint;
  // Defaults created here (callers omitted them) are disposed here.
  final bool _ownsRotateX;
  final bool _ownsRotateY;
  final bool _ownsBlur;
  final bool _ownsTint;
  final LayerHandle<ImageFilterLayer> _blurLayer =
      LayerHandle<ImageFilterLayer>();

  /// Rotation around the X axis in turns, drawn with perspective.
  MotionValue<double> get rotateX => _rotateX;
  set rotateX(MotionValue<double> value) {
    if (_rotateX == value) return;
    _rotateX.removeListener(_onPaintValueChanged);
    _rotateX = value;
    _rotateX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Rotation around the Y axis in turns, drawn with perspective.
  MotionValue<double> get rotateY => _rotateY;
  set rotateY(MotionValue<double> value) {
    if (_rotateY == value) return;
    _rotateY.removeListener(_onPaintValueChanged);
    _rotateY = value;
    _rotateY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Gaussian blur sigma in logical pixels; `0` paints without a filter layer.
  MotionValue<double> get blur => _blur;
  set blur(MotionValue<double> value) {
    if (_blur == value) return;
    _blur.removeListener(_onFilterChanged);
    _blur = value;
    _blur.addListener(_onFilterChanged);
    _onFilterChanged();
  }

  /// Colour laid over the painted pixels (`BlendMode.srcATop`), or `null`.
  MotionValue<Color?> get tint => _tint;
  set tint(MotionValue<Color?> value) {
    if (_tint == value) return;
    _tint.removeListener(_onFilterChanged);
    _tint = value;
    _tint.addListener(_onFilterChanged);
    _onFilterChanged();
  }

  bool get _hasFilter => _blur.value > 0.0 || _tint.value != null;

  void _onFilterChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  MotionValue<Color?> _color;
  MotionValue<BorderRadius?> _borderRadius;
  BoxShadowMotionValue _boxShadow;

  /// Opacity from `0.0` (fully transparent) to `1.0` (fully opaque).
  MotionValue<double> get opacity => _opacity;
  set opacity(MotionValue<double> value) {
    if (_opacity == value) return;
    _opacity.removeListener(_onOpacityChanged);
    _opacity = value;
    _opacity.addListener(_onOpacityChanged);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// Horizontal translation, in logical pixels.
  MotionValue<double> get translateX => _translateX;
  set translateX(MotionValue<double> value) {
    if (_translateX == value) return;
    _translateX.removeListener(_onPaintValueChanged);
    _translateX = value;
    _translateX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical translation, in logical pixels.
  MotionValue<double> get translateY => _translateY;
  set translateY(MotionValue<double> value) {
    if (_translateY == value) return;
    _translateY.removeListener(_onPaintValueChanged);
    _translateY = value;
    _translateY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Horizontal scale. Identity is `1.0`.
  MotionValue<double> get scaleX => _scaleX;
  set scaleX(MotionValue<double> value) {
    if (_scaleX == value) return;
    _scaleX.removeListener(_onPaintValueChanged);
    _scaleX = value;
    _scaleX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical scale. Identity is `1.0`.
  MotionValue<double> get scaleY => _scaleY;
  set scaleY(MotionValue<double> value) {
    if (_scaleY == value) return;
    _scaleY.removeListener(_onPaintValueChanged);
    _scaleY = value;
    _scaleY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Rotation around the Z axis, in turns (`1.0` == 360°).
  MotionValue<double> get rotate => _rotate;
  set rotate(MotionValue<double> value) {
    if (_rotate == value) return;
    _rotate.removeListener(_onPaintValueChanged);
    _rotate = value;
    _rotate.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Horizontal shear, in radians.
  MotionValue<double> get skewX => _skewX;
  set skewX(MotionValue<double> value) {
    if (_skewX == value) return;
    _skewX.removeListener(_onPaintValueChanged);
    _skewX = value;
    _skewX.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Vertical shear, in radians.
  MotionValue<double> get skewY => _skewY;
  set skewY(MotionValue<double> value) {
    if (_skewY == value) return;
    _skewY.removeListener(_onPaintValueChanged);
    _skewY = value;
    _skewY.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Background color painted behind [child]. `null` paints nothing.
  MotionValue<Color?> get color => _color;
  set color(MotionValue<Color?> value) {
    if (_color == value) return;
    _color.removeListener(_onPaintValueChanged);
    _color = value;
    _color.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Clip radius applied to [child] and [color]. `null` applies no clip.
  MotionValue<BorderRadius?> get borderRadius => _borderRadius;
  set borderRadius(MotionValue<BorderRadius?> value) {
    if (_borderRadius == value) return;
    _borderRadius.removeListener(_onPaintValueChanged);
    _borderRadius = value;
    _borderRadius.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  /// Shadows painted behind [color] and [child]. `null` or an empty list
  /// paints nothing.
  BoxShadowMotionValue get boxShadow => _boxShadow;
  set boxShadow(BoxShadowMotionValue value) {
    if (_boxShadow == value) return;
    _boxShadow.removeListener(_onPaintValueChanged);
    _boxShadow = value;
    _boxShadow.addListener(_onPaintValueChanged);
    markNeedsPaint();
  }

  void _onPaintValueChanged() => markNeedsPaint();

  void _onOpacityChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// The transform matrix currently applied to [child], built from
  /// [translateX], [translateY], [rotate], [scaleX], [scaleY], [skewX], and
  /// [skewY] around the center of this render object.
  Matrix4 get transform {
    final center = size.center(Offset.zero);
    return Matrix4.translationValues(
        _flipInTranslate ? _flipX : _translateX.value + _flipX,
        _flipInTranslate ? _flipY : _translateY.value + _flipY,
        0.0)
      ..multiply(Matrix4.translationValues(center.dx, center.dy, 0.0))
      ..multiply(Matrix4.rotationZ(_rotate.value * 2 * math.pi))
      ..multiply(Matrix4.diagonal3Values(
          _scaleX.value * (_clipsSize ? 1.0 : _flipScaleX),
          _scaleY.value * (_clipsSize ? 1.0 : _flipScaleY),
          1.0))
      ..multiply(_skewMatrix(_skewX.value, _skewY.value))
      ..multiply(_rotation3D())
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0.0));
  }

  /// Perspective strength for [rotateX]/[rotateY] (per logical pixel of depth).
  static const double _perspective = 0.001;

  Matrix4 _rotation3D() {
    final rx = _rotateX.value;
    final ry = _rotateY.value;
    if (rx == 0.0 && ry == 0.0) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, _perspective)
      ..rotateX(rx * 2 * math.pi)
      ..rotateY(ry * 2 * math.pi);
  }

  Matrix4 _skewMatrix(double skewX, double skewY) {
    return Matrix4.identity()
      ..setEntry(0, 1, math.tan(skewX))
      ..setEntry(1, 0, math.tan(skewY));
  }

  @override
  bool get alwaysNeedsCompositing => _opacity.value < 1.0 || _hasFilter;

  @override
  Matrix4 get paintMatrix => transform;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_layoutMode != NibLayout.none) _measureLayout();
    final opacityValue = _opacity.value;
    if (opacityValue <= 0.0) return;

    if (opacityValue < 1.0) {
      context.pushOpacity(offset, (opacityValue * 255).round(), _paintContents);
    } else {
      _paintContents(context, offset);
    }
  }

  void _paintContents(PaintingContext context, Offset offset) {
    final matrix = transform;
    if (matrix.isIdentity()) {
      _paintClipped(context, offset);
    } else {
      context.pushTransform(needsCompositing, offset, matrix, _paintClipped);
    }
  }

  /// Clips to [layoutClipRect] while a `NibLayoutSizeMode.clip` size
  /// animation is running.
  void _paintClipped(PaintingContext context, Offset offset) {
    final clip = layoutClipRect;
    if (clip == null) {
      _paintFiltered(context, offset);
    } else {
      context.pushClipRect(needsCompositing, offset, clip, _paintFiltered);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final clip = layoutClipRect;
    if (clip != null && !clip.contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => layoutClipRect;

  /// Applies [blur] and [tint] (when set) around the box and its child.
  void _paintFiltered(PaintingContext context, Offset offset) {
    final blur = _blur.value;
    final tint = _tint.value;
    if (blur <= 0.0 && tint == null) {
      _paintBoxAndChild(context, offset);
      return;
    }
    PaintingContextCallback painter = _paintBoxAndChild;
    if (tint != null) {
      final inner = painter;
      painter = (context, offset) => context.pushColorFilter(
          offset, ColorFilter.mode(tint, BlendMode.srcATop), inner);
    }
    if (blur > 0.0) {
      final inner = painter;
      _blurLayer.layer = ImageFilterLayer(
        imageFilter: ui.ImageFilter.blur(
            sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal),
      );
      context.pushLayer(_blurLayer.layer!, inner, offset);
    } else {
      _blurLayer.layer = null;
      painter(context, offset);
    }
  }

  void _paintBoxAndChild(PaintingContext context, Offset offset) {
    final rect = offset & size;
    final color = _color.value;
    final radius = _borderRadius.value;
    final shadows = _boxShadow.value;

    if (shadows != null) {
      for (final shadow in shadows) {
        final shadowRect =
            rect.shift(shadow.offset).inflate(shadow.spreadRadius);
        final shadowRRect = radius != null
            ? radius.toRRect(shadowRect)
            : RRect.fromRectAndRadius(shadowRect, Radius.zero);
        context.canvas.drawRRect(shadowRRect, shadow.toPaint());
      }
    }

    if (color != null && color.a != 0) {
      final paint = Paint()..color = color;
      if (radius != null) {
        context.canvas.drawRRect(radius.toRRect(rect), paint);
      } else {
        context.canvas.drawRect(rect, paint);
      }
    }

    if (radius != null) {
      // `pushClipRRect` shifts both `bounds` and `clipRRect` by `offset`
      // itself, so they must be passed in local coordinates (relative to
      // this render object's own top-left) — not the already-offset `rect`
      // used above for direct canvas drawing. Passing `rect` here would
      // double-apply `offset`, moving the clip away from where `_paintChild`
      // actually paints and clipping the child out entirely whenever
      // `offset` is non-zero.
      final localRect = Offset.zero & size;
      context.pushClipRRect(needsCompositing, offset, localRect,
          radius.toRRect(localRect), _paintChild);
    } else {
      _paintChild(context, offset);
    }
  }

  void _paintChild(PaintingContext context, Offset offset) {
    if (child != null) super.paint(context, offset);
  }

  @override
  void dispose() {
    if (_registered) {
      _registered = false;
      NibLayoutFrameHook.unregister(this);
    }
    _detachChannels();
    _opacity.removeListener(_onOpacityChanged);
    _translateX.removeListener(_onPaintValueChanged);
    _translateY.removeListener(_onPaintValueChanged);
    _scaleX.removeListener(_onPaintValueChanged);
    _scaleY.removeListener(_onPaintValueChanged);
    _rotate.removeListener(_onPaintValueChanged);
    _skewX.removeListener(_onPaintValueChanged);
    _skewY.removeListener(_onPaintValueChanged);
    _rotateX.removeListener(_onPaintValueChanged);
    _rotateY.removeListener(_onPaintValueChanged);
    _blur.removeListener(_onFilterChanged);
    _tint.removeListener(_onFilterChanged);
    _blurLayer.layer = null;
    if (_ownsRotateX) _rotateX.dispose();
    if (_ownsRotateY) _rotateY.dispose();
    if (_ownsBlur) _blur.dispose();
    if (_ownsTint) _tint.dispose();
    _color.removeListener(_onPaintValueChanged);
    _borderRadius.removeListener(_onPaintValueChanged);
    _boxShadow.removeListener(_onPaintValueChanged);
    super.dispose();
  }
}
