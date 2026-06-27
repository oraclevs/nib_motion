import 'dart:async';

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
  group('NibShake', () {
    testWidgets(
        'shake() with an explicit controller animates x and returns to 0',
        (tester) async {
      final controller = NibShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibShake(
            controller: controller,
            duration: const Duration(milliseconds: 200),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final render = _findRenderNibMotion(tester);
      expect(render.translateX.value, 0.0);

      unawaited(controller.shake());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // Partway through the shake keyframes, x should have moved off 0.
      expect(render.translateX.value, isNot(0.0));

      await tester.pumpAndSettle();
      expect(render.translateX.value, closeTo(0.0, 0.001));
    });

    testWidgets('shake() completes without a caller-provided controller',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibShake(
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );

      // No controller was supplied, so NibShake owns one internally; this
      // just verifies building and settling doesn't throw.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing the widget tree does not throw', (tester) async {
      final controller = NibShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibShake(
            controller: controller,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      unawaited(controller.shake());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
