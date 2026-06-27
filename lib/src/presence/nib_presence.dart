import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/nib_motion_animator.dart';
import 'presence_entry.dart';
import 'presence_scope.dart';

/// Orchestrates exit animations for a dynamic list of children.
///
/// Each child must carry a non-null, unique [Key]. When a child is removed
/// from [children], `NibPresence` keeps it mounted (wrapped in an
/// [IgnorePointer]) until its `NibMotion.exit` animation finishes via
/// `NibMotionAnimator.triggerExit`, then removes it from the tree. Children
/// added to [children] mount normally and play their own enter animation.
class NibPresence extends StatefulWidget {
  /// Creates a `NibPresence` that manages exit animations for [children].
  const NibPresence({super.key, required this.children});

  /// The widgets to display. Each must have a non-null, unique [Key].
  final List<Widget> children;

  @override
  State<NibPresence> createState() => _NibPresenceState();
}

class _NibPresenceState extends State<NibPresence> {
  final Map<Key, NibPresenceEntry> _entries = <Key, NibPresenceEntry>{};
  final Map<Key, NibMotionAnimator> _registry = <Key, NibMotionAnimator>{};

  late final NibPresenceRegistration _registration = NibPresenceRegistration(
    register: (key, animator) => _registry[key] = animator,
    unregister: (key) => _registry.remove(key),
  );

  @override
  void initState() {
    super.initState();
    for (final child in widget.children) {
      final key = child.key!;
      _entries[key] = NibPresenceEntry(key: key, child: child);
    }
  }

  @override
  void didUpdateWidget(NibPresence oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newChildren = <Key, Widget>{
      for (final child in widget.children) child.key!: child
    };
    final newKeys = newChildren.keys.toSet();
    final oldKeys = _entries.keys.toSet();

    for (final key in newKeys.intersection(oldKeys)) {
      final entry = _entries[key]!;
      entry.child = newChildren[key]!;
      entry.isExiting = false;
    }

    for (final key in newKeys.difference(oldKeys)) {
      _entries[key] = NibPresenceEntry(key: key, child: newChildren[key]!);
    }

    for (final key in oldKeys.difference(newKeys)) {
      _beginExit(key);
    }
  }

  void _beginExit(Key key) {
    final entry = _entries[key];
    if (entry == null) return;

    final animator = _registry[key];
    if (animator == null) {
      _entries.remove(key);
      return;
    }

    entry.isExiting = true;
    final completer = Completer<void>();
    entry.exitCompleter = completer;

    animator.triggerExit().then((_) {
      completer.complete();
      if (!mounted) return;
      final current = _entries[key];
      if (current == null ||
          !current.isExiting ||
          current.exitCompleter != completer) return;
      setState(() => _entries.remove(key));
    });
  }

  @override
  Widget build(BuildContext context) {
    return NibPresenceScope(
      registration: _registration,
      child: Stack(
        children: _entries.values
            .map((entry) => IgnorePointer(
                key: ValueKey<Key>(entry.key),
                ignoring: entry.isExiting,
                child: entry.child))
            .toList(growable: false),
      ),
    );
  }
}
