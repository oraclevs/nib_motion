import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/shaders/nib_dissolve.dart';

void main() {
  testWidgets('builds and mounts without throwing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibDissolve(child: SizedBox(width: 100, height: 40)),
      ),
    );

    expect(find.byType(NibDissolve), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a plain opacity fade while the shader is unresolved', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibDissolve(child: Text('content', textDirection: TextDirection.ltr)),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('outward direction starts fully visible and animates over its duration', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibDissolve(
          duration: Duration(milliseconds: 100),
          direction: NibDissolveDirection.outward,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    await tester.pump();
    final initialOpacity = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
    expect(initialOpacity, closeTo(1.0, 0.01));

    await tester.pump(const Duration(milliseconds: 100));
    final finalOpacity = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
    expect(finalOpacity, lessThan(initialOpacity));
  });

  testWidgets('calls onComplete once the dissolve finishes', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NibDissolve(
          duration: const Duration(milliseconds: 50),
          onComplete: () => completed = true,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));
    expect(completed, isTrue);
  });

  testWidgets('disposes its Ticker cleanly with no leak failure', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibDissolve(child: SizedBox(width: 100, height: 40)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
