import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import '../recipes/retarget_card_recipe.dart';
import 'demo_scaffold.dart';

/// Tap the track to retarget a spring mid-flight; it keeps its momentum.
class InterruptionScreen extends StatefulWidget {
  /// Creates the screen.
  const InterruptionScreen({super.key});

  @override
  State<InterruptionScreen> createState() => _InterruptionScreenState();
}

class _InterruptionScreenState extends State<InterruptionScreen>
    with SingleTickerProviderStateMixin {
  final MotionValue<double> _x = MotionValue<double>(0);
  late final SpringSolver _solver = SpringSolver(
    vsync: this,
    value: _x,
    spring: NibSpringDescription.wobbly,
  );
  double _declarativeTarget = 0;

  @override
  void dispose() {
    _solver.dispose();
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Interruption',
      blurb: 'Tap either track while the box is moving. The new spring starts '
          'from the current position AND velocity (no restart from rest).',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('SpringSolver + MotionValue (live velocity)'),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final max = c.maxWidth - 56;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _solver.animateTo(
                  target: (d.localPosition.dx - 28).clamp(0.0, max)),
              child: SizedBox(
                height: 80,
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(color: Colors.indigo.withAlpha(20)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NibMotion(
                      motionValues: NibMotionValues(translateX: _x),
                      child: const DemoBox(),
                    ),
                  ),
                ]),
              ),
            );
          }),
          ValueListenableBuilder<double>(
            valueListenable: _x,
            builder: (context, x, _) =>
                Text('x = ${x.toStringAsFixed(1)}   velocity = '
                    '${_x.velocity.toStringAsFixed(0)} px/s'),
          ),
          const SizedBox(height: 32),
          const Text('Copyable spring retarget recipe'),
          const SizedBox(height: 8),
          const RetargetCardRecipe(),
          const SizedBox(height: 32),
          const Text('Declarative: NibMotion(animate: NibAnim(x: …))'),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final max = c.maxWidth - 56;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(() => _declarativeTarget =
                  (d.localPosition.dx - 28).clamp(0.0, max)),
              child: SizedBox(
                height: 80,
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(color: Colors.teal.withAlpha(20)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NibMotion(
                      animate: NibAnim(x: _declarativeTarget),
                      transition: NibTransition.springWobbly,
                      child: const DemoBox(color: Colors.teal),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
