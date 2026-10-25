import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

final _navKey = GlobalKey<NavigatorState>();

Widget _host({TextDirection dir = TextDirection.ltr, Widget? home}) =>
    Directionality(
      textDirection: dir,
      child: NibMotionConfig(
        reducedMotion: false,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Navigator(
                key: _navKey,
                onGenerateRoute: (settings) => PageRouteBuilder<void>(
                  settings: settings,
                  pageBuilder: (_, __, ___) => home ?? const Text('home'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// The full-screen RenderNibMotion that wraps a route's content.
RenderNibMotion _routeMotion(WidgetTester tester, Finder content) {
  RenderNibMotion? found;
  content.evaluate().single.visitAncestorElements((e) {
    if (e.renderObject is RenderNibMotion) {
      found = e.renderObject! as RenderNibMotion;
      return false;
    }
    return true;
  });
  return found!;
}

const _slowTween =
    NibTransition(duration: Duration(milliseconds: 1000), curve: Curves.linear);

void main() {
  group('route motion is never cut at reverseDuration', () {
    testWidgets('a slow exit keeps the route mounted until it settles',
        (tester) async {
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        transition: _slowTween,
        reverseDuration: const Duration(milliseconds: 100),
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pumpAndSettle();
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('d')), findsOneWidget,
          reason: 'the 1s exit is still playing; route must not be removed');
      final motion = _routeMotion(tester, find.byKey(const ValueKey('d')));
      expect(motion.opacity.value, inExclusiveRange(0.2, 0.8));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });

    testWidgets('a spring exit also outlives a too-short reverseDuration',
        (tester) async {
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        transition: NibTransition(
            spring: NibSpringDescription.fromDuration(
                duration: const Duration(milliseconds: 900), bounce: 0.0)),
        reverseDuration: const Duration(milliseconds: 50),
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('d')),
      );
      await tester.pumpAndSettle();
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('d')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('d')), findsNothing);
    });
  });

  group('edge back-swipe', () {
    Future<NibPageRoute<String>> pushPage(WidgetTester tester,
        {bool backSwipe = true}) async {
      final route = NibPageRoute<String>(
        backSwipe: backSwipe,
        transition: NibTransition.springSnappy,
        builder: (_) => const SizedBox.expand(key: ValueKey('page')),
      );
      _navKey.currentState!.push(route);
      await tester.pumpAndSettle();
      return route;
    }

    testWidgets('dragging from the start edge moves the page with the finger',
        (tester) async {
      await tester.pumpWidget(_host());
      await pushPage(tester);
      final motion = _routeMotion(tester, find.byKey(const ValueKey('page')));
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(motion.translateX.value, closeTo(100, 8));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a short slow drag cancels and springs back', (tester) async {
      await tester.pumpWidget(_host());
      await pushPage(tester);
      final motion = _routeMotion(tester, find.byKey(const ValueKey('page')));
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(30, 0),
          timeStamp: const Duration(milliseconds: 100));
      await g.moveBy(const Offset(30, 0),
          timeStamp: const Duration(milliseconds: 600));
      await g.up(timeStamp: const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
      expect(motion.translateX.value, closeTo(0, 0.5));
    });

    testWidgets('dragging past half the width pops the route', (tester) async {
      await tester.pumpWidget(_host());
      final route = await pushPage(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(120, 0));
      await g.moveBy(const Offset(120, 0));
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsNothing);
      expect(route.isActive, isFalse);
    });

    testWidgets('a fast fling pops even after a short drag', (tester) async {
      await tester.pumpWidget(_host());
      await pushPage(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(25, 0),
          timeStamp: const Duration(milliseconds: 8));
      await g.moveBy(const Offset(25, 0),
          timeStamp: const Duration(milliseconds: 16));
      await g.moveBy(const Offset(25, 0),
          timeStamp: const Duration(milliseconds: 24));
      await g.up(timeStamp: const Duration(milliseconds: 25));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsNothing);
    });

    testWidgets('the commit continues from the dragged position (no jump)',
        (tester) async {
      await tester.pumpWidget(_host());
      await pushPage(tester);
      final motion = _routeMotion(tester, find.byKey(const ValueKey('page')));
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(120, 0));
      await g.moveBy(const Offset(120, 0));
      final before = motion.translateX.value;
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(motion.translateX.value, greaterThanOrEqualTo(before - 2),
          reason: 'keeps heading off-screen, never snaps back to 0');
      await tester.pumpAndSettle();
    });

    testWidgets('RTL: the edge is on the right and the page goes left',
        (tester) async {
      await tester.pumpWidget(_host(dir: TextDirection.rtl));
      await pushPage(tester);
      final motion = _routeMotion(tester, find.byKey(const ValueKey('page')));
      // A drag from the LEFT edge does nothing in RTL.
      final wrong = await tester.startGesture(const Offset(5, 300));
      await wrong.moveBy(const Offset(60, 0));
      await wrong.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(motion.translateX.value, 0);
      await wrong.up();
      await tester.pumpAndSettle();

      final g = await tester.startGesture(const Offset(395, 300));
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-70, 0));
      await tester.pump();
      expect(motion.translateX.value, closeTo(-100, 8));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('disabled by default: edge drags do nothing', (tester) async {
      await tester.pumpWidget(_host());
      await pushPage(tester, backSwipe: false);
      final motion = _routeMotion(tester, find.byKey(const ValueKey('page')));
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(60, 0));
      await g.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(motion.translateX.value, 0);
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
    });

    testWidgets('taps in the edge strip still reach the page', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host());
      _navKey.currentState!.push(NibPageRoute<void>(
        backSwipe: true,
        builder: (_) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox.expand(key: ValueKey('page')),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 300));
      expect(taps, 1);
    });
  });

  group('shared-element hand-off (sharedFrom)', () {
    testWidgets('the route content grows out of the source and returns to it',
        (tester) async {
      final source = GlobalKey();
      await tester.pumpWidget(_host(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, top: 30),
            child: SizedBox(key: source, width: 40, height: 40),
          ),
        ),
      ));
      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: source,
        transition: _slowTween,
        builder: (_) =>
            const SizedBox(width: 200, height: 100, key: ValueKey('dlg')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The painted *centre* (the box's size is its unscaled layout size).
      Offset paintedCenter() {
        final box =
            tester.renderObject<RenderBox>(find.byKey(const ValueKey('dlg')));
        return box.localToGlobal(box.size.center(Offset.zero));
      }

      // Start: painted on top of the source (centre ~ (40, 50)).
      final start = paintedCenter();
      expect(start.dx, closeTo(40, 12));
      expect(start.dy, closeTo(50, 12));
      // End: at its natural centred position.
      await tester.pumpAndSettle();
      final end = paintedCenter();
      expect(end.dx, closeTo(200, 1));
      expect(end.dy, closeTo(300, 1));

      // Pop: heads back toward the source before removal.
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final mid = paintedCenter();
      expect(mid.dx, lessThan(end.dx - 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dlg')), findsNothing);
    });

    testWidgets('a missing/unmounted source falls back to the normal motion',
        (tester) async {
      final source = GlobalKey();
      await tester.pumpWidget(_host());
      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: source, // never attached
        builder: (_) =>
            const SizedBox(width: 50, height: 50, key: ValueKey('dlg')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dlg')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
