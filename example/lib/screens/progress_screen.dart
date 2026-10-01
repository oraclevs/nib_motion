import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Scroll-through progress drives paint-time properties, with no rebuilds.
class ProgressScreen extends StatelessWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Viewport progress',
      blurb: 'Each card reads NibViewportProgress (0 entering, 0.5 centred, '
          '1 leaving) and maps it to opacity, scale, rotation and parallax.',
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (context, i) => _ProgressCard(index: i),
      ),
    );
  }
}

class _ProgressCard extends StatefulWidget {
  const _ProgressCard({required this.index});

  final int index;

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  final _controller = NibViewportProgressController();
  late final _opacity =
      _controller.progress.mapRange([0, 0.5, 1], [0.15, 1, 0.15]);
  late final _scale = _controller.progress.mapRange([0, 0.5, 1], [0.8, 1, 0.8]);
  late final _rotate = _controller.progress.mapRange([0, 1], [-0.03, 0.03]);
  late final _y = _controller.progress.mapRange([0, 1], [60, -60]);

  @override
  void dispose() {
    _opacity.dispose();
    _scale.dispose();
    _rotate.dispose();
    _y.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibViewportProgress(
      controller: _controller,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: NibMotion(
          motionValues: NibMotionValues(
            opacity: _opacity,
            scaleX: _scale,
            scaleY: _scale,
            rotate: _rotate,
            translateY: _y,
          ),
          child: DemoBox(
            size: 160,
            color: Colors.primaries[widget.index * 2 % Colors.primaries.length],
            label: 'Card ${widget.index}',
          ),
        ),
      ),
    );
  }
}
