import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

void main() {
  group('NibMotion.whileInView', () {
    testWidgets('amount zero still requires a nonempty intersection',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: const Column(children: [
                SizedBox(height: 900),
                NibMotion(
                  key: ValueKey('zero-threshold'),
                  initial: NibAnim(opacity: 0),
                  whileInView: NibAnim(opacity: 1),
                  viewport: NibInViewConfig(amount: 0),
                  child: SizedBox(height: 100, width: 100),
                ),
                SizedBox(height: 900),
              ]),
            ),
          ),
        ),
      ));
      final render = tester.renderObject<RenderNibMotion>(
          find.byKey(const ValueKey('zero-threshold')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(render.opacity.value, 0);
    });

    testWidgets('uses the clipped scroll viewport, not only screen bounds',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 120,
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: const Row(children: [
                    SizedBox(width: 650),
                    NibMotion(
                      key: ValueKey('clipped-card'),
                      initial: NibAnim(opacity: 0),
                      whileInView: NibAnim(opacity: 1),
                      transition:
                          NibTransition(duration: Duration(milliseconds: 100)),
                      child: SizedBox(height: 100, width: 100),
                    ),
                    SizedBox(width: 650),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ));

      final render = tester.renderObject<RenderNibMotion>(
          find.byKey(const ValueKey('clipped-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(render.opacity.value, 0,
          reason: 'card is within screen width but clipped by its list');

      controller.jumpTo(500);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(render.opacity.value, 1);
    });

    testWidgets('reveals a mounted card moved into view by ancestor layout',
        (tester) async {
      final headerHeight = ValueNotifier<double>(900);
      addTearDown(headerHeight.dispose);
      const card = NibMotion(
        key: ValueKey('layout-card'),
        initial: NibAnim(opacity: 0),
        whileInView: NibAnim(opacity: 1),
        transition: NibTransition(duration: Duration(milliseconds: 200)),
        child: SizedBox(height: 100, width: 100),
      );

      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<double>(
                valueListenable: headerHeight,
                builder: (context, height, child) => Column(children: [
                  SizedBox(height: height),
                  child!,
                  const SizedBox(height: 900),
                ]),
                child: card,
              ),
            ),
          ),
        ),
      ));

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(
          find.byKey(const ValueKey('layout-card')));
      expect(render().opacity.value, 0);

      // The NibMotion element stays mounted and is not updated; only its
      // ancestor changes size. This also occurs during list restoration and
      // when recycled slivers settle after a fast direction reversal.
      headerHeight.value = 100;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, 1,
          reason: 'a built, visible card must not remain permanently hidden');
    });

    testWidgets('layout changes preserve once and repeat visibility semantics',
        (tester) async {
      final headerHeight = ValueNotifier<double>(900);
      addTearDown(headerHeight.dispose);

      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<double>(
                valueListenable: headerHeight,
                builder: (context, height, child) => Column(children: [
                  SizedBox(height: height),
                  child!,
                  const SizedBox(height: 900),
                ]),
                child: const Column(children: [
                  NibMotion(
                    key: ValueKey('once'),
                    initial: NibAnim(opacity: 0),
                    whileInView: NibAnim(opacity: 1),
                    viewport: NibInViewConfig(once: true),
                    transition:
                        NibTransition(duration: Duration(milliseconds: 100)),
                    child: SizedBox(height: 100, width: 100),
                  ),
                  NibMotion(
                    key: ValueKey('repeat'),
                    initial: NibAnim(opacity: 0),
                    whileInView: NibAnim(opacity: 1),
                    viewport: NibInViewConfig(once: false),
                    transition:
                        NibTransition(duration: Duration(milliseconds: 100)),
                    child: SizedBox(height: 100, width: 100),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ));

      double opacity(String key) => tester
          .renderObject<RenderNibMotion>(find.byKey(ValueKey(key)))
          .opacity
          .value;
      expect(opacity('once'), 0);
      expect(opacity('repeat'), 0);

      headerHeight.value = 100;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity('once'), 1);
      expect(opacity('repeat'), 1);

      headerHeight.value = 900;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity('once'), 1);
      expect(opacity('repeat'), 0);
    });

    testWidgets('lazy cards reveal after long jump and abrupt reversal',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 120,
              itemExtent: 100,
              itemBuilder: (_, index) => NibMotion(
                key: ValueKey('card-$index'),
                initial: const NibAnim(opacity: 0),
                whileInView: const NibAnim(opacity: 1),
                viewport: const NibInViewConfig(amount: 0.2, once: true),
                transition:
                    const NibTransition(duration: Duration(milliseconds: 100)),
                child: Text('card $index'),
              ),
            ),
          ),
        ),
      ));

      for (final offset in [9500.0, 3000.0, 8700.0, 0.0]) {
        controller.jumpTo(offset);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final visible = find.byType(NibMotion).evaluate().where((element) {
          final rect = tester.getRect(find.byWidget(element.widget));
          return rect.top >= 0 && rect.bottom <= 600;
        });
        expect(visible, isNotEmpty);
        for (final element in visible) {
          final render = tester
              .renderObject<RenderNibMotion>(find.byWidget(element.widget));
          expect(render.opacity.value, 1,
              reason: '${element.widget.key} is built and on screen');
        }
      }
    });

    testWidgets('once-revealed card stays visible after tab ticker resumes',
        (tester) async {
      final controller = ScrollController();
      final tickerEnabled = ValueNotifier<bool>(true);
      addTearDown(controller.dispose);
      addTearDown(tickerEnabled.dispose);

      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          child: ValueListenableBuilder<bool>(
            valueListenable: tickerEnabled,
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: const Column(children: [
                  SizedBox(height: 700),
                  NibMotion(
                    key: ValueKey('tab-card'),
                    initial: NibAnim(opacity: 0),
                    whileInView: NibAnim(opacity: 1),
                    viewport: NibInViewConfig(once: true),
                    transition:
                        NibTransition(duration: Duration(milliseconds: 100)),
                    child: SizedBox(height: 100, width: 100),
                  ),
                  SizedBox(height: 900),
                ]),
              ),
            ),
          ),
        ),
      ));

      RenderNibMotion render() => tester.renderObject<RenderNibMotion>(
          find.byKey(const ValueKey('tab-card')));
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(render().opacity.value, 1);

      controller.jumpTo(0);
      await tester.pump();
      tickerEnabled.value = false;
      await tester.pump();
      tickerEnabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(render().opacity.value, 1,
          reason: 'a once-revealed tab card must not reset to hidden');
    });

    testWidgets('reduced motion reveals immediately after layout change',
        (tester) async {
      final headerHeight = ValueNotifier<double>(900);
      addTearDown(headerHeight.dispose);
      await tester.pumpWidget(MaterialApp(
        home: NibMotionConfig(
          entranceWarmup: Duration.zero,
          reducedMotion: true,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<double>(
                valueListenable: headerHeight,
                builder: (context, height, child) => Column(children: [
                  SizedBox(height: height),
                  child!,
                  const SizedBox(height: 900),
                ]),
                child: const NibMotion(
                  key: ValueKey('reduced-card'),
                  initial: NibAnim(opacity: 0),
                  whileInView: NibAnim(opacity: 1),
                  child: SizedBox(height: 100, width: 100),
                ),
              ),
            ),
          ),
        ),
      ));

      final render = tester.renderObject<RenderNibMotion>(
          find.byKey(const ValueKey('reduced-card')));
      expect(render.opacity.value, 0);
      headerHeight.value = 100;
      await tester.pump();
      expect(render.opacity.value, 1);
    });

    testWidgets(
        'animates when scrolled into view and reverts when scrolled out',
        (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    NibMotion(
                      initial: const NibAnim(opacity: 0),
                      whileInView: const NibAnim(opacity: 1),
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
                      child: const SizedBox(height: 100, width: 100),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      expect(render().opacity.value, closeTo(0, 1e-9),
          reason: 'starts at initial while off-screen');

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'animates to whileInView once scrolled into view');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(0, 1e-9),
          reason: 'reverts to initial once scrolled out of view');
    });

    testWidgets(
        'viewport.once prevents reverting after the widget leaves the viewport',
        (tester) async {
      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    NibMotion(
                      initial: const NibAnim(opacity: 0),
                      whileInView: const NibAnim(opacity: 1),
                      viewport: const NibInViewConfig(once: true),
                      transition: const NibTransition(
                          duration: Duration(milliseconds: 200)),
                      child: const SizedBox(height: 100, width: 100),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'animates to whileInView once scrolled into view');

      controller.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        render().opacity.value,
        closeTo(1, 1e-9),
        reason:
            'stays at whileInView after leaving the viewport with once: true',
      );
    });

    testWidgets(
        'animates when a non-nearest ancestor scroll view brings the widget into view',
        (tester) async {
      // Regression test: a `whileInView` widget inside a horizontal list
      // nested in a vertical scroll view must react to the *outer* scroll
      // view moving it on screen, even though its nearest `Scrollable` (the
      // horizontal list) never scrolls.
      final outerController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: outerController,
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          NibMotion(
                            initial: const NibAnim(opacity: 0),
                            whileInView: const NibAnim(opacity: 1),
                            viewport:
                                const NibInViewConfig(once: false, amount: 0.5),
                            transition: const NibTransition(
                                duration: Duration(milliseconds: 200)),
                            child: const SizedBox(height: 100, width: 100),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      expect(render().opacity.value, closeTo(0, 1e-9),
          reason: 'starts at initial while off-screen');

      outerController.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        render().opacity.value,
        closeTo(1, 1e-9),
        reason: 'animates to whileInView once the outer scroll view reveals it',
      );
    });

    testWidgets('animates immediately when already in view on first frame',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NibMotionConfig(
            entranceWarmup: Duration.zero,
            child: NibMotion(
              initial: const NibAnim(opacity: 0),
              whileInView: const NibAnim(opacity: 1),
              transition:
                  const NibTransition(duration: Duration(milliseconds: 200)),
              child: const SizedBox(height: 100, width: 100),
            ),
          ),
        ),
      );

      RenderNibMotion render() =>
          tester.renderObject<RenderNibMotion>(find.byType(NibMotion));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(render().opacity.value, closeTo(1, 1e-9),
          reason: 'animates to whileInView when visible on mount');
    });
  });
}
