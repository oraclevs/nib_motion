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
  group('NibBounce', () {
    testWidgets('animates in and settles without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibBounce(
            duration: Duration(milliseconds: 200),
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      // bounceIn starts at y: -60, opacity: 0.
      expect(render.translateY.value, -60.0);
      expect(render.opacity.value, 0.0);

      await tester.pump();
      // Pump in small steps (rather than one big jump) so the keyframe
      // controller actually ticks through the 0.6 keyframe — where opacity
      // is explicitly set to 1.0 — instead of skipping straight from 0% to
      // 100% progress in a single frame, which would land only on the first
      // and last keyframes' raw (sparse) values.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(render.translateY.value, closeTo(0.0, 0.001));
      expect(render.opacity.value, closeTo(1.0, 0.001));
      expect(tester.takeException(), isNull);
    });
  });
}
