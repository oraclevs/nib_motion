import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return NibMotionConfig(
    entranceWarmup: Duration.zero,
    child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
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
  group('NibFloat', () {
    testWidgets('builds and pumps several frames without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibFloat(
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

    testWidgets('y offset moves away from 0 and the loop keeps running', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibFloat(
            distance: 10,
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.translateY.value, 0.0);

      await tester.pump(const Duration(milliseconds: 50));
      expect(render.translateY.value, isNot(0.0));

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
