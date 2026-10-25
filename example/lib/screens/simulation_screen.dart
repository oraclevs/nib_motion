import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// A ball dropped with GravitySimulation via NibSimulationDriver.
class SimulationScreen extends StatefulWidget {
  /// Creates the screen.
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  static const double _gravity = 2400;
  static const double _ball = 48;
  final MotionValue<double> _y = MotionValue<double>(0);
  late final NibSimulationDriver _driver =
      NibSimulationDriver(vsync: this, value: _y);
  double _floor = 300;
  int _bounces = 0;

  @override
  void dispose() {
    _driver.dispose();
    _y.dispose();
    super.dispose();
  }

  void _fall(double from, double velocity) {
    final impact =
        math.sqrt(velocity * velocity + 2 * _gravity * (_floor - from));
    _driver.run(GravitySimulation(_gravity, from, _floor, velocity)).then((_) {
      if (!mounted) return;
      final bounce = impact * 0.6;
      if (bounce < 80) {
        _y.value = _floor;
        return;
      }
      setState(() => _bounces++);
      _rise(bounce);
    });
  }

  void _rise(double speed) {
    // Upward leg is the same gravity with an initial negative velocity,
    // starting just above the floor so the simulation is not already done.
    _fall(_floor - 1, -speed);
  }

  void _drop() {
    _driver.stop();
    setState(() => _bounces = 0);
    _y.value = 0;
    _fall(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Custom Simulation',
      blurb: 'NibSimulationDriver runs any Flutter Simulation on a '
          'MotionValue. Here a GravitySimulation drops the ball; each impact '
          'restarts gravity upward at 60% speed.',
      child: LayoutBuilder(builder: (context, c) {
        _floor = c.maxHeight - _ball - 72;
        return Column(children: [
          Expanded(
            child: Container(
              color: Colors.indigo.withAlpha(16),
              alignment: Alignment.topCenter,
              child: NibMotion(
                motionValues: NibMotionValues(translateY: _y),
                child: const DemoBox(size: _ball, color: Colors.orange),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              FilledButton(onPressed: _drop, child: const Text('Drop')),
              const SizedBox(width: 16),
              Text('bounces: $_bounces'),
            ]),
          ),
        ]);
      }),
    );
  }
}
