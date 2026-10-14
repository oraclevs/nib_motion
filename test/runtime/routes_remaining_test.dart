import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

final _navKey = GlobalKey<NavigatorState>();

Widget _host({
  TextDirection dir = TextDirection.ltr,
  double parallax = 0.3,
  Widget? homeChild,
}) {
  return Directionality(
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
              onGenerateRoute: (settings) => NibPageRoute<void>(
                settings: settings,
                parallax: parallax,
                initial: NibAnim.identity,
                builder: (_) =>
                    homeChild ??
                    const Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                          key: ValueKey('homeBox'), width: 40, height: 40),
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _homeX(WidgetTester tester) => tester
    .getTopLeft(find.byKey(const ValueKey('homeBox'), skipOffstage: false))
    .dx;

Future<void> _pushDetail(WidgetTester tester, {bool backSwipe = true}) async {
  _navKey.currentState!.push(NibPageRoute<void>(
    backSwipe: backSwipe,
    initial: NibAnim.identity,
    transition: NibTransition.springSnappy,
    builder: (_) => const SizedBox.expand(key: ValueKey('detail')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('back-swipe parallax of the route below', () {
    testWidgets('the page below slides in from the side as the top page drags',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      expect(_homeX(tester), 0, reason: 'idle: no parallax offset');

      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(70, 0));
      await tester.pump();
      // top page ~100px right => fraction 0.25 => -0.3 * 400 * 0.75 = -90
      expect(_homeX(tester), inExclusiveRange(-100.0, -80.0));

      await g.moveBy(const Offset(100, 0));
      await tester.pump();
      // ~200px => fraction 0.5 => -60: it keeps moving toward 0 with the drag.
      expect(_homeX(tester), inExclusiveRange(-70.0, -50.0));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('parallax: 0 on the route below disables it', (tester) async {
      await tester.pumpWidget(_host(parallax: 0));
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(_homeX(tester), 0);
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('RTL mirrors the direction', (tester) async {
      await tester.pumpWidget(_host(dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      final g = await tester.startGesture(const Offset(395, 300));
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-70, 0));
      await tester.pump();
      expect(_homeX(tester), inExclusiveRange(80.0, 100.0));
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a cancelled swipe leaves the page below at rest',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(30, 0),
          timeStamp: const Duration(milliseconds: 100));
      await g.moveBy(const Offset(30, 0),
          timeStamp: const Duration(milliseconds: 600));
      await g.up(timeStamp: const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail')), findsOneWidget);
      expect(_homeX(tester), 0);
    });

    testWidgets(
        'a committed swipe ends with the page below at rest and '
        'current, moving monotonically', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(60, 0),
          timeStamp: const Duration(milliseconds: 8));
      await g.moveBy(const Offset(60, 0),
          timeStamp: const Duration(milliseconds: 16));
      await g.moveBy(const Offset(60, 0),
          timeStamp: const Duration(milliseconds: 24));
      await g.up(timeStamp: const Duration(milliseconds: 25));
      await tester.pump();
      var previous = _homeX(tester);
      expect(previous, lessThan(0));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final x = _homeX(tester);
        expect(x, greaterThanOrEqualTo(previous - 0.01),
            reason: 'follows the departing page toward rest');
        previous = x;
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail')), findsNothing);
      expect(_homeX(tester), 0);
    });

    testWidgets(
        'a normal (non-swipe) push or pop never offsets the page '
        'below', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await _pushDetail(tester, backSwipe: false);
      expect(_homeX(tester), 0);
      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_homeX(tester), 0);
      await tester.pumpAndSettle();
    });
  });

  group('sharedFrom hides its source while the route is open', () {
    final source = GlobalKey();

    Widget homeWithSource() => Center(
          child: NibSharedSource(
            sourceKey: source,
            child: const SizedBox(key: ValueKey('src'), width: 80, height: 80),
          ),
        );

    double sourceOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.ancestor(
            of: find.byKey(const ValueKey('src')),
            matching: find.byType(Opacity)))
        .opacity;

    testWidgets('hidden once the route enters, restored when it is gone',
        (tester) async {
      await tester.pumpWidget(_host(homeChild: homeWithSource()));
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 1);

      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: source,
        builder: (_) =>
            const SizedBox(key: ValueKey('content'), width: 200, height: 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(sourceOpacity(tester), 0);
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 0, reason: 'still open');

      _navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(sourceOpacity(tester), 0,
          reason: 'not shown until the content is back over it');
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 1);
    });

    testWidgets(
        'popping before the route finished entering still restores '
        'the source', (tester) async {
      await tester.pumpWidget(_host(homeChild: homeWithSource()));
      await tester.pumpAndSettle();
      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: source,
        builder: (_) => const SizedBox(width: 200, height: 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 1);
    });

    testWidgets(
        'two routes sharing one source: shown only when both are '
        'gone', (tester) async {
      await tester.pumpWidget(_host(homeChild: homeWithSource()));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        showNibDialog<void>(
          context: _navKey.currentContext!,
          sharedFrom: source,
          builder: (_) => const SizedBox(width: 200, height: 200),
        );
        await tester.pumpAndSettle();
      }
      expect(sourceOpacity(tester), 0);
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 0, reason: 'one route still open');
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sourceOpacity(tester), 1);
    });

    testWidgets('a plain GlobalKey (no NibSharedSource) still works',
        (tester) async {
      final plain = GlobalKey();
      await tester.pumpWidget(_host(
        homeChild: Center(child: SizedBox(key: plain, width: 80, height: 80)),
      ));
      await tester.pumpAndSettle();
      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: plain,
        builder: (_) =>
            const SizedBox(key: ValueKey('content'), width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('content')), findsOneWidget);
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a source that unmounted while the route is open is safe',
        (tester) async {
      await tester.pumpWidget(_host(homeChild: homeWithSource()));
      await tester.pumpAndSettle();
      showNibDialog<void>(
        context: _navKey.currentContext!,
        sharedFrom: source,
        builder: (_) => const SizedBox(width: 200, height: 200),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(homeChild: const SizedBox()));
      _navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
