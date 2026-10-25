import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

Iterable<Layer> _layers(Layer root) sync* {
  yield root;
  if (root is ContainerLayer) {
    Layer? child = root.firstChild;
    while (child != null) {
      yield* _layers(child);
      child = child.nextSibling;
    }
  }
}

void main() {
  group('NibAnim rotateX / rotateY / blur / tint values', () {
    test('identity has zero rotation and blur, no tint', () {
      expect(NibAnim.identity.rotateX, 0);
      expect(NibAnim.identity.rotateY, 0);
      expect(NibAnim.identity.blur, 0);
      expect(NibAnim.identity.tint, isNull);
    });

    test('lerp interpolates, falling back to identity for unset side', () {
      const a = NibAnim(rotateY: 0.5, blur: 10, tint: Color(0xFF000000));
      final mid = NibAnim.identity.lerp(a, 0.5);
      expect(mid.rotateY, closeTo(0.25, 1e-9));
      expect(mid.rotateX, isNotNull);
      expect(mid.blur, closeTo(5, 1e-9));
      expect(mid.tint, isNotNull);
      expect(const NibAnim().lerp(const NibAnim(), 0.5).rotateY, isNull);
    });

    test('merge, copyWith and equality include the new fields', () {
      const a = NibAnim(rotateX: 0.1, rotateY: 0.2, blur: 3);
      const b = NibAnim(rotateY: 0.4, tint: Color(0xFFFF0000));
      final merged = a.merge(b);
      expect(merged.rotateX, 0.1);
      expect(merged.rotateY, 0.4);
      expect(merged.blur, 3);
      expect(merged.tint, const Color(0xFFFF0000));
      expect(a.copyWith(blur: 9).blur, 9);
      expect(a == const NibAnim(rotateX: 0.1, rotateY: 0.2, blur: 3), isTrue);
      expect(a == const NibAnim(rotateX: 0.1, rotateY: 0.2, blur: 4), isFalse);
      expect(a.hashCode,
          const NibAnim(rotateX: 0.1, rotateY: 0.2, blur: 3).hashCode);
    });
  });

  group('NibMotion 3D rotation', () {
    testWidgets('rotateY foreshortens the painted box (perspective)',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        initial: NibAnim(rotateY: 0.125), // 45 degrees
        child: SizedBox(width: 100, height: 100),
      )));
      final render = _render(tester);
      final right =
          MatrixUtils.transformPoint(render.transform, const Offset(100, 50));
      expect(right.dx, lessThan(100), reason: 'right edge swings away');
      expect(right.dx, greaterThan(0));
      // Untouched axis stays put.
      final top =
          MatrixUtils.transformPoint(render.transform, const Offset(50, 0));
      expect(top.dy, closeTo(0, 1e-6));
    });

    testWidgets('rotateX animates through the driver', (tester) async {
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: NibTransition.springSnappy,
        child: const SizedBox(width: 50, height: 50),
      )));
      controller.start(target: const NibAnim(rotateX: 0.25));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = _render(tester).rotateX.value;
      expect(mid, inExclusiveRange(0.0, 0.25));
      expect(_render(tester).rotateX.velocity, greaterThan(0));
      await tester.pumpAndSettle();
      expect(_render(tester).rotateX.value, 0.25);
    });

    testWidgets('taps land where a rotated-in-3D box is painted',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(NibMotion(
        initial: const NibAnim(rotateY: 0.1, x: 200),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 100),
        ),
      )));
      await tester.tapAt(const Offset(250, 50));
      expect(taps, 1);
      await tester.tapAt(const Offset(50, 50));
      expect(taps, 1);
    });
  });

  group('NibMotion blur and tint', () {
    testWidgets('blur adds an ImageFilterLayer, zero blur adds none',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        initial: NibAnim(blur: 6),
        child: SizedBox(width: 50, height: 50),
      )));
      final layers =
          _layers(RendererBinding.instance.renderViews.first.debugLayer!);
      expect(layers.whereType<ImageFilterLayer>(), isNotEmpty);

      await tester.pumpWidget(_wrap(const NibMotion(
        key: ValueKey('fresh'), // new state: `initial` is read once
        initial: NibAnim(blur: 0),
        child: SizedBox(width: 50, height: 50),
      )));
      final none =
          _layers(RendererBinding.instance.renderViews.first.debugLayer!);
      expect(none.whereType<ImageFilterLayer>(), isEmpty);
    });

    testWidgets('tint adds a ColorFilterLayer', (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        initial: NibAnim(tint: Color(0x80FF0000)),
        child: SizedBox(width: 50, height: 50),
      )));
      final layers =
          _layers(RendererBinding.instance.renderViews.first.debugLayer!);
      final filters = layers.whereType<ColorFilterLayer>().toList();
      expect(filters, isNotEmpty);
      expect(filters.first.colorFilter, isA<ui.ColorFilter>());
    });

    testWidgets('blur and tint animate without rebuilding the child',
        (tester) async {
      var builds = 0;
      final controller = NibMotionController();
      await tester.pumpWidget(_wrap(NibMotion(
        controller: controller,
        transition: const NibTransition(duration: Duration(milliseconds: 200)),
        child: Builder(builder: (_) {
          builds++;
          return const SizedBox(width: 50, height: 50);
        }),
      )));
      final before = builds;
      controller.start(target: const NibAnim(blur: 8, tint: Color(0xFF0000FF)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_render(tester).blur.value, inExclusiveRange(0.0, 8.0));
      await tester.pumpAndSettle();
      expect(_render(tester).blur.value, 8);
      expect(_render(tester).tint.value, const Color(0xFF0000FF));
      expect(builds, before);
    });

    testWidgets('external motion values drive blur', (tester) async {
      final blur = MotionValue<double>(0);
      await tester.pumpWidget(_wrap(NibMotion(
        motionValues: NibMotionValues(blur: blur),
        child: const SizedBox(width: 50, height: 50),
      )));
      blur.value = 5;
      await tester.pump();
      expect(
          _layers(RendererBinding.instance.renderViews.first.debugLayer!)
              .whereType<ImageFilterLayer>(),
          isNotEmpty);
    });
  });
}
