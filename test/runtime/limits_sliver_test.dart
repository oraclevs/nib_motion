import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('ValueListenableBuilder on the delegate progress is safe',
      (tester) async {
    final s = ScrollController();
    addTearDown(s.dispose);
    final seen = <double>[];
    final delegate = NibSliverHeaderDelegate(
      minExtent: 50,
      maxExtent: 250,
      builder: (context, progress) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, p, _) {
          seen.add(p);
          return SizedBox(
              height: 250, child: Text('p=${p.toStringAsFixed(2)}'));
        },
      ),
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: SizedBox(
          width: 400,
          height: 600,
          child: CustomScrollView(
            controller: s,
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: delegate),
              const SliverToBoxAdapter(child: SizedBox(height: 3000)),
            ],
          ),
        ),
      ),
    ));
    for (var i = 1; i <= 10; i++) {
      s.jumpTo(i * 20.0);
      await tester.pump();
    }
    expect(tester.takeException(), isNull,
        reason: 'notifying during layout must not reach setState');
    // A write during layout notifies right after that frame, so the builder
    // is at most one frame behind (0.9 was the previous jump's value).
    expect(seen.last, closeTo(0.9, 1e-9));
    await tester.pump();
    expect(seen.last, closeTo(1.0, 1e-9));
    expect(find.text('p=1.00'), findsOneWidget);
    // Lags at most one frame: after each jump + single pump the builder has
    // already seen that frame's progress.
    seen.clear();
    s.jumpTo(100);
    await tester.pump();
    await tester.pump();
    expect(seen, isNotEmpty);
    expect(seen.last, closeTo(0.5, 1e-9));
  });

  testWidgets('paint-only consumers still see the value synchronously',
      (tester) async {
    final s = ScrollController();
    addTearDown(s.dispose);
    late MotionValue<double> captured;
    final delegate = NibSliverHeaderDelegate(
      minExtent: 50,
      maxExtent: 250,
      builder: (context, progress) {
        captured = progress;
        return NibMotion(
          motionValues:
              NibMotionValues(opacity: progress.mapRange([0, 1], [1, 0])),
          child: const SizedBox(height: 250),
        );
      },
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: SizedBox(
          width: 400,
          height: 600,
          child: CustomScrollView(
            controller: s,
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: delegate),
              const SliverToBoxAdapter(child: SizedBox(height: 3000)),
            ],
          ),
        ),
      ),
    ));
    s.jumpTo(200);
    await tester.pump();
    expect(captured.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a listener outside the sliver (e.g. an app bar title) is safe',
      (tester) async {
    final s = ScrollController();
    addTearDown(s.dispose);
    final delegate = NibSliverHeaderDelegate(
      minExtent: 50,
      maxExtent: 250,
      builder: (context, progress) => const SizedBox(height: 250),
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 700)),
        child: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: delegate.progress,
              builder: (context, p, _) => Text('title ${p.toStringAsFixed(2)}'),
            ),
            SizedBox(
              width: 400,
              height: 500,
              child: CustomScrollView(
                controller: s,
                slivers: [
                  SliverPersistentHeader(pinned: true, delegate: delegate),
                  const SliverToBoxAdapter(child: SizedBox(height: 3000)),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    for (var i = 1; i <= 10; i++) {
      s.jumpTo(i * 20.0);
      await tester.pump();
    }
    expect(tester.takeException(), isNull,
        reason: 'notifying during layout must not dirty a widget elsewhere');
    await tester.pump();
    expect(find.text('title 1.00'), findsOneWidget);
  });
}
