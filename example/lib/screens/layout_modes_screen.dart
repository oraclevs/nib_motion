import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Size FLIP: scale vs clip, a delayed layout transition, and boundaries.
class LayoutModesScreen extends StatefulWidget {
  /// Creates the screen.
  const LayoutModesScreen({super.key});

  @override
  State<LayoutModesScreen> createState() => _LayoutModesScreenState();
}

class _LayoutModesScreenState extends State<LayoutModesScreen> {
  bool _big = false;
  bool _delay = false;
  List<int> _order = [0, 1, 2, 3, 4, 5];

  Widget _panel(NibLayoutSizeMode mode, String label) {
    return NibMotion(
      layout: NibLayout.size,
      layoutSizeMode: mode,
      layoutTransition: NibTransition(
        spring: NibSpring.spatialDefault,
        delay: _delay ? const Duration(milliseconds: 600) : Duration.zero,
      ),
      child: Container(
        width: _big ? 150 : 90,
        height: _big ? 120 : 70,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.indigo.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo),
        ),
        child: Text(
            '$label\nText stays crisp in clip mode, stretches in scale.',
            style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _chip(int id) => RepaintBoundary(
        key: ValueKey('rb$id'),
        child: NibMotion(
          key: ValueKey('chip$id'),
          layout: NibLayout.position,
          layoutTransition: NibSpring.spatialDefault.transition,
          child: DemoBox(
            size: 48,
            color: Colors.primaries[id * 2 % Colors.primaries.length],
            label: '$id',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Layout size modes',
      blurb: 'Toggle size: scale (left) stretches its content, clip (right) '
          'keeps it undistorted while the box grows. Delay holds the old look '
          'before playing. Below: layout inside RepaintBoundaries.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: () => setState(() => _big = !_big),
              child: const Text('Toggle size')),
          FilterChip(
            label: const Text('600 ms delay'),
            selected: _delay,
            onSelected: (v) => setState(() => _delay = v),
          ),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _panel(NibLayoutSizeMode.scale, 'scale'),
          const SizedBox(width: 24),
          _panel(NibLayoutSizeMode.clip, 'clip'),
        ]),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () =>
              setState(() => _order = List<int>.of(_order.reversed)),
          child: const Text('Reverse (RepaintBoundary children)'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final id in _order) _chip(id),
        ]),
        const SizedBox(height: 8),
        const Text('A boundary can move a child without repainting it; the '
            'frame hook catches that one frame late.'),
      ]),
    );
  }
}
