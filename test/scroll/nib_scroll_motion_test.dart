import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _scrollable(ScrollController controller, WidgetBuilder builder) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      height: 100,
      width: 100,
      child: Stack(
        children: [
          ListView(
            controller: controller,
            children: [for (var i = 0; i < 20; i++) const SizedBox(height: 50)],
          ),
          Builder(builder: builder),
        ],
      ),
    ),
  );
}

void main() {
  group('NibScrollMotion', () {
    testWidgets('builder receives a bridge tracking the given controller', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      ScrollMotionBridge? received;
      await tester.pumpWidget(
        _scrollable(
          controller,
          (context) => NibScrollMotion(
            controller: controller,
            builder: (context, bridge) {
              received = bridge;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(received, isNotNull);
      expect(received!.controller, same(controller));

      controller.jumpTo(100);
      expect(received!.scrollY.value, 100.0);
    });

    testWidgets('dispose removes the bridge listener from the controller', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _scrollable(
          controller,
          (context) => NibScrollMotion(
            controller: controller,
            builder: (context, bridge) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(_scrollable(controller, (context) => const SizedBox.shrink()));

      expect(() => controller.jumpTo(50), returnsNormally);
    });
  });
}
