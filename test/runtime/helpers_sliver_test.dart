import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

Widget _scroll(ScrollController c, List<Widget> slivers) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: CustomScrollView(controller: c, slivers: slivers),
      ),
    );

SliverList _filler() => SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => SizedBox(height: 100, child: Text('row $i')),
        childCount: 30,
      ),
    );

void main() {
  group('NibSliverHeaderDelegate', () {
    testWidgets('exposes shrink progress 0..1 as a MotionValue',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      MotionValue<double>? progress;
      await tester.pumpWidget(_scroll(controller, [
        SliverPersistentHeader(
          pinned: true,
          delegate: NibSliverHeaderDelegate(
            minExtent: 50,
            maxExtent: 200,
            builder: (context, p) {
              progress = p;
              return const SizedBox.expand();
            },
          ),
        ),
        _filler(),
      ]));
      expect(progress!.value, 0.0);
      controller.jumpTo(75);
      await tester.pump();
      expect(progress!.value, closeTo(0.5, 1e-6));
      controller.jumpTo(150);
      await tester.pump();
      expect(progress!.value, 1.0);
      controller.jumpTo(900);
      await tester.pump();
      expect(progress!.value, 1.0, reason: 'clamped once fully collapsed');
      controller.jumpTo(0);
      await tester.pump();
      expect(progress!.value, 0.0);
    });

    testWidgets('scrolling does not rebuild the header content',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var builds = 0;
      var childBuilds = 0;
      await tester.pumpWidget(_scroll(controller, [
        SliverPersistentHeader(
          pinned: true,
          delegate: NibSliverHeaderDelegate(
            minExtent: 50,
            maxExtent: 200,
            builder: (context, p) {
              builds++;
              return NibMotion(
                motionValues:
                    NibMotionValues(opacity: p.mapRange([0, 1], [1, 0.2])),
                child: Builder(builder: (_) {
                  childBuilds++;
                  return const SizedBox.expand();
                }),
              );
            },
          ),
        ),
        _filler(),
      ]));
      final b0 = builds;
      final c0 = childBuilds;
      for (var y = 10.0; y <= 140; y += 10) {
        controller.jumpTo(y);
        await tester.pump();
      }
      expect(builds, b0,
          reason: 'builder runs once; progress is a MotionValue');
      expect(childBuilds, c0);
    });

    testWidgets('drives a NibMotion opacity through mapRange', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scroll(controller, [
        SliverPersistentHeader(
          pinned: true,
          delegate: NibSliverHeaderDelegate(
            minExtent: 50,
            maxExtent: 200,
            builder: (context, p) => NibMotion(
              motionValues:
                  NibMotionValues(opacity: p.mapRange([0, 1], [1, 0])),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        _filler(),
      ]));
      controller.jumpTo(75);
      await tester.pump();
      RenderNibMotion? render;
      void visit(RenderObject o) {
        if (o is RenderNibMotion) render ??= o;
        o.visitChildren(visit);
      }

      tester.binding.rootElement!.renderObject!.visitChildren(visit);
      expect(render!.opacity.value, closeTo(0.5, 1e-6));
    });
  });

  group('NibSliverProgress', () {
    testWidgets('reports collapse progress for a scrolling sliver',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      MotionValue<double>? progress;
      await tester.pumpWidget(_scroll(controller, [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 300,
            child: NibSliverProgress(
              expandedExtent: 300,
              collapsedExtent: 100,
              builder: (context, p) {
                progress = p;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
        _filler(),
      ]));
      await tester.pump();
      expect(progress!.value, 0.0);
      controller.jumpTo(100);
      await tester.pump();
      expect(progress!.value, closeTo(0.5, 1e-6));
      controller.jumpTo(250);
      await tester.pump();
      expect(progress!.value, 1.0);
    });

    testWidgets('accounts for slivers that precede it', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      MotionValue<double>? progress;
      await tester.pumpWidget(_scroll(controller, [
        const SliverToBoxAdapter(child: SizedBox(height: 500)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: NibSliverProgress(
              expandedExtent: 200,
              builder: (context, p) {
                progress = p;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
        _filler(),
      ]));
      await tester.pump();
      controller.jumpTo(300);
      await tester.pump();
      expect(progress!.value, 0.0, reason: 'has not reached its sliver yet');
      controller.jumpTo(600);
      await tester.pump();
      expect(progress!.value, closeTo(0.5, 1e-6));
    });

    testWidgets('detaches from the scroll position on dispose', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_scroll(controller, [
        SliverToBoxAdapter(
          child: NibSliverProgress(
            expandedExtent: 100,
            builder: (context, p) => const SizedBox(height: 100),
          ),
        ),
        _filler(),
      ]));
      await tester.pump();
      // Scrolling after unmount must not reach a disposed progress value.
      controller.jumpTo(10);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
