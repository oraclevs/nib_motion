import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'flip_recorder.dart';

/// Animates [children] to their new positions whenever a rebuild changes
/// their layout, using the FLIP (First, Last, Invert, Play) technique.
///
/// Each widget in [children] must carry a non-null, unique [Key], which
/// identifies it across rebuilds so [NibLayoutGroup] can measure how far it
/// moved:
///
/// - **First:** before the new layout is applied, the current position of
///   every child present in both the old and new [children] is recorded.
/// - **Last:** after the new layout is applied (via
///   [WidgetsBinding.addPostFrameCallback]), each tracked child's new
///   position is compared against its recorded one.
/// - **Invert:** if a child moved, its [NibMotion] is immediately offset
///   (no animation) so it visually stays at its old position.
/// - **Play:** that offset is animated back to zero with [transition],
///   so the child appears to travel smoothly from its old position to its
///   new one.
///
/// A child whose key is newly added to [children] mounts without a FLIP
/// animation. A child whose key is removed from [children] stops being
/// tracked; re-adding it later is treated as a new child.
class NibLayoutGroup extends StatefulWidget {
  /// Creates a `NibLayoutGroup`.
  const NibLayoutGroup({super.key, required this.children, this.transition});

  /// The widgets to lay out and track. Each must carry a non-null, unique
  /// [Key].
  final List<Widget> children;

  /// The transition used to animate a moved child back to its new position.
  ///
  /// Defaults to [NibTransition.springGentle].
  final NibTransition? transition;

  @override
  State<NibLayoutGroup> createState() => _NibLayoutGroupState();
}

class _NibLayoutGroupState extends State<NibLayoutGroup> {
  final FlipRecorder _recorder = FlipRecorder();
  final Map<Key, GlobalKey> _globalKeys = <Key, GlobalKey>{};
  final Map<Key, NibMotionController> _controllers = <Key, NibMotionController>{};

  GlobalKey _globalKeyFor(Key key) => _globalKeys.putIfAbsent(key, GlobalKey.new);

  NibMotionController _controllerFor(Key key) => _controllers.putIfAbsent(key, NibMotionController.new);

  @override
  void didUpdateWidget(NibLayoutGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKeys = <Key>{for (final child in oldWidget.children) child.key!};
    final newKeys = <Key>{for (final child in widget.children) child.key!};

    final tracked = oldKeys.intersection(newKeys);
    for (final key in tracked) {
      _recorder.record(_globalKeyFor(key));
    }

    for (final key in oldKeys.difference(newKeys)) {
      final globalKey = _globalKeys.remove(key);
      if (globalKey != null) _recorder.forget(globalKey);
      _controllers.remove(key)?.dispose();
    }

    if (tracked.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in tracked) {
        final globalKey = _globalKeys[key];
        if (globalKey == null) continue;

        final delta = _recorder.computeDelta(globalKey);
        if (delta == null || delta == Offset.zero) continue;

        final controller = _controllerFor(key);
        controller.set(NibAnim(x: delta.dx, y: delta.dy));
        controller.start(target: const NibAnim(x: 0, y: 0), transition: widget.transition ?? NibTransition.springGentle);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final child in widget.children)
          NibMotion(
            key: _globalKeyFor(child.key!),
            controller: _controllerFor(child.key!),
            child: child,
          ),
      ],
    );
  }
}
