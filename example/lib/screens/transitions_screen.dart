import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// reverseTransition, exitTransition, loopMode and spring keyframe segments.
class TransitionsScreen extends StatefulWidget {
  /// Creates the screen.
  const TransitionsScreen({super.key});

  @override
  State<TransitionsScreen> createState() => _TransitionsScreenState();
}

class _TransitionsScreenState extends State<TransitionsScreen> {
  bool _show = true;
  final NibMotionController _keys = NibMotionController();

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Directional transitions',
      blurb: 'The way back can differ from the way in: slow press, snappy '
          'release. Loops can restart instead of ping-pong. Keyframes can '
          'carry a spring per segment.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _label(
            'reverseTransition: press and hold (slow in), release (fast out)'),
        const NibMotion(
          whileTap: NibAnim(scale: 0.6),
          transition: NibTransition(duration: Duration(milliseconds: 900)),
          reverseTransition: NibTransition(
              duration: Duration(milliseconds: 120), curve: Curves.easeOut),
          child: DemoBox(size: 72, label: 'press'),
        ),
        _label('exitTransition: slow enter, fast exit'),
        Row(children: [
          FilledButton(
              onPressed: () => setState(() => _show = !_show),
              child: Text(_show ? 'Remove' : 'Add')),
          const SizedBox(width: 16),
          SizedBox(
            height: 72,
            width: 72,
            child: NibPresence(children: [
              if (_show)
                const NibMotion(
                  key: ValueKey('exit-demo'),
                  initial: NibAnim(opacity: 0, scale: 0.4),
                  animate: NibAnim(opacity: 1, scale: 1),
                  exit: NibAnim(opacity: 0, scale: 0.4),
                  transition:
                      NibTransition(duration: Duration(milliseconds: 1200)),
                  exitTransition:
                      NibTransition(duration: Duration(milliseconds: 150)),
                  child: DemoBox(size: 72, color: Colors.teal),
                ),
            ]),
          ),
        ]),
        _label('loopMode: pingPong (left) vs restart (right)'),
        SizedBox(
          height: 160,
          child: Row(children: const [
            Expanded(child: _Loop(mode: NibLoopMode.pingPong)),
            Expanded(child: _Loop(mode: NibLoopMode.restart)),
          ]),
        ),
        _label('Keyframes with a spring on the middle segment'),
        SizedBox(
          height: 80,
          child: NibMotion(
            controller: _keys,
            keyframes: [
              const NibKeyframe(at: 0, value: NibAnim(x: 0)),
              NibKeyframe(
                  at: 0.5,
                  value: const NibAnim(x: 200),
                  spring: NibSpring.bouncy),
              const NibKeyframe(at: 1, value: NibAnim(x: 0)),
            ],
            transition: const NibTransition(
                duration: Duration(milliseconds: 2400), curve: Curves.linear),
            child: const Align(
                alignment: Alignment.centerLeft,
                child: DemoBox(color: Colors.orange)),
          ),
        ),
        FilledButton(
            onPressed: () => _keys.start(), child: const Text('Replay')),
      ]),
    );
  }
}

class _Loop extends StatelessWidget {
  const _Loop({required this.mode});

  final NibLoopMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(mode.name),
      const SizedBox(height: 8),
      NibMotion(
        initial: const NibAnim(y: 0),
        animate: const NibAnim(y: 90),
        repeatAnimationInLoop: true,
        loopMode: mode,
        transition: const NibTransition(
            duration: Duration(milliseconds: 1000), curve: Curves.easeInOut),
        child: const DemoBox(size: 48),
      ),
    ]);
  }
}
