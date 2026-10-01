import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// NibValueBuilder with a spring, a tween, and a static child.
class ValueBuilderScreen extends StatefulWidget {
  /// Creates the screen.
  const ValueBuilderScreen({super.key});

  @override
  State<ValueBuilderScreen> createState() => _ValueBuilderScreenState();
}

class _ValueBuilderScreenState extends State<ValueBuilderScreen> {
  bool _open = false;
  int _childBuilds = 0;

  @override
  Widget build(BuildContext context) {
    final target = _open ? const Offset(200, 0) : Offset.zero;
    return DemoScaffold(
      title: 'NibValueBuilder',
      blurb: 'Same target, two drivers: a spring (keeps velocity) and a '
          'tween (fixed duration + curve). withChild passes a static subtree '
          'through so it is not rebuilt each frame.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton(
            onPressed: () => setState(() => _open = !_open),
            child: const Text('Toggle target')),
        const SizedBox(height: 16),
        const Text('Spring'),
        SizedBox(
          height: 64,
          child: NibValueBuilder<Offset>(
            target: target,
            spring: NibSpring.bouncy,
            builder: (context, o) => Transform.translate(
                offset: o,
                child: const Align(
                    alignment: Alignment.centerLeft,
                    child: DemoBox(color: Colors.indigo))),
          ),
        ),
        const Text('Tween (900 ms easeInOutCubic)'),
        SizedBox(
          height: 64,
          child: NibValueBuilder<Offset>(
            target: target,
            transition: const NibTransition(
                duration: Duration(milliseconds: 900),
                curve: Curves.easeInOutCubic),
            builder: (context, o) => Transform.translate(
                offset: o,
                child: const Align(
                    alignment: Alignment.centerLeft,
                    child: DemoBox(color: Colors.teal))),
          ),
        ),
        const SizedBox(height: 8),
        const Text('withChild: static subtree'),
        NibValueBuilder<Offset>.withChild(
          target: target,
          spring: NibSpring.smooth,
          child: Builder(builder: (context) {
            _childBuilds++;
            return DemoBox(color: Colors.orange, label: 'b$_childBuilds');
          }),
          childBuilder: (context, o, child) =>
              Transform.translate(offset: o, child: child),
        ),
        const SizedBox(height: 8),
        const Text('The orange label is the child\'s build count: it stays '
            'put while the box moves (not one build per frame).'),
      ]),
    );
  }
}
