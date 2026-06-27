import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester, Key key) {
  final element = find.byKey(key).evaluate().single;
  final root = element.renderObject!;
  if (root is RenderNibMotion) return root;

  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found!;
}

void main() {
  group('NibPresence', () {
    testWidgets('child added plays its enter animation', (tester) async {
      await tester.pumpWidget(_wrap(const NibPresence(children: [])));

      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 0.0),
                animate: const NibAnim(opacity: 1.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester, const ValueKey('a'));
      expect(renderObject.opacity.value, 0.0);

      await tester.pumpAndSettle();
      expect(renderObject.opacity.value, 1.0);
    });

    testWidgets('child removed plays its exit animation before disappearing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const NibPresence(children: [])));

      // Still mounted right after removal -- exit animation is running.
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      final renderObject = _findRenderNibMotion(tester, const ValueKey('a'));
      expect(renderObject.opacity.value, 1.0);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('child removed without an exit animation is removed immediately', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(key: const ValueKey('a'), initial: const NibAnim(opacity: 1.0), child: const SizedBox(width: 50, height: 50)),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const NibPresence(children: [])));
      await tester.pump();

      expect(find.byKey(const ValueKey('a')), findsNothing);
    });

    testWidgets('removing one child does not affect the other', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
              NibMotion(key: const ValueKey('b'), initial: const NibAnim(opacity: 1.0), child: const SizedBox(width: 50, height: 50)),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(key: const ValueKey('b'), initial: const NibAnim(opacity: 1.0), child: const SizedBox(width: 50, height: 50)),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);

      final renderB = _findRenderNibMotion(tester, const ValueKey('b'));
      expect(renderB.opacity.value, 1.0);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a')), findsNothing);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(renderB.opacity.value, 1.0);
    });

    testWidgets('child removed then re-added before exit completes cancels the exit', (tester) async {
      Widget buildWithChild() {
        return _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 100)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        );
      }

      Widget buildWithoutChild() => _wrap(const NibPresence(children: []));

      await tester.pumpWidget(buildWithChild());

      await tester.pumpWidget(buildWithoutChild());
      await tester.pump(const Duration(milliseconds: 20));

      // Re-add before the 100ms exit animation completes.
      await tester.pumpWidget(buildWithChild());

      expect(find.byKey(const ValueKey('a')), findsOneWidget);

      // Let any pending exit-completion callback run -- entry must remain.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('a')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
    });

    testWidgets('removing all children plays exit animations concurrently', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
              NibMotion(
                key: const ValueKey('b'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const NibPresence(children: [])));

      expect(find.byKey(const ValueKey('a')), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('a')), findsNothing);
      expect(find.byKey(const ValueKey('b')), findsNothing);
    });

    testWidgets('register/unregister lifecycle has no lingering references after dispose', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(key: const ValueKey('a'), initial: const NibAnim(opacity: 1.0), child: const SizedBox(width: 50, height: 50)),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const NibPresence(children: [])));
      await tester.pump();

      expect(find.byKey(const ValueKey('a')), findsNothing);

      // Re-add a different NibMotion with the same key, this time with an
      // exit animation -- a stale registry entry would break this.
      await tester.pumpWidget(
        _wrap(
          NibPresence(
            children: [
              NibMotion(
                key: const ValueKey('a'),
                initial: const NibAnim(opacity: 1.0),
                exit: const NibAnim(opacity: 0.0),
                transition: const NibTransition(duration: Duration(milliseconds: 50)),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const NibPresence(children: [])));

      expect(find.byKey(const ValueKey('a')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a')), findsNothing);
    });
  });
}
