import 'package:flutter/widgets.dart';

/// A signal that, when fired via [replay], tells every descendant
/// [NibMotion] with an entrance animation (`initial`/`animate`/`keyframes`)
/// to replay it from scratch — as if it had just been built for the first
/// time.
///
/// Provided to a subtree via [NibMotionReplayScope]. Used by
/// `NibScreenStack` to optionally retrigger a tab's page animations after
/// its enter transition finishes, when
/// `NibNavScreenTransition.retriggerPageAnimations` is `true`.
class NibMotionReplaySignal extends ChangeNotifier {
  /// The delay requested by the most recent [replay] call. Listeners read
  /// this to decide how long to wait before actually replaying their
  /// entrance animation.
  Duration lastReplayDelay = Duration.zero;

  /// Notifies every listening descendant [NibMotion] that a replay was
  /// requested. Notification happens immediately regardless of [delay] —
  /// [delay] is recorded in [lastReplayDelay] for listeners to apply before
  /// replaying their entrance animation.
  void replay({Duration delay = Duration.zero}) {
    lastReplayDelay = delay;
    notifyListeners();
  }
}

/// Provides a [NibMotionReplaySignal] to descendant [NibMotion] widgets.
///
/// A [NibMotion] with a non-null [NibMotion.animate]/[NibMotion.keyframes]
/// listens to the nearest ancestor [NibMotionReplaySignal] (if any) and
/// replays its entrance animation whenever [NibMotionReplaySignal.replay] is
/// called.
class NibMotionReplayScope extends InheritedNotifier<NibMotionReplaySignal> {
  /// Creates a replay scope providing [signal] to [child] and its
  /// descendants.
  const NibMotionReplayScope({
    super.key,
    required NibMotionReplaySignal signal,
    required super.child,
  }) : super(notifier: signal);

  /// Returns the nearest ancestor [NibMotionReplaySignal], or `null` if this
  /// widget is not inside a [NibMotionReplayScope].
  static NibMotionReplaySignal? maybeOf(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<NibMotionReplayScope>();
    return widget?.notifier;
  }
}
