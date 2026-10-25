import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _blue = Color(0xFF0000FF);
const _shot = ValueKey('shot');

Widget _box(String id, Color color) => ColoredBox(
      key: ValueKey(id),
      color: color,
      child: const SizedBox(width: 100, height: 50),
    );

Widget _host({Axis axis = Axis.vertical}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _shot,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: SizedBox(
              width: 300,
              height: 300,
              child: Align(
                alignment: Alignment.topLeft,
                child: NibReorderable(
                  axis: axis,
                  onReorder: (_, __) {},
                  children: [
                    _box('a', _red),
                    _box('b', _green),
                    _box('c', _blue),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// The colour painted at [point] (logical px) inside the boundary.
Future<Color> _pixel(WidgetTester tester, Offset point) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final color = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final x = point.dx.round(), y = point.dy.round();
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
        data.getUint8(i + 1), data.getUint8(i + 2));
  });
  return color!;
}

void main() {
  testWidgets('the dragged item paints above later siblings', (tester) async {
    await tester.pumpWidget(_host());
    final g = await tester.startGesture(const Offset(50, 25));
    await tester.pump(const Duration(milliseconds: 700)); // long press
    await g.moveBy(const Offset(0, 14));
    await g.moveBy(const Offset(0, 16));
    await tester.pump(const Duration(milliseconds: 500)); // lift settles
    // 'a' (red) is now painted around y 30..80, overlapping 'b' at 50..80.
    expect(await _pixel(tester, const Offset(50, 40)), _red);
    expect(await _pixel(tester, const Offset(50, 65)), _red,
        reason: 'overlap with b: the dragged red item must be on top');
    expect(await _pixel(tester, const Offset(50, 90)), _green,
        reason: 'below the dragged item b is still visible');
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('horizontal: dragged item also paints on top', (tester) async {
    await tester.pumpWidget(_host(axis: Axis.horizontal));
    final g = await tester.startGesture(const Offset(50, 25));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(14, 0));
    await g.moveBy(const Offset(16, 0));
    await tester.pump(const Duration(milliseconds: 500));
    // 'a' (red) is painted at x 30..130, overlapping 'b' over x 100..130.
    expect(await _pixel(tester, const Offset(115, 25)), _red,
        reason: 'overlap with b: red on top');
    expect(await _pixel(tester, const Offset(165, 25)), _green);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the lift scale is applied once the lift animation settles',
      (tester) async {
    await tester.pumpWidget(_host());
    final key = const ValueKey('a');
    final before = tester.getSize(find.byKey(key));
    final g = await tester.startGesture(const Offset(50, 25));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(0, 4));
    await tester.pump(const Duration(milliseconds: 800));
    RenderNibMotion? motion;
    find.byKey(key).evaluate().single.visitAncestorElements((e) {
      if (e.renderObject is RenderNibMotion) {
        motion = e.renderObject! as RenderNibMotion;
        return false;
      }
      return true;
    });
    expect(before, const Size(100, 50));
    expect(motion!.scaleX.value, greaterThan(1.0),
        reason: 'lifted item is scaled up');
    await g.up();
    await tester.pumpAndSettle();
    expect(motion!.scaleX.value, closeTo(1.0, 1e-3));
  });
}
