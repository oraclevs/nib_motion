import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// A responsive path shared by a moving marker and a stroke reveal.
class ShowcasePathsScreen extends StatefulWidget {
  /// Creates the path showcase.
  const ShowcasePathsScreen({super.key});

  @override
  State<ShowcasePathsScreen> createState() => _ShowcasePathsScreenState();
}

class _ShowcasePathsScreenState extends State<ShowcasePathsScreen> {
  final _motion = NibPathMotionController();
  final _drawing = NibDrawPathController();
  bool _paused = false;

  @override
  void dispose() {
    _motion.dispose();
    _drawing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduced = NibMotionConfig.watchReducedMotion(context);
    return DemoScaffold(
      title: 'Follow a path',
      blurb: 'Replay the journey, or pause it halfway. The marker follows the '
          'curve while the stroke draws the same route.',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SizedBox(
                    height: 300,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final end = constraints.maxWidth - 44;
                      final path = Path()
                        ..moveTo(20, 220)
                        ..cubicTo(end * 0.15, 10, end * 0.7, 280, end, 60);
                      return Stack(children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RouteGuide(path, colors.outlineVariant),
                          ),
                        ),
                        Positioned.fill(
                          child: NibDrawPath(
                            controller: _drawing,
                            path: path,
                            color: colors.primary,
                            strokeWidth: 4,
                            duration: const Duration(seconds: 3),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                        NibPathMotion(
                          controller: _motion,
                          path: path,
                          duration: const Duration(seconds: 3),
                          curve: Curves.easeInOutCubic,
                          rotate: true,
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 30, color: colors.primary),
                        ),
                        const Positioned(
                            left: 8, bottom: 32, child: Text('START')),
                        const Positioned(
                            right: 8, top: 24, child: Text('ARRIVE')),
                      ]);
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: () {
                      _motion.restart();
                      _drawing.restart();
                      setState(() => _paused = false);
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay path'),
                  ),
                  OutlinedButton.icon(
                    onPressed: reduced || _paused
                        ? null
                        : () {
                            _motion.pause();
                            _drawing.pause();
                            setState(() => _paused = true);
                          },
                    icon: const Icon(Icons.pause),
                    label: Text(_paused ? 'Path paused' : 'Pause path'),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(reduced
                    ? 'Reduced motion: the complete route and arrival state '
                        'are shown immediately.'
                    : 'One path, two effects: NibPathMotion moves a widget; '
                        'NibDrawPath reveals its stroke. Both use the same '
                        'three-second curve here.'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _RouteGuide extends CustomPainter {
  const _RouteGuide(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RouteGuide oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}
