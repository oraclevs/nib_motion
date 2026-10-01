import 'package:flutter/foundation.dart';

import '../values/motion_value.dart';
import 'nib_anim.dart';
import 'nib_keyframe.dart';
import 'nib_motion_animator.dart';
import 'nib_property.dart';
import 'nib_transition.dart';

/// A single step in a [NibMotionController.sequence].
@immutable
class NibMotionSequenceStep {
  /// Creates a sequence step that animates to [target] using [transition]
  /// (or each `NibMotion`'s default transition if `null`), then waits for
  /// [wait] before the next step starts.
  const NibMotionSequenceStep(
      {required this.target, this.transition, this.wait});

  /// The animation values to transition toward.
  final NibAnim target;

  /// The transition to use for this step. `null` uses each attached
  /// `NibMotion`'s default transition.
  final NibTransition? transition;

  /// How long to pause after this step's animation completes before starting
  /// the next step. `null` chains directly into the next step.
  final Duration? wait;
}

/// External handle for driving one or more [NibMotion] widgets' animations
/// imperatively — equivalent to Framer Motion's `useAnimationControls()`.
///
/// ```dart
/// final controller = NibMotionController();
///
/// @override
/// Widget build(BuildContext context) {
///   return Column(children: [
///     ElevatedButton(
///       onPressed: () => controller.start(target: const NibAnim(opacity: 0, y: -20)),
///       child: const Text('Hide'),
///     ),
///     NibMotion(
///       controller: controller,
///       animate: const NibAnim(opacity: 1, y: 0),
///       child: MyWidget(),
///     ),
///   ]);
/// }
///
/// @override
/// void dispose() {
///   controller.dispose();
///   super.dispose();
/// }
/// ```
///
/// A single controller can be attached to multiple `NibMotion` widgets (by
/// passing it to each one's `controller` parameter); every method below
/// applies to all of them.
class NibMotionController extends ChangeNotifier {
  final Set<NibMotionAnimator> _animators = <NibMotionAnimator>{};
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Attaches this controller to [animator]. Called by `_NibMotionState`
  /// during `initState`/`didUpdateWidget`.
  void attach(NibMotionAnimator animator) {
    _animators.add(animator);
  }

  /// Detaches [animator] from this controller. Called by `_NibMotionState`
  /// during `dispose`/`didUpdateWidget`.
  void detach(NibMotionAnimator animator) {
    _animators.remove(animator);
  }

  /// Drives every attached `NibMotion`:
  /// - `start(target: ..., transition: ...)` — animates toward `target` (old behavior).
  /// - `start(keyframes: [...], transition: ...)` — plays that keyframe sequence once.
  /// - `start()` (both null) — replays each widget's entrance animation
  ///   (`initial` -> `animate`/`keyframes`, or restarts its
  ///   `repeatAnimationInLoop` loop).
  ///
  /// Only one of `target`/`keyframes` may be provided.
  Future<void> start(
      {NibAnim? target,
      List<NibKeyframe>? keyframes,
      NibTransition? transition}) {
    assert(
      target == null || keyframes == null,
      'NibMotionController.start: only one of `target` or `keyframes` may be provided.',
    );
    final futures = _animators.map((animator) {
      if (keyframes != null) {
        return animator.playKeyframes(keyframes, transition: transition);
      }
      if (target != null) {
        return animator.animateTo(target, transition: transition);
      }
      return animator.replayEntrance();
    });
    return Future.wait(futures).then((_) {
      // Animations resolve when superseded or when their widget is disposed,
      // which can happen after this controller itself was disposed.
      if (!_disposed) notifyListeners();
    });
  }

  /// The live [MotionValue] behind [property] of the first attached
  /// `NibMotion`, or `null` if none is attached yet.
  ///
  /// It is the widget's own value, so it carries `value` and `velocity` and
  /// can be listened to (`addListener`) without rebuilding anything.
  MotionValue<double>? motionValueOf(NibProperty property) {
    for (final animator in _animators) {
      final value = animator.motionValueOf(property);
      if (value != null) return value;
    }
    return null;
  }

  /// The current velocity of [property] in units per second (`0` when
  /// nothing is attached or the property is at rest).
  double velocityOf(NibProperty property) =>
      motionValueOf(property)?.velocity ?? 0.0;

  /// A snapshot of the velocity of every [NibProperty].
  Map<NibProperty, double> get velocities => <NibProperty, double>{
        for (final property in NibProperty.values)
          property: velocityOf(property),
      };

  /// The start state of the first attached `NibMotion` (its `initial`),
  /// merged over [NibAnim.identity]; [NibAnim.identity] if none is attached.
  NibAnim get initialAnim {
    for (final animator in _animators) {
      return animator.initialAnim;
    }
    return NibAnim.identity;
  }

  /// Immediately sets every attached `NibMotion` to [target], with no
  /// animation.
  ///
  /// Each property's velocity is reset to zero unless [keepVelocity] is true,
  /// in which case a following [start] continues the motion in progress.
  void set(NibAnim target, {bool keepVelocity = false}) {
    for (final animator in _animators) {
      animator.setImmediately(target, keepVelocity: keepVelocity);
    }
    notifyListeners();
  }

  /// Stops all in-progress animations on every attached `NibMotion`,
  /// freezing each animated property at its current value.
  void stop() {
    for (final animator in _animators) {
      animator.stopAnimations();
    }
    notifyListeners();
  }

  /// Enables (or, with `enabled: false`, disables) [NibMotion.repeatAnimationInLoop]'s
  /// ping-pong loop at runtime on every attached `NibMotion`, regardless of
  /// that widget's `repeatAnimationInLoop` value.
  void repeat([bool enabled = true]) {
    for (final animator in _animators) {
      animator.setRepeatLoop(enabled);
    }
    notifyListeners();
  }

  /// Runs [steps] in order, waiting for each step's animation to complete
  /// (and its [NibMotionSequenceStep.wait], if any) before starting the
  /// next.
  Future<void> sequence(List<NibMotionSequenceStep> steps) async {
    for (final step in steps) {
      await start(target: step.target, transition: step.transition);
      final wait = step.wait;
      if (wait != null) {
        await Future<void>.delayed(wait);
      }
    }
  }
}
