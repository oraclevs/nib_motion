import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

void main() => runApp(const MaterialApp(home: SpringDemo()));

class SpringDemo extends StatefulWidget {
  const SpringDemo({super.key});

  @override
  State<SpringDemo> createState() => _SpringDemoState();
}

class _SpringDemoState extends State<SpringDemo> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tap again while it moves')),
      body: Center(
        child: NibMotion(
          animate: NibAnim(
            y: selected ? -40 : 0,
            scale: selected ? 1.15 : 1,
            rotate: selected ? -0.08 : 0,
          ),
          transition: NibTransition.springWobbly,
          child: FilledButton(
            onPressed: () => setState(() => selected = !selected),
            child: Text(selected ? 'Tap to reset' : 'Tap to lift'),
          ),
        ),
      ),
    );
  }
}
