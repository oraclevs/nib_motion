import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: Center(child: child));
}

/// Returns every [RenderNibMotion] in the tree, in depth-first build order
/// (so the outermost `NibMotion` comes first, then its descendants).
List<RenderNibMotion> _findRenderNibMotions(WidgetTester tester) {
  final found = <RenderNibMotion>[];
  void visit(RenderObject object) {
    if (object is RenderNibMotion) found.add(object);
    object.visitChildren(visit);
  }

  tester.binding.rootElement!.renderObject!.visitChildren(visit);
  return found;
}

const _variants = {'hidden': NibAnim(opacity: 0), 'visible': NibAnim(opacity: 1)};

void main() {
  group('NibMotion variants', () {
    testWidgets('parent animate "visible" propagates to descendant with matching variant', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: 'hidden',
            animate: 'visible',
            variants: _variants,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: NibMotion(
              initial: 'hidden',
              variants: _variants,
              transition: const NibTransition(duration: Duration(milliseconds: 50)),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final motions = _findRenderNibMotions(tester);
      expect(motions[0].opacity.value, closeTo(1.0, 0.001));
      expect(motions[1].opacity.value, closeTo(1.0, 0.001));
    });

    testWidgets('parent animate "hidden" propagates descendant to hidden variant', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: 'visible',
            animate: 'hidden',
            variants: _variants,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: NibMotion(
              initial: 'visible',
              variants: _variants,
              transition: const NibTransition(duration: Duration(milliseconds: 50)),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final motions = _findRenderNibMotions(tester);
      expect(motions[0].opacity.value, closeTo(0.0, 0.001));
      expect(motions[1].opacity.value, closeTo(0.0, 0.001));
    });

    testWidgets('child with no variants ignores the parent variant and uses its own animate', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: 'hidden',
            animate: 'visible',
            variants: _variants,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: NibMotion(
              initial: const NibAnim(scale: 0.5),
              animate: const NibAnim(scale: 2.0),
              transition: const NibTransition(duration: Duration(milliseconds: 50)),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final motions = _findRenderNibMotions(tester);
      expect(motions[1].scaleX.value, closeTo(2.0, 0.001));
      // The child has no `variants`, so the parent's "visible" variant never
      // touches its opacity — it stays at the identity value.
      expect(motions[1].opacity.value, closeTo(1.0, 0.001));
    });

    testWidgets('staggerChildren delays later descendants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: 'hidden',
            animate: 'visible',
            variants: _variants,
            transition: const NibTransition(
              duration: Duration(milliseconds: 100),
              staggerChildren: Duration(milliseconds: 100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NibMotion(
                  initial: 'hidden',
                  variants: _variants,
                  transition: const NibTransition(duration: Duration(milliseconds: 100)),
                  child: const SizedBox(width: 10, height: 10),
                ),
                NibMotion(
                  initial: 'hidden',
                  variants: _variants,
                  transition: const NibTransition(duration: Duration(milliseconds: 100)),
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final motions = _findRenderNibMotions(tester);
      expect(motions[1].opacity.value, greaterThan(0.0));
      expect(motions[2].opacity.value, 0.0);
    });

    testWidgets('unknown variant name on child does nothing (no crash)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NibMotion(
            initial: 'hidden',
            animate: 'visible',
            variants: _variants,
            transition: const NibTransition(duration: Duration(milliseconds: 50)),
            child: NibMotion(
              initial: const NibAnim(scale: 1.0),
              variants: const {'shown': NibAnim(scale: 2.0)},
              transition: const NibTransition(duration: Duration(milliseconds: 50)),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final motions = _findRenderNibMotions(tester);
      expect(motions[1].scaleX.value, closeTo(1.0, 0.001));
    });
  });
}
