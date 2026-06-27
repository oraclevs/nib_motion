import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets(
    'removing a whileTap NibMotion mid-gesture does not throw on a deactivated context',
    (tester) async {
      // Regression test: a `whileTap` NibMotion wraps its child in a
      // GestureDetector(onTapDown/onTapUp/onTapCancel). If the widget is
      // removed from the tree while a tap is still "down" (e.g. a bottom nav
      // icon whose tap navigates to a new screen, replacing the tree),
      // `GestureDetector`'s `TapGestureRecognizer.dispose()` synchronously
      // calls `handleTapCancel` -> `_onTapEnd` -> `_revertFromGesture` ->
      // `animateTo`, while `StatefulElement.unmount()` has already cleared
      // this element's `_widget` (so `context.mounted` is false). Without the
      // `context.mounted` guard in `animateTo`, this throws "Looking up a
      // deactivated widget's ancestor is unsafe".
      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: NibMotion(
                whileTap: const NibAnim(scale: 0.82),
                transition: NibTransition.springSnappy,
                child: GestureDetector(
                  key: const Key('tappable'),
                  onTap: () {},
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester
          .startGesture(tester.getCenter(find.byKey(const Key('tappable'))));
      await tester.pump();

      // Simulate Navigator.pushReplacement swapping out the whole tree while
      // the pointer is still down.
      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
