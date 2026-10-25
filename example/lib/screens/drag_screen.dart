import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Drag with bounded inertia (elastic bounce) and snap points with projection.
class DragScreen extends StatefulWidget {
  /// Creates the screen.
  const DragScreen({super.key});

  @override
  State<DragScreen> createState() => _DragScreenState();
}

class _DragScreenState extends State<DragScreen> {
  bool _project = true;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Drag, inertia, snap',
      blurb: 'Fling the top box: it coasts and bounces off its bounds. '
          'Flick the bottom box: with projection it lands on the point it is '
          'heading to, not just the nearest one.',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Inertia release, constrained to ±120 px'),
          Container(
            height: 100,
            color: Colors.indigo.withAlpha(20),
            alignment: Alignment.center,
            child: const NibMotion(
              drag: NibDragConfig(
                axis: Axis.horizontal,
                constraints: Rect.fromLTRB(-120, 0, 120, 0),
                releaseMode: NibDragReleaseMode.inertia,
              ),
              child: DemoBox(),
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('snapProjection: 150 ms'),
            value: _project,
            onChanged: (v) => setState(() => _project = v),
          ),
          Container(
            height: 100,
            color: Colors.teal.withAlpha(20),
            alignment: Alignment.centerLeft,
            child: NibMotion(
              key: ValueKey(_project),
              drag: NibDragConfig(
                axis: Axis.horizontal,
                releaseMode: NibDragReleaseMode.stay,
                snapPoints: const [
                  Offset(0, 0),
                  Offset(120, 0),
                  Offset(240, 0)
                ],
                snapProjection: _project
                    ? const Duration(milliseconds: 150)
                    : Duration.zero,
              ),
              transition: NibTransition.springSnappy,
              child: const DemoBox(color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
