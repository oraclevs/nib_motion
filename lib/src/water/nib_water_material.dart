import 'dart:ui';

/// Artistic optics, independent of simulation speed and sampling resolution.
///
/// Depth is a 2.5D optical approximation over Flutter content, not volumetric
/// water. Input and semantic bounds remain those of the original widgets.
class NibWaterMaterial {
  /// Creates clear optics. All numeric settings are validated by the surface.
  const NibWaterMaterial(
      {this.refraction = 8,
      this.highlight = .3,
      this.blurSigma = 0,
      this.depth = 0,
      this.absorption = 0,
      this.tint = const Color(0xFF000000)});

  /// No deliberate blur or absorption; moderate displacement and highlights.
  static const clear = NibWaterMaterial();

  /// Neutral forced sampling, useful for fidelity comparisons.
  static const neutral = NibWaterMaterial(refraction: 0, highlight: 0);

  /// Bounded depth-looking shading, without deliberate blur.
  static const deep = NibWaterMaterial(depth: 1, absorption: .12);

  /// Displacement strength in logical pixels, 0..48.
  final double refraction;

  /// Normal-based light strength, 0..2.
  final double highlight;

  /// Optional input blur in logical pixels, 0..12. Zero is unblurred.
  final double blurSigma;

  /// Artistic optical thickness, 0..4; not a world-space depth map.
  final double depth;

  /// Attenuation per unit optical thickness, 0..2.
  final double absorption;

  /// Color approached with increasing absorption. Alpha controls tint strength.
  final Color tint;

  /// Rejects invalid/nonfinite optics in release builds.
  void validate() {
    for (final entry in <String, (double, double)>{
      'refraction': (refraction, 48),
      'highlight': (highlight, 2),
      'blurSigma': (blurSigma, 12),
      'depth': (depth, 4),
      'absorption': (absorption, 2),
      'tint alpha': (tint.a, 1),
      'tint red': (tint.r, 1),
      'tint green': (tint.g, 1),
      'tint blue': (tint.b, 1),
    }.entries) {
      if (!entry.value.$1.isFinite ||
          entry.value.$1 < 0 ||
          entry.value.$1 > entry.value.$2) {
        throw ArgumentError.value(entry.value.$1, entry.key);
      }
    }
  }
}
