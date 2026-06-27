import '../core/nib_anim.dart';
import '../core/nib_keyframe.dart';

/// A library of common, ready-to-use animations for `NibMotion`.
///
/// The [List<NibKeyframe>] presets are passed to `NibMotion.keyframes` (e.g.
/// `NibMotion(keyframes: NibAnimPresets.shake, child: ...)`) to play a
/// multi-step animation. The [NibAnim] presets are single-state snapshots
/// meant for `NibMotion.initial`/`NibMotion.animate` (e.g.
/// `NibMotion(initial: NibAnimPresets.fadeUp, animate: NibAnim(opacity: 1, y: 0))`).
abstract final class NibAnimPresets {
  /// Rapid left-right oscillation, commonly used for input validation
  /// feedback (see `NibShake`).
  static const List<NibKeyframe> shake = [
    NibKeyframe(at: 0.0, value: NibAnim(x: 0)),
    NibKeyframe(at: 0.1, value: NibAnim(x: -10)),
    NibKeyframe(at: 0.3, value: NibAnim(x: 10)),
    NibKeyframe(at: 0.5, value: NibAnim(x: -8)),
    NibKeyframe(at: 0.7, value: NibAnim(x: 8)),
    NibKeyframe(at: 0.9, value: NibAnim(x: -4)),
    NibKeyframe(at: 1.0, value: NibAnim(x: 0)),
  ];

  /// Drops in from above and settles with a small bounce, commonly used for
  /// enter animations (see `NibBounce`).
  static const List<NibKeyframe> bounceIn = [
    NibKeyframe(at: 0.0, value: NibAnim(y: -60, opacity: 0)),
    NibKeyframe(at: 0.6, value: NibAnim(y: 0, opacity: 1)),
    NibKeyframe(at: 0.75, value: NibAnim(y: -12)),
    NibKeyframe(at: 0.9, value: NibAnim(y: 0)),
    NibKeyframe(at: 0.95, value: NibAnim(y: -4)),
    NibKeyframe(at: 1.0, value: NibAnim(y: 0)),
  ];

  /// Scales up and back down, commonly used as a repeating "heartbeat"
  /// animation (see `NibPulse`).
  static const List<NibKeyframe> pulse = [
    NibKeyframe(at: 0.0, value: NibAnim(scale: 1.0)),
    NibKeyframe(at: 0.5, value: NibAnim(scale: 1.08)),
    NibKeyframe(at: 1.0, value: NibAnim(scale: 1.0)),
  ];

  /// Overshoots non-uniformly on each axis and settles, like a rubber band
  /// snapping back into shape (see `NibRubberBand`).
  static const List<NibKeyframe> rubberBand = [
    NibKeyframe(at: 0.0, value: NibAnim(scaleX: 1.0, scaleY: 1.0)),
    NibKeyframe(at: 0.3, value: NibAnim(scaleX: 1.25, scaleY: 0.75)),
    NibKeyframe(at: 0.4, value: NibAnim(scaleX: 0.75, scaleY: 1.25)),
    NibKeyframe(at: 0.5, value: NibAnim(scaleX: 1.15, scaleY: 0.85)),
    NibKeyframe(at: 0.65, value: NibAnim(scaleX: 0.95, scaleY: 1.05)),
    NibKeyframe(at: 0.75, value: NibAnim(scaleX: 1.05, scaleY: 0.95)),
    NibKeyframe(at: 1.0, value: NibAnim(scaleX: 1.0, scaleY: 1.0)),
  ];

  /// Gentle rotation oscillation.
  static const List<NibKeyframe> wiggle = [
    NibKeyframe(at: 0.0, value: NibAnim(rotate: 0)),
    NibKeyframe(at: 0.15, value: NibAnim(rotate: -0.03)),
    NibKeyframe(at: 0.3, value: NibAnim(rotate: 0.03)),
    NibKeyframe(at: 0.45, value: NibAnim(rotate: -0.02)),
    NibKeyframe(at: 0.6, value: NibAnim(rotate: 0.02)),
    NibKeyframe(at: 0.75, value: NibAnim(rotate: -0.01)),
    NibKeyframe(at: 1.0, value: NibAnim(rotate: 0)),
  ];

  /// Fade in from below — a common enter animation starting state.
  static const NibAnim fadeUp = NibAnim(opacity: 0, y: 24);

  /// Fade in from above.
  static const NibAnim fadeDown = NibAnim(opacity: 0, y: -24);

  /// Fade in from the left.
  static const NibAnim fadeLeft = NibAnim(opacity: 0, x: -24);

  /// Fade in from the right.
  static const NibAnim fadeRight = NibAnim(opacity: 0, x: 24);

  /// Zoom in from slightly smaller than identity.
  static const NibAnim zoomIn = NibAnim(opacity: 0, scale: 0.85);

  /// Zoom out from slightly larger than identity.
  static const NibAnim zoomOut = NibAnim(opacity: 0, scale: 1.15);
}
