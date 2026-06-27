import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return NibMotionConfig(
    entranceWarmup: Duration.zero,
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
  group('NibPulse', () {
    testWidgets('builds and pumps several frames without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibPulse(
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('scale oscillates away from 1.0 then keeps looping',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibPulse(
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.scaleX.value, 1.0);

      await tester.pump(const Duration(milliseconds: 50));
      expect(render.scaleX.value, isNot(1.0));

      // The repeat loop should keep the ticker scheduled across many cycles.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
