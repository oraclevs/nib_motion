import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// FLIP in Wrap/Row/Grid, size changes, shared layoutId and reordering.
class LayoutScreen extends StatefulWidget {
  /// Creates the screen.
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  List<int> _chips = [0, 1, 2, 3, 4, 5, 6];
  final Set<int> _wide = {};
  int? _open;
  final List<int> _order = [0, 1, 2, 3];

  Widget _chip(int id) => NibMotion(
        key: ValueKey('chip$id'),
        layout: NibLayout.both,
        layoutTransition: NibTransition.springGentle,
        child: GestureDetector(
          onTap: () => setState(
              () => _wide.contains(id) ? _wide.remove(id) : _wide.add(id)),
          child: DemoBox(
            size: _wide.contains(id) ? 120 : 56,
            color: Colors.primaries[id * 2 % Colors.primaries.length],
            label: '$id',
          ),
        ),
      );

  Widget _card(int id, {required bool expanded}) => NibMotion(
        key: ValueKey('card$id-$expanded'),
        layoutId: 'card$id',
        layout: NibLayout.both,
        layoutTransition: NibSpring.spatialDefault.transition,
        child: GestureDetector(
          onTap: () => setState(() => _open = expanded ? null : id),
          child: Container(
            width: expanded ? 300 : 80,
            height: expanded ? 160 : 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.primaries[id * 3 % Colors.primaries.length],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(expanded ? 'card $id (tap to close)' : '$id',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Layout (FLIP)',
      blurb:
          'Every block below is a plain NibMotion(layout: …). Shuffle chips, '
          'tap to resize, open a shared card, long-press to reorder.',
      child: NibLayoutScope(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            FilledButton(
              onPressed: () => setState(() => _chips = [..._chips.reversed]),
              child: const Text('Reverse'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  setState(() => _chips = [..._chips.sublist(1), _chips.first]),
              child: const Text('Rotate'),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in _chips) _chip(id),
          ]),
          const SizedBox(height: 24),
          const Text('Shared layoutId (grid ↔ detail)'),
          const SizedBox(height: 8),
          if (_open == null)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < 4; i++) _card(i, expanded: false),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: _card(_open!, expanded: true),
            ),
          const SizedBox(height: 24),
          const Text('NibReorderable (long-press, drag)'),
          const SizedBox(height: 8),
          NibReorderable(
            onReorder: (from, to) => setState(() {
              final item = _order.removeAt(from);
              _order.insert(to, item);
            }),
            children: [
              for (final id in _order)
                Padding(
                  key: ValueKey('r$id'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.primaries[id * 4 % Colors.primaries.length],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Item $id',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
