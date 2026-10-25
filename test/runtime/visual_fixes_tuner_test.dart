import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _host(NibSpringDescription initial, {double width = 420}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: true,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 900)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: NibSpringTuner(initial: initial),
            ),
          ),
        ),
      ),
    );

String _snippet(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('nib-tuner-snippet'))).data!;

void main() {
  group('nibSpringToDurationBounce', () {
    for (final bounce in [-0.5, -0.1, 0.0, 0.25, 0.6]) {
      test('round-trips fromDuration(bounce: $bounce)', () {
        final spring = NibSpringDescription.fromDuration(
            duration: const Duration(milliseconds: 640), bounce: bounce);
        final back = nibSpringToDurationBounce(spring);
        expect(back.duration.inMilliseconds, closeTo(640, 2));
        expect(back.bounce, closeTo(bounce, 0.01));
      });
    }

    test('a non-unit mass keeps the same natural period and damping ratio', () {
      const heavy = NibSpringDescription(mass: 4, stiffness: 400, damping: 40);
      final r = nibSpringToDurationBounce(heavy);
      // period 2*pi*sqrt(m/k) = 2*pi*0.1 s; zeta = 40 / (2*sqrt(1600)) = 0.5
      expect(r.duration.inMilliseconds, closeTo(628, 2));
      expect(r.bounce, closeTo(0.5, 0.01));
    });

    test('is clamped into the slider ranges', () {
      const extreme =
          NibSpringDescription(mass: 1, stiffness: 100000, damping: 0.001);
      final r = nibSpringToDurationBounce(extreme);
      expect(r.duration.inMilliseconds, inInclusiveRange(100, 2000));
      expect(r.bounce, inInclusiveRange(-0.9, 0.9));
    });
  });

  group('NibSpringTuner honours initial in duration+bounce mode', () {
    testWidgets('bounce 0 and 0.5 start with different values', (tester) async {
      Widget keyed(double bounce) => KeyedSubtree(
            key: ValueKey('b$bounce'),
            child: _host(NibSpringDescription.fromDuration(
                duration: const Duration(milliseconds: 400), bounce: bounce)),
          );
      await tester.pumpWidget(keyed(0.0));
      final a = _snippet(tester);
      await tester.pumpWidget(keyed(0.5));
      final b = _snippet(tester);
      expect(a, isNot(b));
      expect(a, contains('bounce: 0.00'));
      expect(b, contains('bounce: 0.50'));
      expect(a, contains('milliseconds: 400'));
      expect(b, contains('milliseconds: 400'));
    });

    testWidgets('the default initial (gentle) reproduces gentle',
        (tester) async {
      await tester.pumpWidget(_host(NibSpringDescription.gentle));
      final snippet = _snippet(tester);
      final r = nibSpringToDurationBounce(NibSpringDescription.gentle);
      expect(snippet, contains('milliseconds: ${r.duration.inMilliseconds}'));
    });
  });

  group('layout', () {
    for (final width in [420.0, 320.0]) {
      testWidgets('fits a ${width.toInt()}px stage without overflow',
          (tester) async {
        await tester
            .pumpWidget(_host(NibSpringDescription.wobbly, width: width));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(NibSpringTuner));
        expect(size.width, lessThanOrEqualTo(width + 0.01));
      });
    }
  });
}
