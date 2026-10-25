import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _app(Widget child, {required bool reduced}) => Directionality(
      textDirection: TextDirection.ltr,
      child: NibMotionConfig(
        reducedMotion: reduced,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

T _render<T extends RenderObject>(WidgetTester tester) {
  T? found;
  void visit(RenderObject o) {
    if (o is T) found = o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

/// Finds a (possibly private) render object by class name.
dynamic _named(WidgetTester tester, String name) {
  RenderObject? found;
  void visit(RenderObject o) {
    if (o.runtimeType.toString() == name) found = o;
    o.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found;
}

const _box = SizedBox(width: 60, height: 60);

void main() {
  tearDown(() => NibMotionConfig.setReducedMotion(null));

  group('reduced motion: decorative loops stay static', () {
    testWidgets('NibGradientText', (tester) async {
      Widget w() => const NibGradientText(
            'hi',
            gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
          );
      await tester.pumpWidget(_app(w(), reduced: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(_app(w(), reduced: false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NibShimmer', (tester) async {
      await tester
          .pumpWidget(_app(const NibShimmer(child: _box), reduced: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);

      await tester
          .pumpWidget(_app(const NibShimmer(child: _box), reduced: false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('preference flipping while mounted stops the loop',
        (tester) async {
      Widget w(bool reduced) =>
          _app(const NibShimmer(child: _box), reduced: reduced);
      await tester.pumpWidget(w(false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(w(true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduced motion: one-shot motion jumps to its end state', () {
    testWidgets('NibTextReveal shows fully at once', (tester) async {
      await tester.pumpWidget(_app(
        const NibTextReveal(child: Text('hello')),
        reduced: true,
      ));
      await tester.pump();
      expect(_render<RenderNibTextReveal>(tester).factor.value, 1.0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibTextReveal animates when not reduced', (tester) async {
      await tester.pumpWidget(_app(
        const NibTextReveal(child: Text('hello')),
        reduced: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_render<RenderNibTextReveal>(tester).factor.value,
          inExclusiveRange(0.0, 1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('NibTypewriter types everything, no timers, fires onComplete',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(_app(
        NibTypewriter('hello world', onComplete: () => done++),
        reduced: true,
      ));
      await tester.pump();
      expect(find.textContaining('hello world'), findsOneWidget);
      expect(done, 1);
    });

    testWidgets('NibTypewriter still types when not reduced', (tester) async {
      await tester.pumpWidget(_app(
        const NibTypewriter('hello', cursor: null),
        reduced: false,
      ));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('hello'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('NibPathMotion lands on the end of the path', (tester) async {
      final path = Path()..lineTo(100, 0);
      await tester.pumpWidget(_app(
        NibPathMotion(path: path, repeat: true, child: _box),
        reduced: true,
      ));
      await tester.pump();
      expect(_render<RenderNibPathMotion>(tester).progress.value, 1.0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibPathMotion animates when not reduced', (tester) async {
      final path = Path()..lineTo(100, 0);
      await tester.pumpWidget(_app(
        NibPathMotion(path: path, child: _box),
        reduced: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_render<RenderNibPathMotion>(tester).progress.value,
          inExclusiveRange(0.0, 1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('NibDrawPath is fully drawn at once', (tester) async {
      final path = Path()..lineTo(100, 0);
      await tester.pumpWidget(_app(NibDrawPath(path: path), reduced: true));
      await tester.pump();
      expect(_render<RenderNibDrawPath>(tester).progress.value, 1.0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibFlip toggles instantly', (tester) async {
      Widget w(bool flipped) => _app(
            NibFlip(front: _box, back: _box, isFlipped: flipped),
            reduced: true,
          );
      await tester.pumpWidget(w(false));
      await tester.pumpWidget(w(true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibFlip animates when not reduced', (tester) async {
      Widget w(bool flipped) => _app(
            NibFlip(front: _box, back: _box, isFlipped: flipped),
            reduced: false,
          );
      await tester.pumpWidget(w(false));
      await tester.pumpWidget(w(true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('NibDissolve completes immediately and reports it',
        (tester) async {
      var done = 0;
      await tester.pumpWidget(_app(
        NibDissolve(onComplete: () => done++, child: _box),
        reduced: true,
      ));
      await tester.pump();
      expect(done, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reduced motion: gestures follow the finger but settle instantly', () {
    testWidgets('NibDraggable snapBack jumps home', (tester) async {
      await tester.pumpWidget(_app(
        const NibDraggable(snapBack: true, child: _box),
        reduced: true,
      ));
      final g = await tester.startGesture(const Offset(30, 30));
      await g.moveBy(const Offset(80, 0));
      await tester.pump();
      expect((_named(tester, '_RenderNibDraggable').x.value as double), 80,
          reason: 'finger-following is essential and stays');
      await g.up();
      await tester.pump();
      expect((_named(tester, '_RenderNibDraggable').x.value as double), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibDraggable snapBack springs when not reduced',
        (tester) async {
      await tester.pumpWidget(_app(
        const NibDraggable(snapBack: true, child: _box),
        reduced: false,
      ));
      final g = await tester.startGesture(const Offset(30, 30));
      await g.moveBy(const Offset(80, 0));
      await g.up();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('NibPinch snaps back to initial scale', (tester) async {
      await tester.pumpWidget(_app(
        const NibPinch(snapBackOnRelease: true, child: _box),
        reduced: true,
      ));
      final a = await tester.startGesture(const Offset(20, 30));
      final b = await tester.startGesture(const Offset(40, 30));
      await a.moveTo(const Offset(0, 30));
      await b.moveTo(const Offset(60, 30));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      expect((_named(tester, '_RenderNibPinch').scale.value as double), 1.0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibSwipeDismiss dismisses without a fling animation',
        (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(_app(
        SizedBox(
          width: 200,
          height: 60,
          child: NibSwipeDismiss(
              onDismissed: () => dismissed++, child: const SizedBox.expand()),
        ),
        reduced: true,
      ));
      await tester.drag(find.byType(NibSwipeDismiss), const Offset(150, 0));
      await tester.pump();
      expect(dismissed, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('NibSwipeDismiss below threshold returns instantly',
        (tester) async {
      await tester.pumpWidget(_app(
        SizedBox(
          width: 200,
          height: 60,
          child: NibSwipeDismiss(
              onDismissed: () {}, child: const SizedBox.expand()),
        ),
        reduced: true,
      ));
      await tester.drag(find.byType(NibSwipeDismiss), const Offset(30, 0));
      await tester.pump();
      expect((_named(tester, '_RenderNibSwipeDismiss').offset.value as double),
          0.0);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reduced motion: nav bar', () {
    Widget bar(int index, {required bool reduced}) => _app(
          SizedBox(
            width: 300,
            child: NibNavBar(
              currentIndex: index,
              onIndexChanged: (_) {},
              items: const [
                NibNavItem(icon: Icon(Icons.home)),
                NibNavItem(icon: Icon(Icons.search)),
              ],
            ),
          ),
          reduced: reduced,
        );

    testWidgets('indicator jumps to the new tab', (tester) async {
      await tester.pumpWidget(bar(0, reduced: true));
      await tester.pump();
      await tester.pumpWidget(bar(1, reduced: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('indicator springs when not reduced', (tester) async {
      await tester.pumpWidget(bar(0, reduced: false));
      await tester.pump();
      await tester.pumpWidget(bar(1, reduced: false));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
    });
  });
}
