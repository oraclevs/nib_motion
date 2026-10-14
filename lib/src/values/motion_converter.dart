import 'package:flutter/painting.dart';

/// Splits a value type into independent scalar channels so each channel can be
/// driven by its own physics, and joins the channels back.
///
/// `Offset(dx, dy)` is two channels; a spring toward a new `Offset` moves `dx`
/// and `dy` with *independent* positions and velocities, exactly as two
/// separate scalar springs would, but writes one composed value.
abstract class MotionConverter<T> {
  /// Const constructor for subclasses.
  const MotionConverter();

  /// Creates a converter from closures, for types NibMotion does not know.
  ///
  /// [normalize] must return exactly [channels] numbers and [denormalize]
  /// must accept a list of that length.
  const factory MotionConverter.custom({
    required int channels,
    required List<double> Function(T value) normalize,
    required T Function(List<double> channels) denormalize,
  }) = _CustomConverter<T>;

  /// A plain scalar (one channel).
  static const MotionConverter<double> scalar = _ScalarConverter();

  /// `Offset` as `[dx, dy]`.
  static const MotionConverter<Offset> offset = _OffsetConverter();

  /// `Size` as `[width, height]`.
  static const MotionConverter<Size> size = _SizeConverter();

  /// `Rect` as `[left, top, right, bottom]`.
  static const MotionConverter<Rect> rect = _RectConverter();

  /// `Alignment` as `[x, y]`.
  static const MotionConverter<Alignment> alignment = _AlignmentConverter();

  /// `EdgeInsets` as `[left, top, right, bottom]`.
  static const MotionConverter<EdgeInsets> edgeInsets = _EdgeInsetsConverter();

  /// `Color` as `[alpha, red, green, blue]` in `0..1`. Springs that overshoot
  /// are clamped back into range when the colour is rebuilt.
  static const MotionConverter<Color> color = _ColorConverter();

  /// The built-in converter for [T], or `null` if there is none.
  static MotionConverter<T>? maybeFor<T>() {
    final Object? found = switch (T) {
      const (double) => scalar,
      const (Offset) => offset,
      const (Size) => size,
      const (Rect) => rect,
      const (Alignment) => alignment,
      const (EdgeInsets) => edgeInsets,
      const (Color) => color,
      _ => null,
    };
    return found as MotionConverter<T>?;
  }

  /// How many scalar channels [T] is split into.
  int get channels;

  /// Splits [value] into [channels] numbers.
  List<double> normalize(T value);

  /// Rebuilds a [T] from [channels] numbers.
  T denormalize(List<double> channels);
}

class _CustomConverter<T> extends MotionConverter<T> {
  const _CustomConverter({
    required this.channels,
    required List<double> Function(T value) normalize,
    required T Function(List<double> channels) denormalize,
  })  : _normalize = normalize,
        _denormalize = denormalize;

  @override
  final int channels;
  final List<double> Function(T) _normalize;
  final T Function(List<double>) _denormalize;

  @override
  List<double> normalize(T value) {
    final out = _normalize(value);
    assert(out.length == channels, 'normalize must return $channels channels');
    return out;
  }

  @override
  T denormalize(List<double> channels) => _denormalize(channels);
}

class _ScalarConverter extends MotionConverter<double> {
  const _ScalarConverter();
  @override
  int get channels => 1;
  @override
  List<double> normalize(double value) => [value];
  @override
  double denormalize(List<double> c) => c[0];
}

class _OffsetConverter extends MotionConverter<Offset> {
  const _OffsetConverter();
  @override
  int get channels => 2;
  @override
  List<double> normalize(Offset v) => [v.dx, v.dy];
  @override
  Offset denormalize(List<double> c) => Offset(c[0], c[1]);
}

class _SizeConverter extends MotionConverter<Size> {
  const _SizeConverter();
  @override
  int get channels => 2;
  @override
  List<double> normalize(Size v) => [v.width, v.height];
  @override
  Size denormalize(List<double> c) => Size(c[0], c[1]);
}

class _RectConverter extends MotionConverter<Rect> {
  const _RectConverter();
  @override
  int get channels => 4;
  @override
  List<double> normalize(Rect v) => [v.left, v.top, v.right, v.bottom];
  @override
  Rect denormalize(List<double> c) => Rect.fromLTRB(c[0], c[1], c[2], c[3]);
}

class _AlignmentConverter extends MotionConverter<Alignment> {
  const _AlignmentConverter();
  @override
  int get channels => 2;
  @override
  List<double> normalize(Alignment v) => [v.x, v.y];
  @override
  Alignment denormalize(List<double> c) => Alignment(c[0], c[1]);
}

class _EdgeInsetsConverter extends MotionConverter<EdgeInsets> {
  const _EdgeInsetsConverter();
  @override
  int get channels => 4;
  @override
  List<double> normalize(EdgeInsets v) => [v.left, v.top, v.right, v.bottom];
  @override
  EdgeInsets denormalize(List<double> c) =>
      EdgeInsets.fromLTRB(c[0], c[1], c[2], c[3]);
}

class _ColorConverter extends MotionConverter<Color> {
  const _ColorConverter();
  @override
  int get channels => 4;
  @override
  List<double> normalize(Color v) => [v.a, v.r, v.g, v.b];
  @override
  Color denormalize(List<double> c) => Color.from(
        alpha: c[0].clamp(0.0, 1.0),
        red: c[1].clamp(0.0, 1.0),
        green: c[2].clamp(0.0, 1.0),
        blue: c[3].clamp(0.0, 1.0),
      );
}
