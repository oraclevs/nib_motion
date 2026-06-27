import 'package:flutter/widgets.dart';

import '../core/nib_motion_animator.dart';

/// Register/unregister callbacks provided by an ancestor `NibPresence`.
///
/// `_NibMotionState` calls [register] when it finds a [NibPresenceScope]
/// above it (and a [Key] is set), and [unregister] when it is disposed or
/// the scope changes.
class NibPresenceRegistration {
  /// Creates a registration with the given callbacks.
  const NibPresenceRegistration(
      {required this.register, required this.unregister});

  /// Called with the `NibMotion`'s [Key] and its [NibMotionAnimator] when it
  /// mounts under a [NibPresenceScope].
  final void Function(Key key, NibMotionAnimator animator) register;

  /// Called with the `NibMotion`'s [Key] when it unmounts or the scope
  /// changes.
  final void Function(Key key) unregister;
}

/// Provides a [NibPresenceRegistration] to descendant `NibMotion` widgets so
/// they can participate in exit animations orchestrated by an ancestor
/// `NibPresence`.
class NibPresenceScope extends InheritedWidget {
  /// Creates a scope exposing [registration] to [child] and its descendants.
  const NibPresenceScope(
      {super.key, required this.registration, required super.child});

  /// The register/unregister callbacks for this scope.
  final NibPresenceRegistration registration;

  /// Returns the nearest [NibPresenceScope]'s registration, or `null` if
  /// there is none.
  static NibPresenceRegistration? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<NibPresenceScope>()
        ?.registration;
  }

  @override
  bool updateShouldNotify(NibPresenceScope oldWidget) => false;
}
