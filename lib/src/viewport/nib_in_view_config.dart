import 'package:flutter/widgets.dart';

/// Configures when [NibMotion.whileInView] triggers, based on how much of the
/// widget is visible within the screen.
@immutable
class NibInViewConfig {
  /// Creates a viewport configuration.
  const NibInViewConfig({this.amount = 0.5, this.once = false, this.margin = EdgeInsets.zero})
    : assert(amount >= 0.0 && amount <= 1.0, 'amount must be between 0.0 and 1.0.');

  /// The fraction of this widget's area that must be visible for it to be
  /// considered in view. `0.0` triggers as soon as any part is visible;
  /// `1.0` requires the whole widget to be visible.
  final double amount;

  /// If `true`, [NibMotion.whileInView] plays only the first time this widget
  /// enters the viewport, and it won't revert when it leaves.
  final bool once;

  /// Expands (positive) or shrinks (negative) the viewport bounds used for
  /// the visibility check, per edge.
  final EdgeInsets margin;
}
