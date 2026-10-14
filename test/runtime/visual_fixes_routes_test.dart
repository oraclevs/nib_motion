import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

final _navKey = GlobalKey<NavigatorState>();
const _home = ValueKey('home');
const _page = ValueKey('page');

Widget _host() => Directionality(
      textDirection: TextDirection.ltr,
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
                  pageBuilder: (_, __, ___) =>
                      const ColoredBox(key: _home, color: Color(0xFF3366CC)),
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// Whether the home page is on stage. `find` skips offstage content using the
/// framework's own rule, which covers the overlay's skipped (non-painted)
/// entries as well as `Offstage` widgets.
bool _homeOnStage(WidgetTester tester) =>
    find.byKey(_home).evaluate().isNotEmpty;

Future<void> _push(WidgetTester tester) async {
  _navKey.currentState!.push(NibPageRoute<void>(
    backSwipe: true,
    transition: NibTransition.springSnappy,
    builder: (_) => const ColoredBox(key: _page, color: Color(0xFFCC6633)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('back-swipe reveals the page underneath', () {
    testWidgets('home is offstage at rest, visible mid-drag', (tester) async {
      await tester.pumpWidget(_host());
      await _push(tester);
      expect(_homeOnStage(tester), isFalse, reason: 'opaque page covers it');

      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(110, 0));
      await tester.pump();
      expect(_homeOnStage(tester), isTrue,
          reason: 'the route below must be painted while the page slides away');
      expect(_navKey.currentState!.userGestureInProgress, isTrue);

      // Cancel: slow short release springs back.
      await g.up();
      await tester.pumpAndSettle();
      expect(_navKey.currentState!.userGestureInProgress, isFalse);
      expect(_homeOnStage(tester), isFalse,
          reason: 'after cancel the page is opaque again');
      expect(find.byKey(_page), findsOneWidget);
    });

    testWidgets('committing the swipe pops to the home route', (tester) async {
      await tester.pumpWidget(_host());
      await _push(tester);
      final g = await tester.startGesture(const Offset(5, 300));
      await g.moveBy(const Offset(150, 0));
      await g.moveBy(const Offset(150, 0));
      await tester.pump();
      expect(_homeOnStage(tester), isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsNothing);
      expect(_homeOnStage(tester), isTrue);
      expect(_navKey.currentState!.userGestureInProgress, isFalse);
    });
  });
}
