import 'package:flutter/widgets.dart';

import '../core/nib_motion_values.dart';
import '../core/nib_motion_widget.dart';
import '../values/derived_motion_value.dart';
import '../values/motion_value.dart';
import 'scroll_motion_bridge.dart';

/// Moves [child] at a different rate than the surrounding scroll view,
/// creating a depth/parallax effect.
///
/// `NibParallax` creates its own [ScrollMotionBridge] for [scrollController]
/// and derives a translate offset from the live scroll position via
/// [MotionValue.transform] — `offset = scrollOffset * factor`. That derived
/// [MotionValue] is fed straight into a [NibMotion] via
/// [NibMotion.motionValues], so [child] repaints with the new offset on every
/// scroll tick with no `setState` and no widget rebuild.
///
/// [factor] controls the parallax strength: `0` pins [child] in place
/// (ignores scrolling entirely), `1` makes it scroll at the same rate as the
/// surrounding content (no visible parallax), and values in between (or
/// negative, or greater than `1`) produce a slower/faster/reversed depth
/// effect relative to the scroll.
///
/// ```dart
/// NibParallax(
///   scrollController: myScrollController,
///   factor: 0.5,
///   child: const Image(image: AssetImage('background.png')),
/// )
/// ```
///
/// [scrollController] must be attached to an ancestor (or otherwise
/// reachable) scrollable for its offset to drive anything — `NibParallax`
/// only reads [scrollController]'s offset, it does not need to be placed
/// inside the scroll view it tracks.
class NibParallax extends StatefulWidget {
  /// Creates a `NibParallax`.
  const NibParallax({
    super.key,
    required this.child,
    required this.scrollController,
    this.factor = 0.5,
    this.axis = Axis.vertical,
  });

  /// The widget to apply the parallax offset to.
  final Widget child;

  /// The scroll controller whose offset drives the parallax effect.
  final ScrollController scrollController;

  /// The parallax strength. `0` keeps [child] stationary; `1` scrolls it at
  /// the same rate as the tracked scroll view (no visible parallax effect).
  final double factor;

  /// Which axis of [scrollController]'s offset to translate [child] along.
  ///
  /// [Axis.vertical] (the default) translates [child] vertically using
  /// [ScrollMotionBridge.scrollY]; [Axis.horizontal] translates it
  /// horizontally using [ScrollMotionBridge.scrollX].
  final Axis axis;

  @override
  State<NibParallax> createState() => _NibParallaxState();
}

class _NibParallaxState extends State<NibParallax> {
  late ScrollMotionBridge _bridge;
  late DerivedMotionValue<double, double> _offset;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _bridge = ScrollMotionBridge(controller: widget.scrollController);
    final source =
        widget.axis == Axis.horizontal ? _bridge.scrollX : _bridge.scrollY;
    _offset = source.transform((value) => value * widget.factor);
  }

  void _detach() {
    _offset.dispose();
    _bridge.dispose();
  }

  @override
  void didUpdateWidget(NibParallax oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.axis != widget.axis) {
      _detach();
      _attach();
    } else if (oldWidget.factor != widget.factor) {
      // Re-derive with the new factor; the old derived value is replaced
      // wholesale since `DerivedMotionValue`'s mapper is immutable.
      final source =
          widget.axis == Axis.horizontal ? _bridge.scrollX : _bridge.scrollY;
      _offset.dispose();
      _offset = source.transform((value) => value * widget.factor);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    return NibMotion(
      motionValues: NibMotionValues(
        translateX: isHorizontal ? _offset : null,
        translateY: isHorizontal ? null : _offset,
      ),
      child: widget.child,
    );
  }
}
