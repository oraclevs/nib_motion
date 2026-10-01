import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// NibPresence.layout in column / row / wrap with pop exit.
class PresenceLayoutScreen extends StatefulWidget {
  /// Creates the screen.
  const PresenceLayoutScreen({super.key});

  @override
  State<PresenceLayoutScreen> createState() => _PresenceLayoutScreenState();
}

class _PresenceLayoutScreenState extends State<PresenceLayoutScreen> {
  NibPresenceAxis _axis = NibPresenceAxis.wrap;
  NibExitLayout _exit = NibExitLayout.pop;
  final List<int> _ids = [0, 1, 2, 3, 4];
  int _next = 5;

  Widget _item(int id) => NibMotion(
        key: ValueKey(id),
        initial: const NibAnim(opacity: 0, scale: 0.5),
        animate: const NibAnim(opacity: 1, scale: 1),
        exit: const NibAnim(opacity: 0, scale: 0.5),
        transition: NibSpring.spatialDefault.transition,
        child: GestureDetector(
          onTap: () => setState(() => _ids.remove(id)),
          child: DemoBox(
            size: 56,
            color: Colors.primaries[id % Colors.primaries.length],
            label: '$id',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'NibPresence.layout',
      blurb: 'One call wires the layout scope, pop exit and FLIP reflow. '
          'Tap a box to remove it; siblings close the gap immediately with '
          'pop, or after the exit with sync.',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in NibPresenceAxis.values)
              ChoiceChip(
                label: Text(a.name),
                selected: _axis == a,
                onSelected: (_) => setState(() => _axis = a),
              ),
            FilterChip(
              label: const Text('pop exit'),
              selected: _exit == NibExitLayout.pop,
              onSelected: (v) => setState(
                  () => _exit = v ? NibExitLayout.pop : NibExitLayout.sync),
            ),
            ActionChip(
              label: const Text('Add'),
              onPressed: () => setState(() =>
                  _ids.insert(_ids.isEmpty ? 0 : _ids.length ~/ 2, _next++)),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: NibPresence.layout(
                  key: ValueKey(_axis),
                  axis: _axis,
                  exitLayout: _exit,
                  spacing: 8,
                  runSpacing: 8,
                  stagger: const Duration(milliseconds: 40),
                  children: [for (final id in _ids) _item(id)],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
