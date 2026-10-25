import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_transition.dart';

/// A single recorded step in a [NibAnimationSequence], built by its fluent
/// `.animate()`/`.wait()`/`.call()` methods and replayed by `.play()`/`.loop()`.
@immutable
abstract class _SequenceStep {
  const _SequenceStep();

  /// Runs this step against [controller], returning a future that completes
  /// once the step (and any wait it implies) is done.
  Future<void> run(NibMotionController controller);
}

class _AnimateStep extends _SequenceStep {
  const _AnimateStep(this.target, this.transition);

  final NibAnim target;
  final NibTransition? transition;

  @override
  Future<void> run(NibMotionController controller) {
    return controller.start(target: target, transition: transition);
  }
}

class _WaitStep extends _SequenceStep {
  const _WaitStep(this.duration);

  final Duration duration;

  @override
  Future<void> run(NibMotionController controller) {
    return Future<void>.delayed(duration);
  }
}

class _CallStep extends _SequenceStep {
  const _CallStep(this.callback);

  final VoidCallback callback;

  @override
  Future<void> run(NibMotionController controller) {
    callback();
    return Future<void>.value();
  }
}

/// How a looping [NibAnimationSequence] repeats.
enum NibLoopMode {
  /// Every repetition replays the steps from the first one.
  restart,

  /// Alternates direction: forward passes replay the steps in order; backward
  /// passes replay them in reverse, animating back through the earlier
  /// animate targets until the first target is reached again. `call` and
  /// `wait` steps run in both directions.
  pingPong,

  /// Like [restart], but when the first animate step targets exactly the
  /// state the last animate step ended on, that step is skipped on repeats so
  /// there is no dead time at the seam.
  seamless,
}

/// A fluent builder for a sequence of animation steps driven against a
/// single [NibMotionController].
///
/// Chain `.animate()`, `.wait()`, and `.call()` to record steps, optionally
/// `.loop()` to repeat them, then call `.play()` to start execution:
///
/// ```dart
/// await NibAnimationSequence(controller)
///   .animate(const NibAnim(y: -20, opacity: 0))
///   .wait(const Duration(milliseconds: 100))
///   .animate(const NibAnim(y: 0, opacity: 1), transition: NibTransition.springGentle)
///   .play();
/// ```
///
/// Internally, each step is executed in order via `async`/`await` against
/// [controller] — `.animate()` steps delegate to
/// [NibMotionController.start], so the same per-step animate/wait semantics
/// as [NibMotionController.sequence] apply, but `.call()` callbacks and
/// `.loop()` repetition are layered on top without modifying
/// [NibMotionController] itself.
class NibAnimationSequence {
  /// Creates a sequence builder over [controller]. Call `.animate()`,
  /// `.wait()`, `.call()`, and `.loop()` to record steps, then `.play()` to
  /// run them.
  NibAnimationSequence(this.controller);

  /// The controller this sequence drives.
  final NibMotionController controller;

  final List<_SequenceStep> _steps = <_SequenceStep>[];

  /// How many times to repeat the recorded steps: `null` means "play the
  /// steps once" (no looping), a positive integer repeats that many times,
  /// and `-1` (set by `.loop()` with no argument) repeats forever until
  /// [stop] is called.
  int? _loopCount;
  NibLoopMode _loopMode = NibLoopMode.restart;

  int _generation = 0;
  Completer<void>? _active;

  /// Queues an animation step that animates [controller] toward [target]
  /// using [transition] (or each attached `NibMotion`'s default transition
  /// if `null`).
  NibAnimationSequence animate(NibAnim target, {NibTransition? transition}) {
    _steps.add(_AnimateStep(target, transition));
    return this;
  }

  /// Queues a delay of [duration] before the next step starts.
  NibAnimationSequence wait(Duration duration) {
    _steps.add(_WaitStep(duration));
    return this;
  }

  /// Queues a synchronous [callback] to run inline, at this point in the
  /// sequence.
  NibAnimationSequence call(VoidCallback callback) {
    _steps.add(_CallStep(callback));
    return this;
  }

  /// Repeats every step recorded so far, either [times] times, or forever
  /// if [times] is omitted/`null`.
  ///
  /// Must be called at most once, after recording the steps to repeat and
  /// before calling [play].
  NibAnimationSequence loop(
      [int? times, NibLoopMode mode = NibLoopMode.restart]) {
    assert(times == null || times > 0,
        'NibAnimationSequence.loop: times must be positive if provided.');
    _loopCount = times ?? -1;
    _loopMode = mode;
    return this;
  }

  /// Starts executing the recorded steps in order.
  ///
  /// If [loop] was called with a finite count, the steps repeat that many
  /// times and the returned [Future] completes once the final repetition
  /// finishes. If [loop] was called with no argument (forever), the steps
  /// repeat indefinitely and the returned [Future] **never completes** —
  /// call [stop] to halt playback (the future remains incomplete even
  /// then; it exists only to let finite sequences be awaited).
  ///
  /// Calling [play] again while already playing has no additional effect
  /// beyond returning a new future tracking the (still in-progress) run.
  Future<void> play() {
    final active = _active;
    if (active != null && !active.isCompleted) return active.future;

    _generation++;
    final completer = Completer<void>();
    _active = completer;
    unawaited(_run(_generation, completer));
    return completer.future;
  }

  List<_SequenceStep> _stepsForPass(int pass) {
    switch (_loopMode) {
      case NibLoopMode.restart:
        return _steps;
      case NibLoopMode.seamless:
        if (pass == 0) return _steps;
        final animates = _steps.whereType<_AnimateStep>().toList();
        if (animates.length < 2 ||
            animates.first.target != animates.last.target) {
          return _steps;
        }
        final skip = animates.first;
        return [
          for (final step in _steps)
            if (!identical(step, skip)) step,
        ];
      case NibLoopMode.pingPong:
        if (pass.isEven) return _steps;
        final result = <_SequenceStep>[];
        for (var i = _steps.length - 1; i >= 0; i--) {
          final step = _steps[i];
          if (step is! _AnimateStep) {
            result.add(step);
            continue;
          }
          // Animate back to the previous animate step's target, if any.
          final previous = _steps.sublist(0, i).whereType<_AnimateStep>();
          if (previous.isEmpty) continue;
          result.add(_AnimateStep(previous.last.target, step.transition));
        }
        return result;
    }
  }

  Future<void> _run(int generation, Completer<void> completer) async {
    final loopCount = _loopCount;
    final forever = loopCount == -1;
    // No loop() call -> play once. Finite loop() -> that many repetitions.
    final repetitions = forever ? null : (loopCount ?? 1);

    // `generation` changes on stop(), so a stopped run that is still awaiting
    // a step can never resume alongside a run started after it.
    var iteration = 0;
    while (generation == _generation && (forever || iteration < repetitions!)) {
      for (final step in _stepsForPass(iteration)) {
        if (generation != _generation) break;
        await step.run(controller);
      }
      iteration++;
    }

    if (!completer.isCompleted && !forever) {
      completer.complete();
    }
    if (identical(_active, completer)) _active = null;
  }

  /// Cancels an in-progress or looping sequence. Steps already started will
  /// still finish their current `run` (e.g. an in-flight animation or
  /// wait), but no further steps will execute.
  void stop() {
    _generation++;
    _active = null;
    controller.stop();
  }

  /// Stops playback and releases this sequence's recorded steps. The
  /// underlying [controller] is not disposed — callers own its lifecycle.
  void dispose() {
    stop();
    _steps.clear();
  }
}
