import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('declarative velocity read', () {
    testWidgets('controller exposes value and velocity per property',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springGentle,
        child: const SizedBox(width: 10, height: 10),
      )));
      expect(controller.velocityOf(NibProperty.x), 0);
      controller.start(target: const NibAnim(x: 200, opacity: 0.5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(controller.velocityOf(NibProperty.x), greaterThan(0));
      expect(controller.velocityOf(NibProperty.opacity), lessThan(0));
      expect(controller.velocityOf(NibProperty.rotate), 0);
      final snapshot = controller.velocities;
      expect(snapshot[NibProperty.x], controller.velocityOf(NibProperty.x));
      expect(snapshot.keys, containsAll(NibProperty.values));
      final value = controller.motionValueOf(NibProperty.x)!;
      expect(value.value, inExclusiveRange(0.0, 200.0));
      expect(identical(value, _render(tester).translateX), isTrue,
          reason: 'the live MotionValue, so it is listenable');
      await tester.pumpAndSettle();
      expect(controller.velocityOf(NibProperty.x), 0);
    });

    testWidgets('a listener on the exposed MotionValue sees velocity',
        (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springSnappy,
        child: const SizedBox(width: 10, height: 10),
      )));
      final seen = <double>[];
      final value = controller.motionValueOf(NibProperty.x)!;
      value.addListener(() => seen.add(value.velocity));
      controller.start(target: const NibAnim(x: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(seen, isNotEmpty);
      expect(seen.any((v) => v > 0), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('unattached controller reports zero / null', (tester) async {
      final controller = NibMotionController();
      expect(controller.velocityOf(NibProperty.x), 0);
      expect(controller.motionValueOf(NibProperty.x), isNull);
      expect(controller.velocities.values.every((v) => v == 0), isTrue);
    });
  });

  group('offset-driven NibMotion', () {
    testWidgets('MotionValue<Offset> drives translate without rebuilding',
        (tester) async {
      var builds = 0;
      final offset = MotionValue<Offset>(Offset.zero);
      final key = GlobalKey();
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset),
        child: Builder(builder: (_) {
          builds++;
          return SizedBox(key: key, width: 50, height: 50);
        }),
      )));
      final before = builds;
      offset.value = const Offset(30, 40);
      await tester.pump();
      expect(_render(tester).translateX.value, 30);
      expect(_render(tester).translateY.value, 40);
      final box = key.currentContext!.findRenderObject()! as RenderBox;
      expect(box.localToGlobal(Offset.zero), const Offset(30, 40));
      for (var i = 1; i <= 10; i++) {
        offset.value = Offset(i * 10.0, i * 5.0);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds, before, reason: 'paint-only: no rebuilds');
      expect(_render(tester).translateX.value, 100);
    });

    testWidgets('initial offset is applied on first frame', (tester) async {
      final offset = MotionValue<Offset>(const Offset(12, 7));
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset),
        child: const SizedBox(width: 50, height: 50),
      )));
      expect(_render(tester).translateX.value, 12);
      expect(_render(tester).translateY.value, 7);
    });

    testWidgets('explicit translateX wins over offset on that axis',
        (tester) async {
      final offset = MotionValue<Offset>(const Offset(30, 40));
      final tx = MotionValue<double>(5);
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset, translateX: tx),
        child: const SizedBox(width: 50, height: 50),
      )));
      expect(_render(tester).translateX.value, 5);
      expect(_render(tester).translateY.value, 40);
      offset.value = const Offset(99, 98);
      await tester.pump();
      expect(_render(tester).translateX.value, 5);
      expect(_render(tester).translateY.value, 98);
    });

    testWidgets('unmounting detaches from the offset and never disposes it',
        (tester) async {
      final offset = MotionValue<Offset>(Offset.zero);
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset),
        child: const SizedBox(width: 50, height: 50),
      )));
      expect(offset.hasListeners, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(offset.hasListeners, isFalse);
      offset.value = const Offset(1, 1); // would throw if disposed
      offset.dispose();
    });

    testWidgets('NibOffsetMotionValue exposes x/y channels and shares them',
        (tester) async {
      final offset = NibOffsetMotionValue(const Offset(3, 4));
      expect(offset.x.value, 3);
      expect(offset.y.value, 4);
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset),
        child: const SizedBox(width: 50, height: 50),
      )));
      expect(identical(_render(tester).translateX, offset.x), isTrue);
      offset.value = const Offset(8, 9);
      await tester.pump();
      expect(_render(tester).translateY.value, 9);
      await tester.pumpWidget(const SizedBox());
      // Shared channels belong to the adapter: still usable after unmount.
      offset.value = const Offset(1, 2);
      expect(offset.x.value, 1);
      offset.dispose();
      expect(offset.x.hasListeners, isFalse);
    });

    testWidgets('a MultiSpringSolver on an offset value moves the widget',
        (tester) async {
      final offset = NibOffsetMotionValue(Offset.zero);
      final solver = MultiSpringSolver<Offset>(
        vsync: const TestVSync(),
        value: offset,
        converter: MotionConverter.offset,
        spring: NibSpringDescription.snappy,
      );
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(offset: offset),
        child: const SizedBox(width: 50, height: 50),
      )));
      solver.animateTo(const Offset(100, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_render(tester).translateX.value, inExclusiveRange(0.0, 100.0));
      await tester.pumpAndSettle();
      expect(_render(tester).translateX.value, 100);
      expect(_render(tester).translateY.value, 50);
      solver.dispose();
    });
  });
}
