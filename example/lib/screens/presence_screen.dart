import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Presence: exits, re-entry mid-exit, stagger, and pop layout.
class PresenceScreen extends StatefulWidget {
  /// Creates the screen.
  const PresenceScreen({super.key});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  final Set<int> _shown = {0, 1, 2, 3, 4};
  bool _pop = true;
  bool _stagger = true;

  Widget _item(int id) => NibMotion(
        key: ValueKey(id),
        layout: NibLayout.position,
        initial: const NibAnim(opacity: 0, scale: 0.6),
        animate: const NibAnim(opacity: 1, scale: 1),
        exit: const NibAnim(opacity: 0, scale: 0.6),
        transition: NibSpring.spatialDefault.transition,
        child: GestureDetector(
          onTap: () => setState(() => _shown.remove(id)),
          child: DemoBox(
            size: 64,
            color: Colors.primaries[id % Colors.primaries.length],
            label: '$id',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ids = _shown.toList()..sort();
    return DemoScaffold(
      title: 'Presence',
      blurb: 'Tap a box to remove it; re-add it while it fades to see it '
          'animate back. "Pop" lets siblings reflow immediately.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          FilterChip(
            label: const Text('exitLayout: pop'),
            selected: _pop,
            onSelected: (v) => setState(() => _pop = v),
          ),
          FilterChip(
            label: const Text('stagger 60ms'),
            selected: _stagger,
            onSelected: (v) => setState(() => _stagger = v),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < 8; i++)
            ActionChip(
              label: Text(_shown.contains(i) ? 'remove $i' : 'add $i'),
              onPressed: () => setState(
                  () => _shown.contains(i) ? _shown.remove(i) : _shown.add(i)),
            ),
        ]),
        const SizedBox(height: 16),
        NibLayoutScope(
          child: NibPresence(
            exitLayout: _pop ? NibExitLayout.pop : NibExitLayout.sync,
            stagger:
                _stagger ? const Duration(milliseconds: 60) : Duration.zero,
            layoutBuilder: (context, children) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
            children: [for (final id in ids) _item(id)],
          ),
        ),
      ]),
    );
  }
}
