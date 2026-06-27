import '../core/nib_anim.dart';
import '../core/nib_transition.dart';
import 'nib_keyframe.dart';

/// Implemented by `_NibMotionState` so external collaborators
/// (`NibMotionController`, `NibPresence`) can drive its animations without
/// depending on the widget's private state type.
abstract class NibMotionAnimator {
  /// Animates every property present in [target] toward its value, using
  /// [transition] (or the widget's default transition if `null`).
  ///
  /// Returns a future that completes once all animated properties have
  /// settled.
  Future<void> animateTo(NibAnim target, {NibTransition? transition});

  /// Plays the widget's `exit` animation, if any, and completes once it has
  /// settled. Called by `NibPresence` before removing the widget.
  Future<void> triggerExit();

  /// Sets every property present in [target] immediately, with no animation,
  /// cancelling any animations currently in progress for those properties.
  void setImmediately(NibAnim target);

  /// Stops all in-progress animations, freezing every animated property at
  /// its current value.
  void stopAnimations();

  /// Replays this widget's entrance animation (`initial` -> `animate`/`keyframes`,
  /// or restarts the [NibMotion.repeatAnimationInLoop] loop), as if it had just
  /// been built for the first time. Same effect as the existing
  /// `NibMotionReplaySignal`-driven replay.
  Future<void> replayEntrance();

  /// Plays [keyframes] once, from `0.0` to `1.0`, using [transition] (or the
  /// widget's default transition if `null`). Returns a future that completes
  /// when the keyframe animation settles.
  Future<void> playKeyframes(List<NibKeyframe> keyframes,
      {NibTransition? transition});

  /// Enables or disables [NibMotion.repeatAnimationInLoop]'s ping-pong loop at
  /// runtime, regardless of the widget's `repeatAnimationInLoop` value.
  void setRepeatLoop(bool enabled);
}
