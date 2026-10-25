import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';

/// Which changes of its own layout a `NibMotion` animates.
///
/// Set through `NibMotion.layout`. The widget is measured in the coordinate
/// space of the nearest `NibLayoutScope` (or the whole box-model subtree above
/// it, bounded by the nearest scrollable), so scrolling never counts as a
/// layout change.
enum NibLayout {
  /// Layout changes are not animated, even when an enclosing
  /// `NibLayoutDefaults` asks for them.
  none,

  /// Animate position changes (FLIP translation).
  position,

  /// Animate size changes (FLIP scale about the widget's centre, with the
  /// position held). The child is scaled, not re-laid out, so text and images
  /// stretch for the duration of the animation.
  size,

  /// Animate both position and size changes.
  both,

  /// Use the enclosing `NibLayoutDefaults` layout, or [none] when there is
  /// none (default). Being distinct from an explicit [none] lets a child opt
  /// out of an inherited default.
  inherit,
}

/// How a size change of a `NibMotion(layout: size | both)` is played.
enum NibLayoutSizeMode {
  /// FLIP scale about the centre (default): cheap, but the child (text,
  /// images) stretches for the duration of the animation.
  scale,

  /// The child is laid out at its *final* size and revealed through an
  /// interpolated clip anchored at its top-left: nothing is stretched. A
  /// shrinking widget simply shows its new (smaller) content at once, since
  /// the old pixels no longer exist — combine with a sibling `position` FLIP
  /// for the surrounding reflow.
  clip,
}

/// Where a layout FLIP's position offset is stored.
enum NibLayoutChannelMode {
  /// In dedicated layout channels, painted on top of the widget's own
  /// transform. The default: a widget can animate `x`/`y` and FLIP at once.
  channels,

  /// Directly in the widget's own `translateX`/`translateY` values. Used by
  /// `NibLayoutGroup`, whose children are laid out and moved only by layout, so
  /// the FLIP is observable as the widget's translation. The widget must not
  /// animate its own `x`/`y` in this mode (the FLIP owns them and rests at 0).
  translate,
}

/// The four scalar channels a layout FLIP animates back to identity.
///
/// They are separate from the widget's own `x`/`y`/`scale` animation values so
/// a layout animation composes with `animate:`, gestures and variants instead
/// of fighting them.
class NibLayoutChannels {
  /// Creates channels at rest (translation 0, scale 1).
  NibLayoutChannels()
      : x = MotionValue<double>(0),
        y = MotionValue<double>(0),
        scaleX = MotionValue<double>(1),
        scaleY = MotionValue<double>(1);

  /// Horizontal FLIP translation, in the parent's coordinate space.
  final MotionValue<double> x;

  /// Vertical FLIP translation, in the parent's coordinate space.
  final MotionValue<double> y;

  /// Horizontal FLIP scale about the centre.
  final MotionValue<double> scaleX;

  /// Vertical FLIP scale about the centre.
  final MotionValue<double> scaleY;

  /// All channels, for bulk operations.
  List<MotionValue<double>> get all => [x, y, scaleX, scaleY];

  /// Releases the channels.
  void dispose() {
    for (final channel in all) {
      channel.dispose();
    }
  }
}

/// The target transform a layout change produced, applied by the widget state.
@immutable
class NibLayoutFlip {
  /// Creates a flip result.
  const NibLayoutFlip({
    required this.x,
    required this.y,
    required this.scaleX,
    required this.scaleY,
  });

  /// New horizontal translation.
  final double x;

  /// New vertical translation.
  final double y;

  /// New horizontal scale.
  final double scaleX;

  /// New vertical scale.
  final double scaleY;
}
