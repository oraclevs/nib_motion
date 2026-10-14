import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// NibHotReloadReplay: edit and hot reload to see entrances replay.
class HotReloadScreen extends StatelessWidget {
  /// Creates the screen.
  const HotReloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Hot reload replay',
      blurb: 'Debug only. Wrap a screen in NibHotReloadReplay, then edit '
          'initial/animate/transition in this file and hot reload: every '
          'NibMotion below replays its entrance so the change is visible.',
      child: NibHotReloadReplay(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (var i = 0; i < 4; i++)
            NibMotion(
              initial: const NibAnim(opacity: 0, x: -48),
              animate: const NibAnim(opacity: 1, x: 0),
              transition: NibTransition(
                  spring: NibSpring.spatialDefault,
                  delay: Duration(milliseconds: 80 * i)),
              child: Card(
                child: ListTile(
                  title: Text('Card $i'),
                  subtitle: const Text('Try changing x: -48 to y: 48'),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
