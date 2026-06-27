import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return NibMotionConfig(
    entranceWarmup: Duration.zero,
    child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
  );
}

/// Returns every [RenderNibMotion] in the tree, in depth-first build order.
List<RenderNibMotion> _findRenderNibMotions(WidgetTester tester) {
  final found = <RenderNibMotion>[];
  void visit(RenderObject object) {
    if (object is RenderNibMotion) found.add(object);
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found;
}

List<Widget> _items(int count) => [
  for (var i = 0; i < count; i++) SizedBox(key: ValueKey('item$i'), width: 10, height: 10),
];

void main() {
  group('NibMotionList', () {
    testWidgets('staggers children so the first starts before the last', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotionList(
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            staggerDelay: const Duration(milliseconds: 100),
            transition: const NibTransition(duration: Duration(milliseconds: 100)),
            children: _items(5),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final motions = _findRenderNibMotions(tester);
      expect(motions[0].opacity.value, greaterThan(0.0));
      expect(motions[4].opacity.value, 0.0);
    });

    testWidgets('staggerDirection reverse starts the last child before the first', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotionList(
            initial: const NibAnim(opacity: 0),
            animate: const NibAnim(opacity: 1),
            staggerDelay: const Duration(milliseconds: 100),
            staggerDirection: NibStaggerDirection.reverse,
            transition: const NibTransition(duration: Duration(milliseconds: 100)),
            children: _items(5),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final motions = _findRenderNibMotions(tester);
      expect(motions[4].opacity.value, greaterThan(0.0));
      expect(motions[0].opacity.value, 0.0);
    });

    testWidgets('presenceEnabled plays the exit animation for a removed child', (tester) async {
      Widget build(List<Widget> children) {
        return _wrap(
          NibMotionList(
            initial: const NibAnim(opacity: 1),
            exit: const NibAnim(opacity: 0),
            presenceEnabled: true,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            children: children,
          ),
        );
      }

      final items = _items(2);
      await tester.pumpWidget(build(items));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build([items[0]]));

      // Still mounted right after removal -- exit animation is running.
      expect(find.byKey(const ValueKey('item1')), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item1')), findsNothing);
    });

    testWidgets('controller.start animates all children', (tester) async {
      final controller = NibMotionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          NibMotionList(
            initial: const NibAnim(opacity: 0),
            controller: controller,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            children: _items(3),
          ),
        ),
      );

      controller.start(target: const NibAnim(opacity: 0.5));
      await tester.pumpAndSettle();

      final motions = _findRenderNibMotions(tester);
      for (final motion in motions) {
        expect(motion.opacity.value, closeTo(0.5, 0.001));
      }
    });
  });
}
