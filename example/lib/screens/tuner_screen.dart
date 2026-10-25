import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// The live spring tuner.
class TunerScreen extends StatefulWidget {
  /// Creates the screen.
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  NibSpringDescription _spring = NibSpringDescription.gentle;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Spring tuner',
      blurb: 'Tune by duration/bounce or by mass/stiffness/damping; the plot '
          'is the real step response. Copy the snippet into your code.',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NibSpringTuner(
            onChanged: (s) => setState(() => _spring = s),
          ),
          const SizedBox(height: 16),
          Text('Current: mass ${_spring.mass.toStringAsFixed(2)}, '
              'stiffness ${_spring.stiffness.toStringAsFixed(1)}, '
              'damping ${_spring.damping.toStringAsFixed(1)}'),
        ],
      ),
    );
  }
}
