import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// A collapsing header driven by sliver progress, plus a reflowing list.
class SliverScreen extends StatefulWidget {
  /// Creates the screen.
  const SliverScreen({super.key});

  @override
  State<SliverScreen> createState() => _SliverScreenState();
}

class _SliverScreenState extends State<SliverScreen> {
  final List<int> _items = List<int>.generate(8, (i) => i);
  int _next = 8;

  Widget _row(int id) => NibMotion(
        key: ValueKey('row$id'),
        layout: NibLayout.position,
        layoutTransition: NibSpring.spatialDefault.transition,
        initial: const NibAnim(opacity: 0, x: -24),
        animate: const NibAnim(opacity: 1, x: 0),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text('Item $id'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _items.remove(id)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Sliver header + list FLIP',
      blurb: 'Scroll: the header title scales, fades and blurs from its '
          'collapse progress (no rebuilds). Insert or remove rows; the rest '
          'glide into place inside the SliverList.',
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: NibSliverHeaderDelegate(
              minExtent: 72,
              maxExtent: 220,
              builder: (context, progress) => ColoredBox(
                color: Colors.indigo,
                child: Stack(fit: StackFit.expand, children: [
                  Align(
                    alignment: Alignment.center,
                    child: NibMotion(
                      motionValues: NibMotionValues(
                        opacity: progress.mapRange([0, 0.8, 1], [1, 1, 0.7]),
                        scaleX: progress.mapRange([0, 1], [1.6, 0.9]),
                        scaleY: progress.mapRange([0, 1], [1.6, 0.9]),
                        blur: progress.mapRange([0, 0.6, 1], [0, 0, 3]),
                      ),
                      child: const Text('Collapsing title',
                          style: TextStyle(color: Colors.white, fontSize: 22)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 8, children: [
                FilledButton(
                    onPressed: () => setState(() => _items.insert(0, _next++)),
                    child: const Text('Insert at top')),
                FilledButton(
                    onPressed: () => setState(() {
                          if (_items.isNotEmpty) _items.removeAt(0);
                        }),
                    child: const Text('Remove first')),
              ]),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              for (final id in _items) _row(id),
            ]),
          ),
        ],
      ),
    );
  }
}
