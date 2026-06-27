import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';
import 'package:nib_motion/src/core/nib_motion_animator.dart';
import 'package:nib_motion/src/presence/presence_scope.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

RenderNibMotion _findRenderNibMotion(WidgetTester tester) {
  RenderNibMotion? found;
  void visit(RenderObject object) {
    if (object is RenderNibMotion) {
      found = object;
      return;
    }
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found!;
}

void main() {
  group('NibMotion', () {
    testWidgets('animate transitions a property from initial to its target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            animate: const NibAnim(opacity: 1.0),
            transition: const NibTransition(duration: Duration(milliseconds: 100)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, 0.0);

      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, 1.0);
    });

    testWidgets('tap down animates toward whileTap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            whileTap: const NibAnim(opacity: 0.5),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);
      expect(renderObject.opacity.value, 1.0);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(NibMotion)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(renderObject.opacity.value, lessThan(1.0));

      await gesture.up();
    });

    testWidgets('tap up reverts to the animate value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            animate: const NibAnim(opacity: 1.0),
            whileTap: const NibAnim(opacity: 0.5),
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(NibMotion)));
      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, closeTo(0.5, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, closeTo(1.0, 0.01));
    });

    testWidgets('hover animates toward whileHover', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0),
            whileHover: const NibAnim(opacity: 0.7),
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.byType(NibMotion)));
      addTearDown(gesture.removePointer);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, closeTo(0.7, 0.01));
    });

    testWidgets('registers with an ancestor NibPresenceScope', (tester) async {
      NibMotionAnimator? registered;
      final registration = NibPresenceRegistration(
        register: (key, animator) => registered = animator,
        unregister: (key) {},
      );

      await tester.pumpWidget(
        _wrap(
          NibPresenceScope(
            registration: registration,
            child: NibMotion(
              key: const ValueKey('exiting'),
              exit: const NibAnim(opacity: 0.0),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      expect(registered, isNotNull);
    });

    testWidgets('dispose cleans up tickers and motion values without error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 0.0),
            animate: const NibAnim(opacity: 1.0),
            transition: NibTransition.springGentle,
            child: const SizedBox(width: 50, height: 50),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilding with a new animate target reuses the same MotionValue instances', (tester) async {
      Widget build(double targetX) {
        return _wrap(
          NibMotion(
            initial: const NibAnim(opacity: 1.0, x: 0.0),
            animate: NibAnim(opacity: 1.0, x: targetX),
            transition: const NibTransition(duration: Duration(milliseconds: 20)),
            child: const SizedBox(width: 50, height: 50),
          ),
        );
      }

      await tester.pumpWidget(build(0.0));
      final renderObject = _findRenderNibMotion(tester);
      final opacityValue = renderObject.opacity;
      final translateXValue = renderObject.translateX;

      await tester.pumpWidget(build(100.0));
      await tester.pumpAndSettle();

      final renderObjectAfter = _findRenderNibMotion(tester);
      expect(renderObjectAfter.opacity, same(opacityValue));
      expect(renderObjectAfter.translateX, same(translateXValue));
      expect(renderObjectAfter.translateX.value, closeTo(100.0, 0.01));
    });

    testWidgets('interrupting a spring animation preserves velocity continuity', (tester) async {
      const spring = NibTransition(spring: NibSpringDescription(stiffness: 50, damping: 4));

      Widget build(double targetX) {
        return _wrap(
          NibMotion(
            initial: const NibAnim(x: 0.0),
            animate: NibAnim(x: targetX),
            transition: spring,
            child: const SizedBox(width: 50, height: 50),
          ),
        );
      }

      await tester.pumpWidget(build(1000.0));
      final renderObject = _findRenderNibMotion(tester);

      await tester.pump(const Duration(milliseconds: 200));
      final beforeA = renderObject.translateX.value;
      await tester.pump(const Duration(milliseconds: 16));
      final beforeB = renderObject.translateX.value;
      final velocityBefore = beforeB - beforeA;

      await tester.pumpWidget(build(2000.0));
      final afterStart = renderObject.translateX.value;
      await tester.pump(const Duration(milliseconds: 16));
      final afterEnd = renderObject.translateX.value;
      final velocityAfter = afterEnd - afterStart;

      expect(afterStart, closeTo(beforeB, 0.01));
      expect(velocityAfter, greaterThan(velocityBefore * 0.5));
    });

    testWidgets('reduced motion via MediaQuery jumps to target immediately', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            NibMotion(
              initial: const NibAnim(opacity: 0.0),
              animate: const NibAnim(opacity: 1.0),
              transition: const NibTransition(duration: Duration(milliseconds: 300)),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      expect(renderObject.opacity.value, 1.0);
    });

    testWidgets('NibMotionConfig.setReducedMotion overrides MediaQuery', (tester) async {
      NibMotionConfig.setReducedMotion(false);
      addTearDown(() => NibMotionConfig.setReducedMotion(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            NibMotion(
              initial: const NibAnim(opacity: 0.0),
              animate: const NibAnim(opacity: 1.0),
              transition: const NibTransition(duration: Duration(milliseconds: 100)),
              child: const SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final renderObject = _findRenderNibMotion(tester);

      expect(renderObject.opacity.value, 0.0);

      await tester.pumpAndSettle();

      expect(renderObject.opacity.value, 1.0);
    });
  });
}
