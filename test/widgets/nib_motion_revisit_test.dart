import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  testWidgets('NibMotion replays initial -> animate when its route becomes visible again after being covered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    NibMotion(
                      initial: const NibAnim(x: -100),
                      animate: const NibAnim(x: 0),
                      transition: const NibTransition(duration: Duration(milliseconds: 200)),
                      child: const SizedBox(width: 40, height: 40),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(), body: const Text('B'))),
                      ),
                      child: const Text('go'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    RenderNibMotion render() => tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

    // Initial enter animation completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(render().translateX.value, closeTo(0, 1e-9), reason: 'finished initial enter animation');

    // Navigate away and back.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsNothing);

    await tester.pageBack();
    await tester.pump();

    expect(render().translateX.value, closeTo(-100, 1e-9), reason: 'replayed initial state on return');

    await tester.pump(const Duration(milliseconds: 300));
    expect(render().translateX.value, closeTo(0, 1e-9), reason: 'replayed animate completes');
  });
}
