import 'package:flutter/widgets.dart';

/// Hands out sequential indices to descendant `NibMotion`s for
/// `NibTransition.staggerChildren` timing.
///
/// One instance is created per `NibMotion` (shared via [VariantsScope] with
/// its direct child subtree) so each descendant `NibMotion` that resolves its
/// `animate` from this scope's [VariantsScope.variant] claims a distinct,
/// order-of-build index via [next].
class VariantsIndexCounter {
  int _next = 0;

  /// Returns the next sequential index, starting at `0`.
  int next() => _next++;
}

/// Propagates the active variant name set by the nearest ancestor
/// `NibMotion` (via a `String` `animate`), plus the stagger timing from its
/// `NibTransition`, to descendant `NibMotion`s that declare a matching
/// `variants` map.
class VariantsScope extends InheritedWidget {
  /// Creates a scope exposing [variant] and stagger timing to [child] and its
  /// descendants.
  const VariantsScope({
    super.key,
    required this.variant,
    required this.delayChildren,
    required this.staggerChildren,
    required this.indexCounter,
    required super.child,
  });

  /// The active variant name, or `null` if no ancestor `NibMotion` set one.
  final String? variant;

  /// Extra delay before the first staggered descendant starts animating.
  final Duration delayChildren;

  /// Extra delay applied per descendant index when staggering.
  final Duration staggerChildren;

  /// Shared counter descendants use to claim a stagger index.
  final VariantsIndexCounter indexCounter;

  /// Returns the nearest ancestor [VariantsScope], registering [context] as a
  /// dependent so it is notified when [variant] (or the stagger timing)
  /// changes.
  static VariantsScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VariantsScope>();
  }

  @override
  bool updateShouldNotify(VariantsScope oldWidget) {
    return variant != oldWidget.variant ||
        delayChildren != oldWidget.delayChildren ||
        staggerChildren != oldWidget.staggerChildren;
  }
}
