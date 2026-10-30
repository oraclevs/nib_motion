import 'dart:math' as math;
import 'dart:ui';

/// Content sampling policy, independent of wave speed and optical strength.
enum NibWaterSampling {
  /// Original asynchronous snapshot path; `captureScale` remains absolute.
  legacy,

  /// Sample the current child layers during scene composition.
  live,

  /// Cache artwork until layout, quality, or explicit invalidation changes.
  static,

  /// Sample changing layers at the surface's configured interval.
  throttled,
}

/// Device-relative sampling quality for the experimental layer sampler.
///
/// Budgets cover one RGBA input texture, not total GPU or Flutter memory.
/// The renderer retains at most one input image and one output picture.
class NibWaterQuality {
  /// Requests device resolution, bounded by pixels, bytes and texture axes.
  const NibWaterQuality(
      {this.scale = 1,
      this.maxPixels = 4000000,
      this.maxBytes = 16000000,
      this.maxTextureSize = 4096});

  /// Multiplier of device pixel ratio, in .25..2.
  final double scale;

  /// Maximum input texels, including any supplied background padding.
  final int maxPixels;

  /// Maximum estimated input RGBA bytes; four bytes per texel.
  final int maxBytes;

  /// Conservative axis limit; callers must respect their backend's limits.
  final int maxTextureSize;

  /// Validates settings in release builds, including before first layout.
  void validate() {
    if (!scale.isFinite ||
        scale < .25 ||
        scale > 2 ||
        maxPixels < 1 ||
        maxBytes < 4 ||
        maxTextureSize < 1 ||
        maxTextureSize > 16384) {
      throw ArgumentError('Invalid water quality or texture budget');
    }
  }

  /// Resolves finite logical bounds to a bounded input texture.
  NibWaterResolution resolve(Size size, double devicePixelRatio) {
    validate();
    if (!size.isFinite ||
        size.isEmpty ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      throw ArgumentError(
          'Water bounds and device pixel ratio must be finite and positive');
    }
    final requested = devicePixelRatio * scale;
    if (!requested.isFinite || !(size.width * size.height).isFinite) {
      throw ArgumentError('Water dimensions or scale exceed finite arithmetic');
    }
    final budget = math.min(maxPixels, maxBytes ~/ 4);
    var effective = math.min(
        requested,
        math.min(math.sqrt(budget / (size.width * size.height)),
            maxTextureSize / math.max(size.width, size.height)));
    bool fits(double value) =>
        (size.width * value).ceil() <= maxTextureSize &&
        (size.height * value).ceil() <= maxTextureSize &&
        (size.width * value).ceil() * (size.height * value).ceil() <= budget;
    // Account for integer texture dimensions at fractional scales.
    if (!fits(effective)) {
      var low = 0.0, high = effective;
      for (var i = 0; i < 48; i++) {
        final mid = (low + high) / 2;
        if (fits(mid)) {
          low = mid;
        } else {
          high = mid;
        }
      }
      effective = low;
    }
    if (effective <= 0 ||
        !effective.isFinite ||
        (size.width * effective).ceil() < 1 ||
        (size.height * effective).ceil() < 1) {
      throw ArgumentError('Water input cannot fit the requested budget');
    }
    return NibWaterResolution(
        requested,
        effective,
        (size.width * effective).ceil(),
        (size.height * effective).ceil(),
        effective < requested
            ? 'Input texture reduced by pixel/byte/axis budget'
            : 'Device-relative target met');
  }
}

/// Selected input dimensions; memory estimates exclude engine intermediates.
class NibWaterResolution {
  /// Records a resolved sampling budget.
  const NibWaterResolution(this.requestedScale, this.effectiveScale, this.width,
      this.height, this.reason);

  /// Requested pixels per logical pixel.
  final double requestedScale;

  /// Selected pixels per logical pixel before integer dimension rounding.
  final double effectiveScale;

  /// Input texture width in pixels.
  final int width;

  /// Input texture height in pixels.
  final int height;

  /// Explanation of any quality reduction.
  final String reason;

  /// Estimated uncompressed input bytes, not total GPU memory.
  int get estimatedBytes => width * height * 4;
}
