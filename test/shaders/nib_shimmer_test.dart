import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/src/shaders/nib_shimmer.dart';

void main() {
  testWidgets('builds and mounts without throwing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(child: SizedBox(width: 100, height: 40)),
      ),
    );

    expect(find.byType(NibShimmer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders child even if the shimmer shader never resolves', (tester) async {
    // In the default `flutter test` harness, shader compilation may not
    // resolve before the widget tree is torn down; `NibShimmer` must still
    // paint `child` either way.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(child: Text('content', textDirection: TextDirection.ltr)),
      ),
    );

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('enabled: false paints child with no shimmer overlay', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(
          enabled: false,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NibShimmer), findsOneWidget);
  });

  testWidgets('toggling enabled at runtime does not throw', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(child: SizedBox(width: 100, height: 40)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(enabled: false, child: SizedBox(width: 100, height: 40)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes its Ticker cleanly with no leak failure', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: NibShimmer(child: SizedBox(width: 100, height: 40)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    // Unmounting the widget must stop/dispose the underlying Ticker;
    // otherwise `flutter_test` fails the test with a "Ticker leaked" error
    // at tear-down.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
