import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

class _PaintSpy extends CustomPainter {
  _PaintSpy(this.count);

  final ValueNotifier<int> count;

  @override
  void paint(Canvas canvas, Size size) {
    count.value++;
    canvas.drawRect(Offset.zero & size, Paint());
  }

  @override
  bool shouldRepaint(covariant _PaintSpy oldDelegate) => true;
}

class _TestMotionValues {
  _TestMotionValues({
    double opacity = 1.0,
    double translateX = 0.0,
    double translateY = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double rotate = 0.0,
    double skewX = 0.0,
    double skewY = 0.0,
    Color? color,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
  }) : opacity = MotionValue<double>(opacity),
       translateX = MotionValue<double>(translateX),
       translateY = MotionValue<double>(translateY),
       scaleX = MotionValue<double>(scaleX),
       scaleY = MotionValue<double>(scaleY),
       rotate = MotionValue<double>(rotate),
       skewX = MotionValue<double>(skewX),
       skewY = MotionValue<double>(skewY),
       color = MotionValue<Color?>(color),
       borderRadius = MotionValue<BorderRadius?>(borderRadius),
       boxShadow = MotionValue<List<BoxShadow>?>(boxShadow);

  final MotionValue<double> opacity;
  final MotionValue<double> translateX;
  final MotionValue<double> translateY;
  final MotionValue<double> scaleX;
  final MotionValue<double> scaleY;
  final MotionValue<double> rotate;
  final MotionValue<double> skewX;
  final MotionValue<double> skewY;
  final MotionValue<Color?> color;
  final MotionValue<BorderRadius?> borderRadius;
  final MotionValue<List<BoxShadow>?> boxShadow;

  List<MotionValue<Object?>> get all => [
    opacity,
    translateX,
    translateY,
    scaleX,
    scaleY,
    rotate,
    skewX,
    skewY,
    color,
    borderRadius,
    boxShadow,
  ];
}

class _NibMotionTestBox extends SingleChildRenderObjectWidget {
  const _NibMotionTestBox({required this.values, super.child});

  final _TestMotionValues values;

  @override
  RenderNibMotion createRenderObject(BuildContext context) {
    return RenderNibMotion(
      opacity: values.opacity,
      translateX: values.translateX,
      translateY: values.translateY,
      scaleX: values.scaleX,
      scaleY: values.scaleY,
      rotate: values.rotate,
      skewX: values.skewX,
      skewY: values.skewY,
      color: values.color,
      borderRadius: values.borderRadius,
      boxShadow: values.boxShadow,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderNibMotion renderObject) {
    renderObject
      ..opacity = values.opacity
      ..translateX = values.translateX
      ..translateY = values.translateY
      ..scaleX = values.scaleX
      ..scaleY = values.scaleY
      ..rotate = values.rotate
      ..skewX = values.skewX
      ..skewY = values.skewY
      ..color = values.color
      ..borderRadius = values.borderRadius
      ..boxShadow = values.boxShadow;
  }
}

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

void main() {
  group('RenderNibMotion', () {
    testWidgets('opacity of 0.0 hides the child', (tester) async {
      final paintCount = ValueNotifier<int>(0);
      final values = _TestMotionValues(opacity: 0.0);

      await tester.pumpWidget(
        _wrap(
          _NibMotionTestBox(
            values: values,
            child: SizedBox(width: 50, height: 50, child: CustomPaint(painter: _PaintSpy(paintCount))),
          ),
        ),
      );

      expect(paintCount.value, 0);
    });

    testWidgets('opacity of 0.0 hides the background color too', (tester) async {
      final values = _TestMotionValues(opacity: 0.0, color: const Color(0xFF112233));

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      expect(find.byType(_NibMotionTestBox), paintsNothing);
    });

    testWidgets('translateX offsets the child by a pure translation', (tester) async {
      final values = _TestMotionValues(translateX: 50.0);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 100, height: 100))),
      );

      final renderObject = tester.renderObject<RenderNibMotion>(find.byType(_NibMotionTestBox));
      expect(renderObject.transform, Matrix4.translationValues(50.0, 0.0, 0.0));
    });

    testWidgets('scale of 2.0 doubles the apparent size of the child', (tester) async {
      final values = _TestMotionValues(scaleX: 2.0, scaleY: 2.0);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 100, height: 100))),
      );

      final renderObject = tester.renderObject<RenderNibMotion>(find.byType(_NibMotionTestBox));
      expect(renderObject.transform.getMaxScaleOnAxis(), closeTo(2.0, 1e-9));
    });

    testWidgets('rotate of 0.5 turns flips the child upside down', (tester) async {
      final values = _TestMotionValues(rotate: 0.5);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 100, height: 100))),
      );

      final renderObject = tester.renderObject<RenderNibMotion>(find.byType(_NibMotionTestBox));
      final transform = renderObject.transform;

      final topCenter = MatrixUtils.transformPoint(transform, const Offset(50, 0));
      final bottomCenter = MatrixUtils.transformPoint(transform, const Offset(50, 100));

      expect(topCenter, within(distance: 1e-9, from: const Offset(50, 100)));
      expect(bottomCenter, within(distance: 1e-9, from: const Offset(50, 0)));
    });

    testWidgets('updating a MotionValue repaints without rebuilding ancestors', (tester) async {
      var buildCount = 0;
      final values = _TestMotionValues();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              buildCount++;
              return Center(
                child: _NibMotionTestBox(values: values, child: const SizedBox(width: 50, height: 50)),
              );
            },
          ),
        ),
      );

      expect(buildCount, 1);

      values.translateX.value = 50.0;
      values.opacity.value = 0.5;
      values.rotate.value = 0.25;
      await tester.pump();

      expect(buildCount, 1);
    });

    testWidgets('dispose removes listeners from every MotionValue', (tester) async {
      final values = _TestMotionValues();

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 10, height: 10))),
      );

      for (final motionValue in values.all) {
        expect(motionValue.hasListeners, isTrue);
      }

      await tester.pumpWidget(const SizedBox());

      for (final motionValue in values.all) {
        expect(motionValue.hasListeners, isFalse);
      }
    });

    testWidgets('translateX moves the background color along with the child', (tester) async {
      final values = _TestMotionValues(translateX: 50.0, color: const Color(0xFF112233));

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      expect(find.byType(_NibMotionTestBox), paints..transform()..rect(color: const Color(0xFF112233)));
    });

    testWidgets('a non-null color paints a background rect behind the child', (tester) async {
      const color = Color(0xFF112233);
      final values = _TestMotionValues(color: color);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      expect(find.byType(_NibMotionTestBox), paints..rect(color: color));
    });

    testWidgets('a non-null borderRadius clips the child', (tester) async {
      final values = _TestMotionValues(borderRadius: BorderRadius.circular(8.0));

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      expect(find.byType(_NibMotionTestBox), paints..clipRRect());
    });

    testWidgets('a non-null borderRadius clips around the child when offset from the origin', (tester) async {
      // Regression test: `pushClipRRect` shifts its `bounds`/`clipRRect`
      // arguments by `offset` itself, so passing already-offset rects (as
      // `offset & size`) double-applies the offset and clips the child out
      // entirely whenever this render object isn't painted at (0, 0).
      //
      // The `paints` matcher always invokes `paint(context, Offset.zero)`,
      // so to exercise a non-zero offset we call `paint` directly inside a
      // custom painter function and check the resulting canvas commands.
      const color = Color(0xFF112233);
      final values = _TestMotionValues(borderRadius: BorderRadius.circular(8.0), color: color);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      final renderObject = tester.renderObject<RenderNibMotion>(find.byType(_NibMotionTestBox));
      const paintOffset = Offset(100, 50);
      final expectedRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(100, 50, 40, 40),
        const Radius.circular(8.0),
      );

      expect(
        (PaintingContext context, Offset _) => renderObject.paint(context, paintOffset),
        paints
          ..rrect(rrect: expectedRRect, color: color)
          ..clipRRect(rrect: expectedRRect),
      );
    });

    testWidgets('a non-null boxShadow paints a shadow behind the child', (tester) async {
      const shadow = BoxShadow(color: Color(0xFF000000), blurRadius: 4.0);
      final values = _TestMotionValues(boxShadow: const [shadow]);

      await tester.pumpWidget(
        _wrap(_NibMotionTestBox(values: values, child: const SizedBox(width: 40, height: 40))),
      );

      expect(find.byType(_NibMotionTestBox), paints..rrect(color: shadow.color));
    });
  });
}
