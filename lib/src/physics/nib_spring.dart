import '../core/nib_transition.dart';
import 'spring_description.dart';

/// Named spring tokens, so an app describes motion by *role* instead of
/// scattering raw mass/stiffness/damping numbers.
///
/// The values are defined by NibMotion (each is a
/// [NibSpringDescription.fromDuration] of a perceptual duration and bounce);
/// they are **not** copies of Material 3 Expressive or Apple numbers. Two
/// families follow the usual split:
///
/// * `spatial*` — things that move or resize. A little overshoot is allowed.
/// * `effects*` — opacity/colour-like changes. Critically damped, never
///   overshoot.
///
/// Each token has a matching [NibTransition] via [NibSpring.transition].
///
/// ```dart
/// NibMotion(
///   animate: const NibAnim(x: 100),
///   transition: NibSpring.spatialDefault.transition,
/// )
/// ```
///
/// Tokens are [NibSpringDescription]s. To pass one where a transition is
/// expected use `NibSpring.smooth.transition` (or
/// `NibTransition(spring: NibSpring.smooth)`).
class NibSpring {
  NibSpring._();

  /// Small, quick spatial movement (e.g. a chip nudge). ~300 ms, slight bounce.
  static final NibSpringDescription spatialFast =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 300), bounce: 0.10);

  /// Default spatial movement. ~450 ms, gentle bounce.
  static final NibSpringDescription spatialDefault =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 450), bounce: 0.15);

  /// Large or deliberate spatial movement. ~700 ms, gentle bounce.
  static final NibSpringDescription spatialSlow =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 700), bounce: 0.15);

  /// Quick non-spatial change (opacity, colour). ~150 ms, no overshoot.
  static final NibSpringDescription effectsFast =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 150));

  /// Default non-spatial change. ~250 ms, no overshoot.
  static final NibSpringDescription effectsDefault =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 250));

  /// Slow non-spatial change. ~400 ms, no overshoot.
  static final NibSpringDescription effectsSlow =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 400));

  /// Tracks a finger or pointer: very quick, no overshoot. ~200 ms.
  static final NibSpringDescription interactive =
      NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 200));

  /// Clean and calm, no overshoot. ~500 ms.
  static final NibSpringDescription smooth = NibSpringDescription.fromDuration(
      duration: const Duration(milliseconds: 500));

  /// Fast and decisive with a hint of overshoot. ~300 ms.
  static final NibSpringDescription snappy = NibSpringDescription.fromDuration(
      duration: const Duration(milliseconds: 300), bounce: 0.15);

  /// Playful, clearly overshoots. ~550 ms.
  static final NibSpringDescription bouncy = NibSpringDescription.fromDuration(
      duration: const Duration(milliseconds: 550), bounce: 0.35);
}

/// Adds [transition] to [NibSpringDescription] so tokens read
/// `NibSpring.smooth.transition`.
extension NibSpringTransition on NibSpringDescription {
  /// A [NibTransition] driven by this spring.
  NibTransition get transition => NibTransition(spring: this);
}
