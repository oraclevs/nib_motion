import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_animator.dart';
import '../core/nib_transition.dart';
import '../layout/nib_layout.dart';
import '../layout/nib_layout_defaults.dart';
import '../layout/nib_layout_scope.dart';
import 'presence_entry.dart';
import 'presence_scope.dart';

/// The container [NibPresence.layout] lays its children out in.
enum NibPresenceAxis {
  /// A vertical [Column].
  column,

  /// A horizontal [Row].
  row,

  /// A [Wrap] (runs flow to the next line).
  wrap,
}

/// How an exiting `NibPresence` child takes part in layout.
enum NibExitLayout {
  /// The child stays in the layout, taking its space, until its exit finishes
  /// (default).
  sync,

  /// The child leaves the layout immediately and is overlaid at its last
  /// rectangle while it fades out, so its siblings reflow right away. Pair the
  /// siblings with `NibMotion.layout` to animate that reflow.
  pop,
}

/// Which end of the list a stagger starts from.
enum NibStaggerFrom {
  /// The first child goes first.
  first,

  /// The last child goes first.
  last,

  /// The middle child goes first, spreading outwards.
  center,
}

/// Builds the layout of the (non-overlaid) presence children.
typedef NibPresenceLayoutBuilder = Widget Function(
    BuildContext context, List<Widget> children);

/// Orchestrates exit animations for a dynamic list of children.
///
/// Each child must carry a non-null, unique [Key]. When a child is removed
/// from [children], `NibPresence` keeps it mounted (ignoring pointers,
/// semantics and focus) until its `NibMotion.exit` animation finishes via
/// `NibMotionAnimator.triggerExit`, then removes it from the tree. Children
/// added to [children] mount normally and play their own enter animation. A
/// child re-added while exiting animates back to its resting state.
///
/// By default children are stacked. Pass [layoutBuilder] to lay them out as a
/// `Column`, `Wrap`, grid, …; with `exitLayout: NibExitLayout.pop` exiting
/// children stop occupying space at once. [stagger] delays each child of a
/// batch by its index (entrances and exits), starting from [staggerFrom].
class NibPresence extends StatefulWidget {
  /// Creates a `NibPresence` that manages exit animations for [children].
  const NibPresence({
    super.key,
    required this.children,
    this.exit,
    this.exitTransition,
    this.layoutBuilder,
    this.exitLayout = NibExitLayout.sync,
    this.stagger = Duration.zero,
    this.staggerFrom = NibStaggerFrom.first,
    this.onChildEnter,
    this.onChildExit,
    this.onChildMove,
    this.onAnimationStart,
    this.onAnimationComplete,
  }) : assert(exitTransition == null || exit != null,
            'exitTransition requires a container exit target.');

  /// The widgets to display. Each must have a non-null, unique [Key].
  final List<Widget> children;

  /// Overrides each child's exit target when it is removed.
  final NibAnim? exit;

  /// Overrides each child's exit transition when [exit] is supplied.
  final NibTransition? exitTransition;

  /// Lays out the children. Defaults to a `Stack`.
  final NibPresenceLayoutBuilder? layoutBuilder;

  /// Whether exiting children keep their space ([NibExitLayout.sync]) or leave
  /// the layout immediately ([NibExitLayout.pop]).
  final NibExitLayout exitLayout;

  /// Delay between consecutive children of the same batch, for both entrances
  /// and exits. [Duration.zero] disables staggering.
  final Duration stagger;

  /// Which child a stagger starts from.
  final NibStaggerFrom staggerFrom;

  /// Called (after the frame) for each child added after the first build.
  final ValueChanged<Key>? onChildEnter;

  /// Called for each removed child once it has left the tree: after its exit
  /// animation finished, or right away if it has none.
  final ValueChanged<Key>? onChildExit;

  /// Called when a layout animation (`NibMotion.layout`) starts for a child —
  /// typically a sibling reflowing because another child entered or left.
  final ValueChanged<Key>? onChildMove;

  /// Called when the first animation of a batch starts: an exit or a child's
  /// layout move. Enter animations belong to the children and are not
  /// tracked.
  final VoidCallback? onAnimationStart;

  /// Called when every exit and layout move started since
  /// [onAnimationStart] has finished (or was superseded).
  final VoidCallback? onAnimationComplete;

  /// A `NibPresence` whose children reflow with FLIP when one enters or
  /// leaves — the common case wired up in one call.
  ///
  /// It lays [children] out in a [Column], [Row] or [Wrap] ([axis]), wraps
  /// them in a `NibLayoutScope`, and applies [childLayout] (default
  /// [NibLayout.position]) to every child `NibMotion` that leaves its own
  /// `layout` at [NibLayout.none] via `NibLayoutDefaults`. [exitLayout]
  /// defaults to [NibExitLayout.pop], so siblings start closing the gap
  /// immediately while the leaver fades out in place.
  ///
  /// [spacing] and [runSpacing] apply to [NibPresenceAxis.wrap] only; for a
  /// column or row pad the children.
  factory NibPresence.layout({
    Key? key,
    required List<Widget> children,
    NibAnim? exit,
    NibTransition? exitTransition,
    NibPresenceAxis axis = NibPresenceAxis.column,
    NibLayout childLayout = NibLayout.position,
    NibExitLayout exitLayout = NibExitLayout.pop,
    double spacing = 0.0,
    double runSpacing = 0.0,
    Duration stagger = Duration.zero,
    NibStaggerFrom staggerFrom = NibStaggerFrom.first,
    ValueChanged<Key>? onChildEnter,
    ValueChanged<Key>? onChildExit,
    ValueChanged<Key>? onChildMove,
    VoidCallback? onAnimationStart,
    VoidCallback? onAnimationComplete,
  }) {
    return NibPresence(
      key: key,
      exit: exit,
      exitTransition: exitTransition,
      exitLayout: exitLayout,
      stagger: stagger,
      staggerFrom: staggerFrom,
      onChildEnter: onChildEnter,
      onChildExit: onChildExit,
      onChildMove: onChildMove,
      onAnimationStart: onAnimationStart,
      onAnimationComplete: onAnimationComplete,
      layoutBuilder: (context, kids) {
        final Widget container;
        switch (axis) {
          case NibPresenceAxis.column:
            container = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kids,
            );
          case NibPresenceAxis.row:
            container = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kids,
            );
          case NibPresenceAxis.wrap:
            container = Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              children: kids,
            );
        }
        return NibLayoutScope(
          child: NibLayoutDefaults(layout: childLayout, child: container),
        );
      },
      children: children,
    );
  }

  @override
  State<NibPresence> createState() => _NibPresenceState();
}

class _NibPresenceState extends State<NibPresence> {
  final Map<Key, NibPresenceEntry> _entries = <Key, NibPresenceEntry>{};
  final Map<Key, ({Matrix4 transform, Size size})> _exitGeometry = {};
  final Map<Key, NibMotionAnimator> _registry = <Key, NibMotionAnimator>{};
  final Map<Key, Duration> _enterDelays = <Key, Duration>{};
  final Set<Key> _activeExits = <Key>{};
  final Set<Key> _activeMoves = <Key>{};
  bool _aggregateActive = false;

  Map<Key, Widget> _validatedChildren() {
    final children = <Key, Widget>{};
    for (final child in widget.children) {
      final key = child.key;
      if (key == null) {
        throw FlutterError('NibPresence children must each have a key.');
      }
      if (children.containsKey(key)) {
        throw FlutterError('NibPresence child keys must be unique: $key.');
      }
      children[key] = child;
    }
    return children;
  }

  late final NibPresenceRegistration _registration = NibPresenceRegistration(
    register: (key, animator) => _registry[key] = animator,
    unregister: (key) => _registry.remove(key),
    takeEnterDelay: _enterDelays.remove,
    layoutAnimation: _onLayoutAnimation,
  );

  /// Calls [callback] now, or after the frame when a frame is being built
  /// (so observers can safely `setState`). Never delays it when idle: a
  /// post-frame callback would wait for a frame that may never come.
  void _later(VoidCallback? callback) {
    if (callback == null) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      callback();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  void _onLayoutAnimation(Key key, bool started) {
    if (started) {
      _activeMoves.add(key);
      widget.onChildMove?.call(key);
    } else {
      _activeMoves.remove(key);
    }
    _updateAggregate();
  }

  void _updateAggregate() {
    final active = _activeExits.isNotEmpty || _activeMoves.isNotEmpty;
    if (active == _aggregateActive) return;
    _aggregateActive = active;
    _later(active ? widget.onAnimationStart : widget.onAnimationComplete);
  }

  @override
  void initState() {
    super.initState();
    for (final entry in _validatedChildren().entries) {
      final key = entry.key;
      final child = entry.value;
      _entries[key] = NibPresenceEntry(key: key, child: child);
    }
    _assignEnterDelays([for (final child in widget.children) child.key!]);
  }

  @override
  void didUpdateWidget(NibPresence oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newChildren = _validatedChildren();
    final newKeys = newChildren.keys.toSet();
    final oldKeys = _entries.keys.toSet();
    final oldOrder = _entries.keys.toList();

    for (final key in newKeys.intersection(oldKeys)) {
      final entry = _entries[key]!;
      entry.child = newChildren[key]!;
      if (entry.isExiting) {
        // Re-added while exiting: cancel the pending removal and animate the
        // child back to its resting state from wherever the exit had got to.
        entry.isExiting = false;
        entry.exitCompleter = null;
        entry.exitRect = null;
        _exitGeometry.remove(key);
        entry.exitTimer?.cancel();
        entry.exitTimer = null;
        _activeExits.remove(key);
        _updateAggregate();
        _registry[key]?.restoreFromExit();
      }
    }

    final added = newKeys.difference(oldKeys);
    for (final key in added) {
      _entries[key] = NibPresenceEntry(key: key, child: newChildren[key]!);
      final onEnter = widget.onChildEnter;
      if (onEnter != null) _later(() => onEnter(key));
    }
    _assignEnterDelays([
      for (final child in widget.children)
        if (added.contains(child.key)) child.key!
    ]);

    final removed = [
      for (final key in oldOrder)
        if (!newKeys.contains(key)) key
    ];
    for (var i = 0; i < removed.length; i++) {
      _beginExit(removed[i], _staggerDelay(i, removed.length));
    }

    _reorder(oldOrder, [for (final child in widget.children) child.key!]);
  }

  /// The delay of item [index] in a batch of [count].
  Duration _staggerDelay(int index, int count) {
    if (widget.stagger == Duration.zero || count <= 1) return Duration.zero;
    final rank = switch (widget.staggerFrom) {
      NibStaggerFrom.first => index,
      NibStaggerFrom.last => count - 1 - index,
      NibStaggerFrom.center => ((index - (count - 1) / 2).abs()).round(),
    };
    return widget.stagger * rank;
  }

  void _assignEnterDelays(List<Key> batch) {
    for (var i = 0; i < batch.length; i++) {
      final delay = _staggerDelay(i, batch.length);
      if (delay > Duration.zero) {
        _enterDelays[batch[i]] = delay;
      } else {
        _enterDelays.remove(batch[i]);
      }
    }
  }

  /// Rebuilds [_entries] in the order of [newOrder], slotting each exiting
  /// child in after the sibling that preceded it in [oldOrder] so it fades out
  /// where it was instead of jumping to the end.
  void _reorder(List<Key> oldOrder, List<Key> newOrder) {
    final result = List<Key>.of(newOrder);
    final present = newOrder.toSet();
    for (var i = 0; i < oldOrder.length; i++) {
      final key = oldOrder[i];
      if (present.contains(key) || !_entries.containsKey(key)) continue;
      var insertAt = 0;
      for (var j = i - 1; j >= 0; j--) {
        final at = result.indexOf(oldOrder[j]);
        if (at >= 0) {
          insertAt = at + 1;
          break;
        }
      }
      result.insert(insertAt, key);
    }
    final reordered = <Key, NibPresenceEntry>{
      for (final key in result) key: _entries[key]!,
    };
    _entries
      ..clear()
      ..addAll(reordered);
  }

  ({Matrix4 transform, Size size, Rect bounds})? _measure(
      NibPresenceEntry entry) {
    final space = context.findRenderObject();
    final box = entry.wrapperKey.currentContext?.findRenderObject();
    if (space is! RenderBox || box is! RenderBox) return null;
    if (!box.attached || !box.hasSize) return null;
    final transform = box.getTransformTo(space);
    final size = box.size;
    return (
      transform: transform,
      size: size,
      bounds: MatrixUtils.transformRect(transform, Offset.zero & size),
    );
  }

  void _beginExit(Key key, Duration delay) {
    final entry = _entries[key];
    if (entry == null) return;

    final animator = _registry[key];
    if (animator == null) {
      _entries.remove(key);
      final onExit = widget.onChildExit;
      if (onExit != null) _later(() => onExit(key));
      return;
    }

    entry.isExiting = true;
    _activeExits.add(key);
    _updateAggregate();
    if (widget.exitLayout == NibExitLayout.pop) {
      final geometry = _measure(entry);
      entry.exitRect = geometry?.bounds;
      if (geometry != null) {
        _exitGeometry[key] =
            (transform: geometry.transform, size: geometry.size);
      }
    }
    final completer = Completer<void>();
    entry.exitCompleter = completer;

    void start() {
      entry.exitTimer = null;
      final exit = widget.exit;
      (exit == null
              ? animator.triggerExit()
              : animator.animateTo(exit, transition: widget.exitTransition))
          .then((_) {
        completer.complete();
        if (!mounted) return;
        final current = _entries[key];
        if (current == null ||
            !current.isExiting ||
            current.exitCompleter != completer) {
          return;
        }
        _exitGeometry.remove(key);
        setState(() => _entries.remove(key));
        _activeExits.remove(key);
        _later(() => widget.onChildExit?.call(key));
        _updateAggregate();
      });
    }

    if (delay == Duration.zero) {
      start();
    } else {
      entry.exitTimer = Timer(delay, () {
        if (mounted && entry.exitCompleter == completer) start();
      });
    }
  }

  @override
  void dispose() {
    for (final entry in _entries.values) {
      entry.exitTimer?.cancel();
    }
    super.dispose();
  }

  Widget _popped(NibPresenceEntry entry) {
    final geometry = _exitGeometry[entry.key]!;
    return Positioned(
      left: 0,
      top: 0,
      width: geometry.size.width,
      height: geometry.size.height,
      child: Transform(
        transform: geometry.transform,
        child: NibPresenceExitOverlay(child: _wrap(entry)),
      ),
    );
  }

  Widget _wrap(NibPresenceEntry entry) {
    final exiting = entry.isExiting;
    return IgnorePointer(
      key: entry.wrapperKey,
      ignoring: exiting,
      child: ExcludeSemantics(
        excluding: exiting,
        child: ExcludeFocus(excluding: exiting, child: entry.child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pop = widget.exitLayout == NibExitLayout.pop;
    bool overlaid(NibPresenceEntry e) =>
        pop && e.isExiting && e.exitRect != null;

    final flow = <Widget>[
      for (final entry in _entries.values)
        if (!overlaid(entry)) _wrap(entry),
    ];
    final builder = widget.layoutBuilder;
    Widget content =
        builder != null ? builder(context, flow) : Stack(children: flow);

    if (pop) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          for (final entry in _entries.values)
            if (overlaid(entry)) _popped(entry),
        ],
      );
    }

    return NibPresenceScope(registration: _registration, child: content);
  }
}
