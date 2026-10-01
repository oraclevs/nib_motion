import 'package:flutter/widgets.dart';

import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_layout.dart';
import 'nib_layout_scope.dart';

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
/// Each child is a `NibMotion(layout: NibLayout.position)` in
/// [NibLayoutChannelMode.translate] mode inside a [NibLayoutScope], so the
/// group is a thin `Column` over the same per-widget mechanism you get from
/// `NibMotion(layout:)` anywhere else; the FLIP is observable as each child's
/// own translation.
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
  final Map<Key, GlobalKey> _globalKeys = <Key, GlobalKey>{};

  /// Keys with a FLIP in flight. Each child's `NibMotion` reports the start and
  /// the settle of its own animation; a superseded animation is followed by its
  /// successor's start for the same key, so the set stays balanced.
  final Set<Key> _active = <Key>{};

  void _moveStarted(Key key) {
    final first = _active.isEmpty;
    _active.add(key);
    widget.onChildMove?.call(key);
    if (first) widget.onAnimationStart?.call();
  }

  void _moveEnded(Key key) {
    if (!_active.remove(key)) return;
    if (_active.isEmpty && mounted) widget.onAnimationComplete?.call();
  }

  GlobalKey _globalKeyFor(Key key) =>
      _globalKeys.putIfAbsent(key, GlobalKey.new);

  @override
  void didUpdateWidget(NibLayoutGroup oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKeys = <Key>{for (final child in oldWidget.children) child.key!};
    final newKeys = <Key>{for (final child in widget.children) child.key!};

    for (final key in oldKeys.difference(newKeys)) {
      _globalKeys.remove(key);
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
  }

  @override
  Widget build(BuildContext context) {
    final transition = widget.transition ?? NibTransition.springGentle;
    return NibLayoutScope(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in widget.children)
            NibMotion(
              key: _globalKeyFor(child.key!),
              layout: NibLayout.position,
              layoutChannelMode: NibLayoutChannelMode.translate,
              layoutTransition: transition,
              onLayoutAnimationStart: () => _moveStarted(child.key!),
              onLayoutAnimationComplete: () => _moveEnded(child.key!),
              child: child,
            ),
        ],
      ),
    );
  }
}
