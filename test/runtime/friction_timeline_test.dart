import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

const _linear1s =
    NibTransition(duration: Duration(milliseconds: 1000), curve: Curves.linear);

void main() {
  group('timeline derives `from` automatically', () {
    testWidgets('from the widget\'s initial state when omitted',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        initial: const NibAnim(x: -100, opacity: 0),
        child: const SizedBox(width: 10, height: 10),
      )));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(x: 0, opacity: 1),
          at: Duration.zero,
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      timeline.seek(0);
      expect(_render(tester).translateX.value, -100);
      expect(_render(tester).opacity.value, 0);
      timeline.seek(0.5);
      expect(_render(tester).translateX.value, closeTo(-50, 0.01));
      expect(_render(tester).opacity.value, closeTo(0.5, 0.01));
      timeline.seek(1);
      expect(_render(tester).translateX.value, 0);
      expect(_render(tester).opacity.value, 1);
    });

    testWidgets('a later entry starts from the previous entry\'s target',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(x: 100),
          at: Duration.zero,
          transition: _linear1s,
        ),
        NibTimelineEntry.after(
          controller: controller,
          target: const NibAnim(x: 0),
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      timeline.seek(0.75); // 1.5 s: halfway back down
      expect(_render(tester).translateX.value, closeTo(50, 0.01));
      timeline.seek(0.25); // 0.5 s: halfway up
      expect(_render(tester).translateX.value, closeTo(50, 0.01));
    });

    testWidgets('an explicit from still wins', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        initial: const NibAnim(x: -100),
        child: const SizedBox(width: 10, height: 10),
      )));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(x: 100),
          from: const NibAnim(x: 0),
          at: Duration.zero,
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      timeline.seek(0.5);
      expect(_render(tester).translateX.value, closeTo(50, 0.01));
    });

    testWidgets('properties missing from initial fall back to identity',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(scale: 2),
          at: Duration.zero,
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      timeline.seek(0.5);
      expect(_render(tester).scaleX.value, closeTo(1.5, 0.01));
    });
  });

  group('NibTimelineScrubber without Material', () {
    testWidgets('renders and scrubs with only a widgets ancestor',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(Column(children: [
        NibMotion(
          controller: controller,
          initial: const NibAnim(x: 0),
          child: const SizedBox(width: 10, height: 10),
        ),
      ])));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(x: 100),
          at: Duration.zero,
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      await tester.pumpWidget(_wrap(SizedBox(
        width: 400,
        child: NibTimelineScrubber(timeline: timeline),
      )));
      expect(tester.takeException(), isNull);
      // No Material widgets are involved.
      expect(
          find.byWidgetPredicate((w) => w.runtimeType.toString() == 'Slider'),
          findsNothing);

      final track = find.byKey(const ValueKey('nib_timeline_scrubber_track'));
      expect(track, findsOneWidget);
      final rect = tester.getRect(track);
      await tester.tapAt(Offset(rect.left + rect.width * 0.5, rect.center.dy));
      await tester.pump();
      expect(timeline.progress.value, closeTo(0.5, 0.02));

      await tester.dragFrom(
          Offset(rect.left + 2, rect.center.dy), Offset(rect.width, 0));
      await tester.pump();
      expect(timeline.progress.value, closeTo(1.0, 0.05));
    });

    testWidgets('mirrors progress and shows elapsed / total ms',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        child: const SizedBox(width: 10, height: 10),
      )));
      final timeline = NibTimeline([
        NibTimelineEntry(
          controller: controller,
          target: const NibAnim(x: 100),
          at: Duration.zero,
          transition: _linear1s,
        ),
      ]);
      addTearDown(timeline.dispose);
      await tester.pumpWidget(_wrap(SizedBox(
        width: 400,
        child: NibTimelineScrubber(timeline: timeline),
      )));
      timeline.seek(0.25);
      await tester.pump();
      expect(find.text('250 / 1000 ms'), findsOneWidget);
    });
  });
}
