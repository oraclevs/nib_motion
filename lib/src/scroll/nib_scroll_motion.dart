import 'package:flutter/widgets.dart';

import 'scroll_motion_bridge.dart';

/// Creates a [ScrollMotionBridge] for [controller] and exposes it to
/// [builder], disposing it when this widget is removed.
///
/// ```dart
/// NibScrollMotion(
///   controller: myScrollController,
///   builder: (context, bridge) => NibMotion(
///     motionValues: NibMotionValues(
///       opacity: bridge.scrollY.mapRange([0, 200], [1.0, 0.0]),
///     ),
///     child: MyWidget(),
///   ),
/// )
/// ```
class NibScrollMotion extends StatefulWidget {
  /// Creates a `NibScrollMotion`.
  const NibScrollMotion({super.key, required this.controller, required this.builder});

  /// The scroll controller whose offset is mirrored into the
  /// [ScrollMotionBridge] passed to [builder].
  final ScrollController controller;

  /// Builds the subtree below this widget, given the [ScrollMotionBridge]
  /// created for [controller].
  final Widget Function(BuildContext context, ScrollMotionBridge bridge) builder;

  @override
  State<NibScrollMotion> createState() => _NibScrollMotionState();
}

class _NibScrollMotionState extends State<NibScrollMotion> {
  late ScrollMotionBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = ScrollMotionBridge(controller: widget.controller);
  }

  @override
  void didUpdateWidget(NibScrollMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _bridge.dispose();
      _bridge = ScrollMotionBridge(controller: widget.controller);
    }
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _bridge);
}
