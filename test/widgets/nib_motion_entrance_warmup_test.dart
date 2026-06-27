import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child,
    {Duration entranceWarmup = const Duration(milliseconds: 400)}) {
  return NibMotionConfig(
    entranceWarmup: entranceWarmup,
    child: Directionality(
        textDirection: TextDirection.ltr, child: Center(child: child)),
  );
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  setUp(() {
    NibMotionConfig.resetAppStartTime();
    NibMotionGate.reset();
  });

  group('NibMotionConfig.entranceWarmup', () {
    testWidgets(
        'holds the entrance animation at its initial value until the warm-up window elapses',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            transition:
                const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.opacity.value, 0.0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(render.opacity.value, 0.0,
          reason: 'still within the default 400ms warm-up window');

      await tester.pumpAndSettle();
      expect(render.opacity.value, 1.0,
          reason: 'starts once the warm-up window elapses');
    });

    testWidgets('Duration.zero starts the entrance animation immediately',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            transition:
                const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 10, height: 10),
          ),
          entranceWarmup: Duration.zero,
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.opacity.value, 0.0);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(render.opacity.value, 1.0,
          reason: 'no warm-up delay when entranceWarmup is zero');
    });
  });

  group('NibMotionGate', () {
    testWidgets(
        'hold() keeps the entrance animation at its initial value until release()',
        (tester) async {
      NibMotionGate.hold();
      addTearDown(NibMotionGate.reset);

      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            transition:
                const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 10, height: 10),
          ),
          entranceWarmup: Duration.zero,
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.opacity.value, 0.0);

      await tester.pump(const Duration(milliseconds: 500));
      expect(render.opacity.value, 0.0,
          reason: 'held entrance animations do not start');

      NibMotionGate.release();
      await tester.pumpAndSettle();
      expect(render.opacity.value, 1.0,
          reason: 'releases the held entrance animation');
    });
  });
}
