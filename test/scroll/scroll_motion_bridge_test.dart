import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _scrollable(ScrollController controller) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      height: 100,
      width: 100,
      child: ListView(
        controller: controller,
        children: [for (var i = 0; i < 20; i++) const SizedBox(height: 50)],
      ),
    ),
  );
}

void main() {
  group('ScrollMotionBridge', () {
    testWidgets('scrollY tracks the ScrollController offset', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollable(controller));

      final bridge = ScrollMotionBridge(controller: controller);
      addTearDown(bridge.dispose);

      controller.jumpTo(100);

      expect(bridge.scrollY.value, 100.0);
    });

    testWidgets('scrollY.mapRange([0,200],[1.0,0.0]) at scroll=100 gives 0.5',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollable(controller));

      final bridge = ScrollMotionBridge(controller: controller);
      addTearDown(bridge.dispose);
      final mapped = bridge.scrollY.mapRange([0, 200], [1.0, 0.0]);

      controller.jumpTo(100);

      expect(mapped.value, 0.5);
    });

    testWidgets('dispose removes the listener from the controller',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scrollable(controller));

      final bridge = ScrollMotionBridge(controller: controller);
      controller.jumpTo(100);
      expect(bridge.scrollY.value, 100.0);

      bridge.dispose();

      expect(() => controller.jumpTo(50), returnsNormally);
      expect(bridge.scrollY.value, 100.0);
    });
  });
}
