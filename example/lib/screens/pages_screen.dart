import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

import 'demo_scaffold.dart';

/// Page/tab progress and viewport progress on a reversed list.
class PagesScreen extends StatefulWidget {
  /// Creates the screen.
  const PagesScreen({super.key});

  @override
  State<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends State<PagesScreen>
    with SingleTickerProviderStateMixin {
  static const _count = 4;
  final PageController _pages = PageController();
  late final NibPageProgress _pageProgress = NibPageProgress(_pages);
  late final TabController _tabs = TabController(length: _count, vsync: this);
  late final NibPageProgress _tabProgress = NibPageProgress.tab(_tabs);
  late final List<DerivedMotionValue<double, double>> _dotScales = [
    for (var i = 0; i < _count; i++)
      _pageProgress.page
          .transform<double>((p) => 1 + (1 - (p - i).abs()).clamp(0.0, 1.0)),
  ];

  @override
  void dispose() {
    for (final d in _dotScales) {
      d.dispose();
    }
    _pageProgress.dispose();
    _tabProgress.dispose();
    _tabs.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Page, tab and viewport progress',
      blurb: 'Swipe the pages: dots scale from NibPageProgress. Tap a tab: '
          'the underline follows NibPageProgress.tab. The reversed list reads '
          'NibViewportProgress in its own scroll direction.',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 120,
          child: PageView(controller: _pages, children: [
            for (var i = 0; i < _count; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.primaries[i * 3 % Colors.primaries.length],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Page $i',
                    style: const TextStyle(color: Colors.white, fontSize: 20)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _count; i++)
            Padding(
              padding: const EdgeInsets.all(6),
              child: NibMotion(
                motionValues: NibMotionValues(
                    scaleX: _dotScales[i], scaleY: _dotScales[i]),
                child: const DemoBox(size: 8, color: Colors.indigo),
              ),
            ),
        ]),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabs,
          labelColor: Colors.indigo,
          tabs: [for (var i = 0; i < _count; i++) Tab(text: 'Tab $i')],
        ),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / _count;
          return SizedBox(
            height: 4,
            child: Stack(children: [
              NibMotion(
                motionValues: NibMotionValues(
                  translateX: _tabProgress.page.mapRange(
                      [0, (_count - 1).toDouble()], [0, w * (_count - 1)]),
                ),
                child: Container(width: w, height: 4, color: Colors.orange),
              ),
            ]),
          );
        }),
        const SizedBox(height: 24),
        const Text('Reversed list (reverse: true)'),
        SizedBox(
          height: 240,
          child: ListView.builder(
            reverse: true,
            itemCount: 10,
            itemBuilder: (context, i) => _ReversedCard(index: i),
          ),
        ),
      ]),
    );
  }
}

class _ReversedCard extends StatefulWidget {
  const _ReversedCard({required this.index});

  final int index;

  @override
  State<_ReversedCard> createState() => _ReversedCardState();
}

class _ReversedCardState extends State<_ReversedCard> {
  final _controller = NibViewportProgressController();
  late final _opacity =
      _controller.progress.mapRange([0, 0.5, 1], [0.2, 1, 0.2]);

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibViewportProgress(
      controller: _controller,
      child: NibMotion(
        motionValues: NibMotionValues(opacity: _opacity),
        child: Container(
          height: 64,
          margin: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Card ${widget.index}',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
