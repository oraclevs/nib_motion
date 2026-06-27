import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'nib_anim.dart';

/// One point in a multi-step animation driven by `NibMotion.keyframes`.
///
/// Keyframes describe a [value] reached at a given progress [at] (`0.0` to
/// `1.0`) along the animation, with an optional per-segment [curve].
@immutable
class NibKeyframe {
  /// Creates a keyframe reached at progress [at].
  const NibKeyframe({required this.at, required this.value, this.curve});

  /// The progress (`0.0` to `1.0`) along the keyframe animation at which
  /// [value] is reached.
  final double at;

  /// The animation state at [at].
  final NibAnim value;

  /// The easing curve for the segment leading into this keyframe, from the
  /// previous keyframe's [value] to this one.
  ///
  /// `null` falls back to the `defaultCurve` passed to
  /// [computeAnimFromKeyframes] (typically `NibTransition.curve`).
  final Curve? curve;
}

/// Computes the [NibAnim] at progress [t] along [keyframes].
///
/// [keyframes] is sorted by [NibKeyframe.at] first if it isn't already.
///
/// - If [t] is at or before the first keyframe, returns its [NibKeyframe.value]
///   directly.
/// - If [t] is at or after the last keyframe, returns its [NibKeyframe.value]
///   directly.
/// - Otherwise, finds the two keyframes surrounding [t], normalizes [t] into
///   that segment, applies the upcoming keyframe's [NibKeyframe.curve] (or
///   [defaultCurve] if unset), and interpolates between the two keyframes'
///   values with [NibAnim.lerp].
NibAnim computeAnimFromKeyframes(List<NibKeyframe> keyframes, double t, Curve defaultCurve) {
  assert(keyframes.isNotEmpty, 'NibMotion.keyframes must not be empty.');

  var sorted = keyframes;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].at < sorted[i - 1].at) {
      sorted = List<NibKeyframe>.of(keyframes)..sort((a, b) => a.at.compareTo(b.at));
      break;
    }
  }

  if (sorted.length == 1) return sorted.first.value;
  if (t <= sorted.first.at) return sorted.first.value;
  if (t >= sorted.last.at) return sorted.last.value;

  var lo = 0;
  var hi = sorted.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].at <= t) {
      lo = mid;
    } else {
      hi = mid;
    }
  }

  final from = sorted[lo];
  final to = sorted[hi];
  final segmentT = (t - from.at) / (to.at - from.at);
  final curvedT = (to.curve ?? defaultCurve).transform(segmentT);
  return from.value.lerp(to.value, curvedT);
}
