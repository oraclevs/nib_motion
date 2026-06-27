import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/text/nib_text_reveal.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibTextReveal _findRenderObject(WidgetTester tester) {
  RenderNibTextReveal? found;
  void visit(RenderObject object) {
    if (object is RenderNibTextReveal) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('NibTextReveal', () {
    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTextReveal(
            duration: Duration(milliseconds: 100),
            child: Text('Reveal me'),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Reveal me'), findsOneWidget);
    });

    testWidgets('animates the clip factor from 0 to 1 over duration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTextReveal(
            duration: Duration(milliseconds: 100),
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );

      await tester.pump();
      final renderObject = _findRenderObject(tester);
      expect(renderObject.factor.value, 0.0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.factor.value, closeTo(1.0, 0.01));
    });

    testWidgets('respects an initial delay before revealing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTextReveal(
            duration: Duration(milliseconds: 100),
            delay: Duration(milliseconds: 50),
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );

      await tester.pump();
      final renderObject = _findRenderObject(tester);
      expect(renderObject.factor.value, 0.0);

      await tester.pump(const Duration(milliseconds: 50));
      // Still at (or very near) zero right when the delay elapses.
      expect(renderObject.factor.value, lessThan(0.1));

      await tester.pump(const Duration(milliseconds: 100));
      expect(renderObject.factor.value, closeTo(1.0, 0.01));
    });

    for (final direction in NibTextRevealDirection.values) {
      testWidgets('supports direction $direction without throwing', (tester) async {
        await tester.pumpWidget(
          _wrap(
            NibTextReveal(
              direction: direction,
              duration: const Duration(milliseconds: 50),
              child: const SizedBox(width: 80, height: 30),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disposes cleanly when removed mid-animation', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NibTextReveal(
            duration: Duration(milliseconds: 200),
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });
  });
}
