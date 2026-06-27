import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_replay_scope.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_nav_transition.dart';
import 'nib_nav_transitions.dart';

/// One screen managed by a [NibScreenStack].
@immutable
class NibNavScreen {
  /// Creates a screen entry.
  const NibNavScreen({required this.child, this.keepAlive = true});

  /// The screen's content.
  final Widget child;

  /// Whether to keep this screen's widget (and its state) alive while it is
  /// inactive. When `false`, the screen's subtree is replaced with an empty
  /// placeholder once it finishes its exit transition, and rebuilt from
  /// [child] the next time it becomes active.
  final bool keepAlive;
}

/// Per-screen state tracked by [_NibScreenStackState].
class _NibScreenEntry {
  _NibScreenEntry({
    required this.index,
    required this.child,
    required this.isActive,
    required this.isOffstage,
  });

  final int index;
  Widget child;
  bool isActive;
  bool isTransitioning = false;
  bool isOffstage;
  final NibMotionReplaySignal replaySignal = NibMotionReplaySignal();
}

/// Manages [screens] as a stack of always-mounted widgets, animating the
/// outgoing and incoming screens simultaneously when [currentIndex] changes.
///
/// Unlike `IndexedStack` (which only shows/hides) or `Navigator` (which
/// pushes/pops routes), `NibScreenStack` keeps every screen in the widget
/// tree (subject to [NibNavScreen.keepAlive]) and plays an enter animation on
/// the incoming screen and an exit animation on the outgoing screen at the
/// same time, via [NibMotion]/[NibMotionController] — no `setState` occurs on
/// animation ticks, only when a transition starts or finishes.
class NibScreenStack extends StatefulWidget {
  /// Creates a screen stack.
  const NibScreenStack({
    super.key,
    required this.screens,
    required this.currentIndex,
    this.screenTransition = const NibNavScreenTransition(),
  });

  /// The screens to manage, indexed the same as the corresponding nav items.
  final List<NibNavScreen> screens;

  /// The index of the currently active screen.
  final int currentIndex;

  /// The transition played between [screens] when [currentIndex] changes.
  final NibNavScreenTransition screenTransition;

  @override
  State<NibScreenStack> createState() => _NibScreenStackState();
}

class _NibScreenStackState extends State<NibScreenStack>
    with TickerProviderStateMixin {
  late List<_NibScreenEntry> _entries;
  late List<NibMotionController> _controllers;
  late int _currentIndex;
  bool _hasEntries = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _buildEntries();
  }

  void _buildEntries() {
    if (_hasEntries) {
      for (final entry in _entries) {
        entry.replaySignal.dispose();
      }
    }
    _entries = [
      for (var i = 0; i < widget.screens.length; i++)
        _NibScreenEntry(
          index: i,
          child: widget.screens[i].child,
          isActive: i == _currentIndex,
          isOffstage: i != _currentIndex,
        ),
    ];
    _controllers = [for (var _ in widget.screens) NibMotionController()];
    _hasEntries = true;
  }

  @override
  void didUpdateWidget(covariant NibScreenStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.screens.length != oldWidget.screens.length) {
      for (final controller in _controllers) {
        controller.dispose();
      }
      _currentIndex = widget.currentIndex.clamp(0, widget.screens.length - 1);
      _buildEntries();
      return;
    }

    for (final entry in _entries) {
      if (entry.isActive || widget.screens[entry.index].keepAlive) {
        entry.child = widget.screens[entry.index].child;
      }
    }

    if (widget.currentIndex != _currentIndex) {
      _startTransition(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final entry in _entries) {
      entry.replaySignal.dispose();
    }
    super.dispose();
  }

  void _startTransition(int newIndex) {
    final oldIndex = _currentIndex;
    final outgoing = _entries[oldIndex];
    final incoming = _entries[newIndex];

    if (widget.screenTransition.type == NibNavTransitionType.none) {
      setState(() {
        outgoing.isActive = false;
        outgoing.isOffstage = true;
        if (!widget.screens[oldIndex].keepAlive) {
          outgoing.child = const SizedBox.shrink();
        }
        incoming.isActive = true;
        incoming.isOffstage = false;
        if (!widget.screens[newIndex].keepAlive) {
          incoming.child = widget.screens[newIndex].child;
        }
      });
      _currentIndex = newIndex;
      if (widget.screenTransition.retriggerPageAnimations) {
        incoming.replaySignal
            .replay(delay: widget.screenTransition.retriggerDelay);
      }
      return;
    }

    final direction = newIndex > oldIndex ? 1 : -1;
    // `context.size` is unavailable here — `_startTransition` runs from
    // `didUpdateWidget`, during build, where reading the render object's size
    // throws. `MediaQuery.sizeOf` is always safe and close enough for slide
    // distances.
    final screenSize = MediaQuery.sizeOf(context);
    final (enterFrom, exitTo) = NibNavTransitions.resolve(
        widget.screenTransition.type, direction, screenSize);
    final transition = widget.screenTransition.tween ??
        NibTransition(spring: widget.screenTransition.spring);

    setState(() {
      if (!widget.screens[newIndex].keepAlive) {
        incoming.child = widget.screens[newIndex].child;
      }
      incoming.isActive = true;
      incoming.isOffstage = false;
      incoming.isTransitioning = true;
      outgoing.isActive = false;
      outgoing.isTransitioning = true;
    });
    _currentIndex = newIndex;

    _controllers[newIndex].set(enterFrom);
    _controllers[newIndex]
        .start(target: NibAnim.identity, transition: transition)
        .then((_) {
      if (!mounted) return;
      setState(() => incoming.isTransitioning = false);
      if (widget.screenTransition.retriggerPageAnimations) {
        incoming.replaySignal
            .replay(delay: widget.screenTransition.retriggerDelay);
      }
    });

    _controllers[oldIndex]
        .start(target: exitTo, transition: transition)
        .then((_) {
      if (!mounted) return;
      setState(() {
        outgoing.isTransitioning = false;
        outgoing.isOffstage = true;
        if (!widget.screens[oldIndex].keepAlive) {
          outgoing.child = const SizedBox.shrink();
        }
      });
      _controllers[oldIndex].set(NibAnim.identity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final entry in _entries)
          Offstage(
            offstage: entry.isOffstage,
            child: IgnorePointer(
              ignoring: !entry.isActive || entry.isTransitioning,
              child: NibMotionReplayScope(
                signal: entry.replaySignal,
                child: NibMotion(
                  key: ValueKey(entry.index),
                  controller: _controllers[entry.index],
                  child: entry.child,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
