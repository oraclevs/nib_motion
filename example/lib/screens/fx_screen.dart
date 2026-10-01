import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// 3D flip, blur, tint and spring token comparison.
class FxScreen extends StatefulWidget {
  /// Creates the screen.
  const FxScreen({super.key});

  @override
  State<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends State<FxScreen> {
  bool _flipped = false;
  bool _fx = false;
  bool _moved = false;

  static final _tokens = <String, NibTransition>{
    'spatialFast': NibSpring.spatialFast.transition,
    'spatialDefault': NibSpring.spatialDefault.transition,
    'spatialSlow': NibSpring.spatialSlow.transition,
    'effectsDefault': NibSpring.effectsDefault.transition,
    'bouncy': NibSpring.bouncy.transition,
    'snappy': NibSpring.snappy.transition,
  };

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Effects & tokens',
      blurb: 'rotateX/rotateY use perspective; blur and tint are paint-time '
          'layers. Below, the same move under each NibSpring token.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: () => setState(() => _flipped = !_flipped),
              child: const Text('Flip')),
          FilledButton(
              onPressed: () => setState(() => _fx = !_fx),
              child: const Text('Blur + tint')),
          FilledButton(
              onPressed: () => setState(() => _moved = !_moved),
              child: const Text('Move')),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          NibMotion(
            animate: NibAnim(rotateY: _flipped ? 0.5 : 0),
            transition: NibSpring.bouncy.transition,
            child: const DemoBox(size: 96, label: 'rotateY'),
          ),
          NibMotion(
            animate: NibAnim(rotateX: _flipped ? 0.25 : 0),
            transition: NibSpring.bouncy.transition,
            child:
                const DemoBox(size: 96, color: Colors.pink, label: 'rotateX'),
          ),
          NibMotion(
            animate: NibAnim(
              blur: _fx ? 6 : 0,
              tint: _fx ? const Color(0x88FF9800) : const Color(0x00FF9800),
            ),
            transition: NibSpring.effectsDefault.transition,
            child: const DemoBox(size: 96, color: Colors.teal, label: 'fx'),
          ),
        ]),
        const SizedBox(height: 32),
        for (final entry in _tokens.entries) ...[
          Text(entry.key),
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: NibMotion(
                animate: NibAnim(x: _moved ? 220 : 0),
                transition: entry.value,
                child: const DemoBox(size: 32),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
