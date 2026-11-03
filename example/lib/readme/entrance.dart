import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

void main() => runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NibMotion(
              initial: const NibAnim(opacity: 0, y: 24),
              animate: const NibAnim(opacity: 1, y: 0),
              transition: NibTransition.springSnappy,
              child: const Text('Hello, NibMotion'),
            ),
          ),
        ),
      ),
    );
