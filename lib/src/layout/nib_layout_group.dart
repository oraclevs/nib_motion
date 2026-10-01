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
  const NibLayoutGroup({
    super.key,
    required this.children,
    this.transition,
    this.onChildEnter,
    this.onChildExit,
    this.onChildMove,
    this.onAnimationStart,
    this.onAnimationComplete,
  });

  /// The widgets to lay out and track. Each must carry a non-null, unique
  /// [Key].
  final List<Widget> children;

  /// The transition used to animate a moved child back to its new position.
  ///
  /// Defaults to [NibTransition.springGentle].
  final NibTransition? transition;

  /// Called (after the frame) for each child added after the first build.
  final ValueChanged<Key>? onChildEnter;

  /// Called (after the frame) for each child removed from [children]; a group
  /// child has no exit animation, it leaves at once.
  final ValueChanged<Key>? onChildExit;

  /// Called when a FLIP starts for a child that moved.
  final ValueChanged<Key>? onChildMove;

  /// Called when the first FLIP of a batch starts.
  final VoidCallback? onAnimationStart;

  /// Called when every FLIP started since [onAnimationStart] has finished (or
  /// was superseded by a newer one for the same child).
  final VoidCallback? onAnimationComplete;

  @override
  State<NibLayoutGroup> createState() => _NibLayoutGroupState();
}

class _NibLayoutGroupState extends State<NibLayoutGroup> {
  final FlipRecorder _recorder = FlipRecorder();
  final Map<Key, GlobalKey> _globalKeys = <Key, GlobalKey>{};
  final Map<Key, NibMotionController> _controllers =
      <Key, NibMotionController>{};

  /// Keys with a FLIP in flight, and a per-key generation so a superseded
  /// FLIP's completion cannot end its successor.
  final Set<Key> _active = <Key>{};
  final Map<Key, int> _generations = <Key, int>{};

  void _moveStarted(Key key) {
    final first = _active.isEmpty;
    _active.add(key);
    widget.onChildMove?.call(key);
    if (first) widget.onAnimationStart?.call();
  }

  void _moveEnded(Key key, int generation) {
    if (_generations[key] != generation || !_active.remove(key)) return;
    if (_active.isEmpty && mounted) widget.onAnimationComplete?.call();
  }

  GlobalKey _globalKeyFor(Key key) =>
      _globalKeys.putIfAbsent(key, GlobalKey.new);

  NibMotionController _controllerFor(Key key) =>
      _controllers.putIfAbsent(key, NibMotionController.new);

  @override
  void didUpdateWidget(NibLayoutGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKeys = <Key>{for (final child in oldWidget.children) child.key!};
    final newKeys = <Key>{for (final child in widget.children) child.key!};

    final tracked = oldKeys.intersection(newKeys);
    final space = context.findRenderObject();
    for (final key in tracked) {
      _recorder.record(_globalKeyFor(key), ancestor: space);
    }

    for (final key in oldKeys.difference(newKeys)) {
      final globalKey = _globalKeys.remove(key);
      if (globalKey != null) _recorder.forget(globalKey);
      _controllers.remove(key)?.dispose();
      _generations.remove(key);
      final wasActive = _active.remove(key);
      final onExit = widget.onChildExit;
      if (onExit != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onExit(key);
        });
      }
      if (wasActive && _active.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onAnimationComplete?.call();
        });
      }
    }

    final onEnter = widget.onChildEnter;
    if (onEnter != null) {
      for (final key in newKeys.difference(oldKeys)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onEnter(key);
        });
      }
    }

    if (tracked.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in tracked) {
        final globalKey = _globalKeys[key];
        if (globalKey == null) continue;

        final delta = _recorder.computeDelta(globalKey,
            ancestor: context.findRenderObject());
        if (delta == null || delta == Offset.zero) continue;

        final controller = _controllerFor(key);
        controller.set(NibAnim(x: delta.dx, y: delta.dy), keepVelocity: true);
        final generation = (_generations[key] ?? 0) + 1;
        _generations[key] = generation;
        _moveStarted(key);
        controller
            .start(
                target: const NibAnim(x: 0, y: 0),
                transition: widget.transition ?? NibTransition.springGentle)
            .then((_) => _moveEnded(key, generation));
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
