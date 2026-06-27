import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester, Key key) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  final renderObject = tester.element(find.byKey(key)).renderObject!;
  if (renderObject is RenderNibMotion) {
    return renderObject;
  }
  renderObject.visitChildren(visit);
  return found!;
}

void main() {
  group('NibTimeline', () {
    testWidgets('fires each entry at its `at` offset', (tester) async {
      final controllerA = NibMotionController();
      final controllerB = NibMotionController();
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      const keyA = ValueKey('a');
      const keyB = ValueKey('b');

      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NibMotion(
                key: keyA,
                initial: const NibAnim(opacity: 0.0),
                controller: controllerA,
                transition: const NibTransition(duration: Duration(milliseconds: 10)),
                child: const SizedBox(width: 20, height: 20),
              ),
              NibMotion(
                key: keyB,
                initial: const NibAnim(opacity: 0.0),
                controller: controllerB,
                transition: const NibTransition(duration: Duration(milliseconds: 10)),
                child: const SizedBox(width: 20, height: 20),
              ),
            ],
          ),
        ),
      );

      final renderA = _findRenderNibMotion(tester, keyA);
      final renderB = _findRenderNibMotion(tester, keyB);

      final timeline = NibTimeline([
        NibTimelineEntry(controller: controllerA, target: const NibAnim(opacity: 1.0), at: Duration.zero),
        NibTimelineEntry(
          controller: controllerB,
          target: const NibAnim(opacity: 1.0),
          at: const Duration(milliseconds: 100),
        ),
      ]);
      addTearDown(timeline.dispose);

      final done = timeline.play();

      // Entry A fires immediately (at: Duration.zero).
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 10));
      expect(renderA.opacity.value, closeTo(1.0, 0.01));
      // Entry B has not fired yet.
      expect(renderB.opacity.value, closeTo(0.0, 0.01));

      // Advance to just before entry B's offset.
      await tester.pump(const Duration(milliseconds: 80));
      expect(renderB.opacity.value, closeTo(0.0, 0.01));

      // Advance past entry B's offset and let its animation finish. The
      // entry's Timer fires mid-pump, so the tween it starts needs an extra
      // pump cycle beyond its nominal duration before it's actually ticked
      // to completion — pumpAndSettle rides that out reliably.
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(renderB.opacity.value, closeTo(1.0, 0.01));

      await done;
    });

    testWidgets('pause cancels pending entries before they fire', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const key = ValueKey('p');

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            key: key,
            initial: const NibAnim(opacity: 0.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 10)),
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester, key);

      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(opacity: 1.0),
          at: const Duration(milliseconds: 100),
        ),
      ]);
      addTearDown(timeline.dispose);

      timeline.play();

      // Pause before the entry's offset elapses.
      await tester.pump(const Duration(milliseconds: 50));
      timeline.pause();

      // Advance well past the original offset — the entry must not fire.
      await tester.pump(const Duration(milliseconds: 200));
      expect(render.opacity.value, closeTo(0.0, 0.01));
    });

    testWidgets('stop cancels pending entries before they fire', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const key = ValueKey('s');

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            key: key,
            initial: const NibAnim(opacity: 0.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 10)),
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester, key);

      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(opacity: 1.0),
          at: const Duration(milliseconds: 100),
        ),
      ]);
      addTearDown(timeline.dispose);

      timeline.play();

      await tester.pump(const Duration(milliseconds: 30));
      timeline.stop();

      await tester.pump(const Duration(milliseconds: 200));
      expect(render.opacity.value, closeTo(0.0, 0.01));
    });

    testWidgets('dispose cancels pending entries and prevents further play', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      const key = ValueKey('d');

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            key: key,
            initial: const NibAnim(opacity: 0.0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 10)),
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester, key);

      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(opacity: 1.0),
          at: const Duration(milliseconds: 100),
        ),
      ]);

      timeline.play();
      await tester.pump(const Duration(milliseconds: 30));
      timeline.dispose();

      await tester.pump(const Duration(milliseconds: 200));
      expect(render.opacity.value, closeTo(0.0, 0.01));
      expect(() => timeline.play(), throwsA(isA<AssertionError>()));
    });

    test('entries are sorted by `at`, regardless of constructor order', () {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      final late = NibTimelineEntry(
        controller: controller,
        target: const NibAnim(opacity: 1.0),
        at: const Duration(milliseconds: 200),
      );
      final early = NibTimelineEntry(controller: controller, target: const NibAnim(opacity: 0.0), at: Duration.zero);

      final timeline = NibTimeline([late, early]);

      expect(timeline.entries.first, same(early));
      expect(timeline.entries.last, same(late));
    });

    testWidgets('empty timeline play() completes immediately', (tester) async {
      final timeline = NibTimeline(const []);
      addTearDown(timeline.dispose);

      await expectLater(timeline.play(), completes);
    });
  });
}
