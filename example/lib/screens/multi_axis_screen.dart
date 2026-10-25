import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Independent per-axis physics on Offset and Color.
class MultiAxisScreen extends StatefulWidget {
  /// Creates the screen.
  const MultiAxisScreen({super.key});

  @override
  State<MultiAxisScreen> createState() => _MultiAxisScreenState();
}

class _MultiAxisScreenState extends State<MultiAxisScreen>
    with SingleTickerProviderStateMixin {
  final MotionValue<Offset> _pos = MotionValue<Offset>(const Offset(40, 40));
  late final MultiSpringSolver<Offset> _solver = MultiSpringSolver<Offset>(
    vsync: this,
    value: _pos,
    converter: MotionConverter.offset,
    spring: NibSpring.bouncy,
  );
  Color _color = Colors.indigo;

  @override
  void dispose() {
    _solver.dispose();
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Multi-axis values',
      blurb: 'Tap the pad: x and y are separate springs that each keep their '
          'own velocity when you retarget. The swatch is a NibValueBuilder<Color>.',
      child: Column(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _solver.animateTo(d.localPosition - const Offset(28, 28)),
            child: Container(
              color: Colors.indigo.withAlpha(20),
              child: ValueListenableBuilder<Offset>(
                valueListenable: _pos,
                builder: (context, p, _) => Stack(children: [
                  Positioned(left: p.dx, top: p.dy, child: const DemoBox()),
                  Positioned(
                    right: 8,
                    top: 8,
                    child:
                        Text('vx ${_solver.velocities[0].toStringAsFixed(0)}  '
                            'vy ${_solver.velocities[1].toStringAsFixed(0)}'),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            NibValueBuilder<Color>(
              target: _color,
              spring: NibSpring.effectsDefault,
              builder: (context, c) => Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 16),
            for (final c in [
              Colors.indigo,
              Colors.orange,
              Colors.teal,
              Colors.pink
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c),
                  onPressed: () => setState(() => _color = c),
                  child: const SizedBox.shrink(),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
