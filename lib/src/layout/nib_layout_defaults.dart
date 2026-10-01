import 'package:flutter/widgets.dart';

import 'nib_layout.dart';

/// Supplies a default [NibLayout] to descendant `NibMotion`s that leave their
/// own `layout` at [NibLayout.none].
///
/// This is what lets `NibPresence.layout` turn on FLIP reflow for every child
/// with one call. A `NibMotion` that sets `layout` explicitly (anything other
/// than [NibLayout.none]) keeps its own value; because [NibLayout.none] is the
/// constructor default it cannot opt out — wrap it in
/// `NibLayoutDefaults(layout: NibLayout.none, …)` instead.
///
/// The value is read when a `NibMotion` is created and on each rebuild; it
/// does not subscribe, so changing it does not rebuild descendants.
class NibLayoutDefaults extends InheritedWidget {
  /// Creates a scope applying [layout] to descendants.
  const NibLayoutDefaults({
    super.key,
    required this.layout,
    required super.child,
  });

  /// The layout mode applied to descendants that do not set their own.
  final NibLayout layout;

  /// The nearest enclosing [NibLayoutDefaults], or `null`.
  static NibLayoutDefaults? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NibLayoutDefaults>();

  @override
  bool updateShouldNotify(NibLayoutDefaults oldWidget) =>
      layout != oldWidget.layout;
}
