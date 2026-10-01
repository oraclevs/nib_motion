import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/reduced_motion_mixin.dart';
import '../values/motion_value.dart';

/// Renders [text] once, then paints an animated [gradient] sweep across it by
/// masking the gradient onto the text's painted pixels via `BlendMode.srcIn`.
///
/// The sweep position is driven by a single `MotionValue<double>` (`_offset`)
/// that a `Ticker` owned by `_NibGradientTextState` advances every frame —
/// mirroring how `SpringSolver`/`InertiaSolver` tick a `Ticker` and write into
/// a `MotionValue` rather than calling `setState`. `RenderNibGradientText`
/// listens to that `MotionValue` and repaints via `markNeedsPaint()`, so the
/// sweep animates without ever rebuilding the widget tree.
class NibGradientText extends StatefulWidget {
  /// Creates a `NibGradientText` that sweeps [gradient] across [text].
  const NibGradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.duration = const Duration(milliseconds: 2000),
    this.repeat = true,
    this.direction = TextDirection.ltr,
  });

  /// The text to render.
  final String text;

  /// The gradient swept across [text].
  final Gradient gradient;

  /// The base text style. Its color is ignored — the gradient masks the
  /// glyphs instead.
  final TextStyle? style;

  /// How long one full sweep across the text takes.
  final Duration duration;

  /// Whether the sweep repeats forever (`true`) or plays once and stops
  /// (`false`).
  final bool repeat;

  /// The direction the sweep travels: left-to-right or right-to-left.
  final TextDirection direction;

  @override
  State<NibGradientText> createState() => _NibGradientTextState();
}

class _NibGradientTextState extends State<NibGradientText>
    with SingleTickerProviderStateMixin, NibReducedMotionMixin {
  late final MotionValue<double> _offset = MotionValue<double>(
    widget.direction == TextDirection.ltr ? -1.0 : 1.0,
  );
  Ticker? _ticker;
  Duration _previousElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void onReducedMotionChanged(bool reduced) => _startTicker();

  void _startTicker() {
    _ticker?.dispose();
    _ticker = null;
    // Decorative loop: reduced motion leaves the gradient at its static frame.
    if (reduceMotion) return;
    _previousElapsed = Duration.zero;
    final ticker = createTicker(_onTick);
    _ticker = ticker;
    ticker.start();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _previousElapsed;
    _previousElapsed = elapsed;

    final durationMicros = widget.duration.inMicroseconds;
    if (durationMicros <= 0) return;

    final deltaT = delta.inMicroseconds / durationMicros;
    final sign = widget.direction == TextDirection.ltr ? 1.0 : -1.0;

    var next = _offset.value + sign * deltaT * 2.0;

    if (next > 1.0 || next < -1.0) {
      if (!widget.repeat) {
        _ticker?.stop();
        next = next.clamp(-1.0, 1.0);
      } else {
        // Wrap back to the opposite edge so the sweep loops continuously.
        next = sign > 0 ? -1.0 : 1.0;
      }
    }

    _offset.value = next;
  }

  @override
  void didUpdateWidget(NibGradientText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.repeat != widget.repeat ||
        oldWidget.direction != widget.direction) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? const TextStyle())
        .copyWith(color: const Color(0xFF000000));
    return _NibGradientTextBox(
      text: widget.text,
      style: effectiveStyle,
      gradient: widget.gradient,
      offset: _offset,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}

/// Bridges [offset] and the other paint inputs to [RenderNibGradientText].
class _NibGradientTextBox extends LeafRenderObjectWidget {
  const _NibGradientTextBox({
    required this.text,
    required this.style,
    required this.gradient,
    required this.offset,
    required this.textDirection,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;
  final MotionValue<double> offset;
  final TextDirection textDirection;

  @override
  RenderNibGradientText createRenderObject(BuildContext context) {
    return RenderNibGradientText(
      text: text,
      style: style,
      gradient: gradient,
      offset: offset,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderNibGradientText renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..gradient = gradient
      ..offset = offset
      ..textDirection = textDirection;
  }
}

/// Paints [text] once via a `TextPainter`, then paints it again through an
/// animated [gradient] using `saveLayer` + `BlendMode.srcIn`, so only the
/// glyphs' pixels are tinted by the gradient. The gradient's sweep position
/// comes from [offset], a `MotionValue<double>` ticked by the owning state's
/// `Ticker` — this render object only listens and repaints, it never drives
/// the animation itself.
class RenderNibGradientText extends RenderBox {
  /// Creates a render object that paints [text] masked by an animated
  /// [gradient] sweep.
  RenderNibGradientText({
    required String text,
    required TextStyle style,
    required Gradient gradient,
    required MotionValue<double> offset,
    required TextDirection textDirection,
  })  : _text = text,
        _style = style,
        _gradient = gradient,
        _offset = offset,
        _textDirection = textDirection {
    _offset.addListener(_onOffsetChanged);
    _buildPainter();
  }

  String _text;
  TextStyle _style;
  Gradient _gradient;
  MotionValue<double> _offset;
  TextDirection _textDirection;

  TextPainter? _painter;

  /// The text being painted.
  String get text => _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
    _buildPainter();
    markNeedsLayout();
  }

  /// The base text style (its color is ignored — the gradient masks the
  /// glyphs).
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (_style == value) return;
    _style = value;
    _buildPainter();
    markNeedsLayout();
  }

  /// The gradient swept across the text.
  Gradient get gradient => _gradient;
  set gradient(Gradient value) {
    if (_gradient == value) return;
    _gradient = value;
    markNeedsPaint();
  }

  /// The sweep position, in the range `[-1.0, 1.0]`, where `0.0` centers the
  /// gradient on the text.
  MotionValue<double> get offset => _offset;
  set offset(MotionValue<double> value) {
    if (_offset == value) return;
    _offset.removeListener(_onOffsetChanged);
    _offset = value;
    _offset.addListener(_onOffsetChanged);
    markNeedsPaint();
  }

  /// The text direction used to lay out [text].
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _buildPainter();
    markNeedsLayout();
  }

  void _onOffsetChanged() => markNeedsPaint();

  void _buildPainter() {
    _painter = TextPainter(
      text: TextSpan(text: _text, style: _style),
      textDirection: _textDirection,
    );
  }

  @override
  void performLayout() {
    final painter = _painter!;
    final constraints = this.constraints;
    painter.layout(maxWidth: constraints.maxWidth);
    size = constraints.constrain(painter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painter = _painter!;
    final canvas = context.canvas;
    final rect = offset & size;

    canvas.saveLayer(rect, Paint());
    painter.paint(canvas, offset);

    final sweepCenter = _offset.value;
    // Expand the gradient's effective span beyond the text bounds so the
    // sweep can travel fully off one edge and back in from the other.
    final span = rect.width.clamp(1.0, double.infinity);
    final gradientRect = Rect.fromLTWH(
      rect.left + sweepCenter * span - span,
      rect.top,
      span * 2,
      rect.height,
    );

    final paint = Paint()
      ..shader = _gradient.createShader(gradientRect)
      ..blendMode = BlendMode.srcIn;
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  void dispose() {
    _offset.removeListener(_onOffsetChanged);
    super.dispose();
  }
}
