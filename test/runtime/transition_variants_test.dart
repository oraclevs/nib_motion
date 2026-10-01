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

void main() {
  group('NibSpringCurve', () {
    test('starts at 0, ends exactly at 1, overshoots for a bouncy spring', () {
      final curve = NibSpringCurve(NibSpringDescription.wobbly);
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      final samples = [for (var i = 1; i < 100; i++) curve.transform(i / 100)];
      expect(samples.reduce((a, b) => a > b ? a : b), greaterThan(1.0));
    });

    test('a critically damped spring never overshoots', () {
      final curve = NibSpringCurve(NibSpringDescription.fromDuration(
          duration: const Duration(milliseconds: 400), bounce: 0));
      final samples = [for (var i = 0; i <= 100; i++) curve.transform(i / 100)];
      expect(samples.every((v) => v <= 1.0 + 1e-9), isTrue);
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1] - 1e-9));
      }
    });
  });

  group('per-keyframe spring segments', () {
    test('a spring keyframe overshoots its own segment only', () {
      const frames = [
        NibKeyframe(at: 0, value: NibAnim(x: 0)),
        NibKeyframe(
            at: 0.5,
            value: NibAnim(x: 100),
            spring: NibSpringDescription.wobbly),
        NibKeyframe(at: 1, value: NibAnim(x: 0)),
      ];
      var peak = 0.0;
      for (var i = 0; i <= 100; i++) {
        final x = computeAnimFromKeyframes(frames, i / 100, Curves.linear).x!;
        if (i <= 50 && x > peak) peak = x;
      }
      expect(peak, greaterThan(100), reason: 'bouncy segment overshoots');
      expect(computeAnimFromKeyframes(frames, 0.5, Curves.linear).x, 100);
      // Second segment (no spring) is plain linear: monotonically decreasing.
      final a = computeAnimFromKeyframes(frames, 0.6, Curves.linear).x!;
      final b = computeAnimFromKeyframes(frames, 0.8, Curves.linear).x!;
      expect(a, greaterThan(b));
    });

    test('curve and spring are mutually exclusive', () {
      expect(
          () => NibKeyframe(
              at: 1,
              value: const NibAnim(),
              curve: Curves.easeIn,
              spring: NibSpringDescription.gentle),
          throwsAssertionError);
    });
  });

  group('reverse and exit transitions', () {
    testWidgets('whileTap release uses reverseTransition', (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        whileTap: NibAnim(scale: 0.5),
        transition: NibTransition(duration: Duration(milliseconds: 1000)),
        reverseTransition: NibTransition(duration: Duration(milliseconds: 100)),
        child: SizedBox(width: 50, height: 50),
      )));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_render(tester).scaleX.value, closeTo(0.5, 0.01));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_render(tester).scaleX.value, closeTo(1.0, 0.02),
          reason: 'reverse uses the fast 100ms transition');
    });

    testWidgets('without reverseTransition the default transition is used',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        whileTap: NibAnim(scale: 0.5),
        transition: NibTransition(duration: Duration(milliseconds: 1000)),
        child: SizedBox(width: 50, height: 50),
      )));
      final g = await tester.startGesture(const Offset(25, 25));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_render(tester).scaleX.value, lessThan(0.8));
      await tester.pumpAndSettle();
    });

    testWidgets('presence exit uses exitTransition', (tester) async {
      Widget host(bool on) => Directionality(
            textDirection: TextDirection.ltr,
            child: NibPresence(children: [
              if (on)
                const NibMotion(
                  key: ValueKey('a'),
                  exit: NibAnim(opacity: 0),
                  transition:
                      NibTransition(duration: Duration(milliseconds: 2000)),
                  exitTransition:
                      NibTransition(duration: Duration(milliseconds: 100)),
                  child: SizedBox(width: 10, height: 10),
                ),
            ]),
          );
      await tester.pumpWidget(host(true));
      await tester.pumpWidget(host(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('a')), findsNothing,
          reason: 'the 100ms exit transition finished');
    });
  });

  group('loop modes on NibMotion', () {
    Widget loop(NibLoopMode? mode) => _wrap(NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: NibMotion(
            initial: const NibAnim(x: 0),
            animate: const NibAnim(x: 100),
            repeatAnimationInLoop: true,
            loopMode: mode ?? NibLoopMode.pingPong,
            transition: const NibTransition(
                duration: Duration(milliseconds: 1000), curve: Curves.linear),
            child: const SizedBox(width: 10, height: 10),
          ),
        ));

    testWidgets('restart mode jumps back instead of reversing', (tester) async {
      await tester.pumpWidget(loop(NibLoopMode.restart));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1250));
      expect(_render(tester).translateX.value, closeTo(25, 8),
          reason: 'second cycle restarted from the start');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pingPong (default) returns along the same path',
        (tester) async {
      await tester.pumpWidget(loop(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1250));
      expect(_render(tester).translateX.value, closeTo(75, 8),
          reason: 'coming back from the far end');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
