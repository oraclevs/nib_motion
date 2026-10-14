import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );

RenderNibMotion _render(WidgetTester tester) {
  RenderNibMotion? render;
  void visit(RenderObject o) {
    if (o is RenderNibMotion) render = o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return render!;
}

void main() {
  group('drag release', () {
    testWidgets('inertia release respects constraints (elastic bounce back)',
        (tester) async {
      await tester.pumpWidget(_wrap(const NibMotion(
        drag: NibDragConfig(
          axis: Axis.horizontal,
          constraints: Rect.fromLTRB(0, 0, 100, 0),
          releaseMode: NibDragReleaseMode.inertia,
        ),
        child: SizedBox(width: 50, height: 50),
      )));

      final g = await tester.startGesture(const Offset(25, 25));
      for (var i = 1; i <= 4; i++) {
        await g.moveBy(const Offset(20, 0),
            timeStamp: Duration(milliseconds: 8 * i));
      }
      await g.up(timeStamp: const Duration(milliseconds: 33));

      var peak = 0.0;
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final x = _render(tester).translateX.value;
        if (x > peak) peak = x;
      }
      expect(_render(tester).translateX.value, closeTo(100, 0.01),
          reason: 'must not coast past the constraint and stay there');
      expect(peak, lessThan(400));
    });

    testWidgets('snap projection lets a flick reach the next snap point',
        (tester) async {
      Widget build(Duration projection) => _wrap(NibMotion(
            drag: NibDragConfig(
              axis: Axis.horizontal,
              releaseMode: NibDragReleaseMode.stay,
              snapPoints: const [Offset(0, 0), Offset(200, 0)],
              snapProjection: projection,
            ),
            child: const SizedBox(width: 50, height: 50),
          ));

      Future<double> flick(Duration projection) async {
        await tester.pumpWidget(build(projection));
        final g = await tester.startGesture(const Offset(25, 25));
        // Fast, short flick: ends near x=40..60 (nearer 0) at ~2500 px/s.
        for (var i = 1; i <= 3; i++) {
          await g.moveBy(const Offset(20, 0),
              timeStamp: Duration(milliseconds: 8 * i));
        }
        await g.up(timeStamp: const Duration(milliseconds: 25));
        await tester.pumpAndSettle();
        final x = _render(tester).translateX.value;
        await tester.pumpWidget(const SizedBox());
        return x;
      }

      expect(await flick(Duration.zero), closeTo(0, 0.5));
      expect(await flick(const Duration(milliseconds: 200)), closeTo(200, 0.5));
    });
  });
}
