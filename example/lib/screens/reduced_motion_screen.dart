import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// One switch, one policy: NibMotionConfig(reducedMotion:) governs every widget.
class ReducedMotionScreen extends StatefulWidget {
  /// Creates the screen.
  const ReducedMotionScreen({super.key});

  @override
  State<ReducedMotionScreen> createState() => _ReducedMotionScreenState();
}

class _ReducedMotionScreenState extends State<ReducedMotionScreen> {
  bool _reduced = true;
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Reduced motion',
      blurb: 'Flip the switch: decorative and settling motion jumps to its end '
          'state, finger-following stays. Nothing here checks MediaQuery itself.',
      child: NibMotionConfig(
        reducedMotion: _reduced,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SwitchListTile(
            title: const Text('Reduce motion'),
            value: _reduced,
            onChanged: (v) => setState(() => _reduced = v),
          ),
          FilledButton(
            onPressed: () => setState(() => _on = !_on),
            child: const Text('Toggle state'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Align(
              alignment: Alignment.centerLeft,
              child: NibMotion(
                animate: NibAnim(x: _on ? 200 : 0, rotate: _on ? 0.5 : 0),
                transition: NibTransition.springWobbly,
                child: const DemoBox(),
              ),
            ),
          ),
          const Text('NibMotion(animate:) — jumps when reduced'),
          const SizedBox(height: 16),
          const NibTypewriter(
              'Typewriter text appears all at once when reduced.'),
          const SizedBox(height: 16),
          NibGradientText(
            'Gradient sweep freezes when reduced',
            gradient: const LinearGradient(
                colors: [Colors.indigo, Colors.pink, Colors.indigo]),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Draggable: follows your finger, snap-back jumps'),
          Container(
            height: 80,
            color: Colors.teal.withAlpha(20),
            alignment: Alignment.centerLeft,
            child: const NibDraggable(
              snapBack: true,
              child: DemoBox(color: Colors.teal),
            ),
          ),
        ]),
      ),
    );
  }
}
