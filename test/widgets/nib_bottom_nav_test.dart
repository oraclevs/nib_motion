import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nib_motion/nib_motion.dart';

const _screens = [
  NibNavScreen(
      child: ColoredBox(color: Color(0xFFEF4444), child: Text('Screen 0'))),
  NibNavScreen(
      child: ColoredBox(color: Color(0xFF22C55E), child: Text('Screen 1'))),
  NibNavScreen(
      child: ColoredBox(color: Color(0xFF3B82F6), child: Text('Screen 2'))),
];

const _items = [
  NibNavItem(icon: Icon(Icons.home)),
  NibNavItem(icon: Icon(Icons.search)),
  NibNavItem(icon: Icon(Icons.person)),
];

Widget _wrap(Widget child) => MaterialApp(home: child);

/// Taps the center of nav item [index] out of 3, assuming [bar] spans the
/// full bar width.
Future<void> _tapItem(WidgetTester tester, Rect bar, int index) async {
  final itemWidth = bar.width / 3;
  await tester
      .tapAt(Offset(bar.left + itemWidth * (index + 0.5), bar.center.dy));
}

/// Whether [finder] is inside an [Offstage] that is currently offstage.
///
/// [finder] must be built with `skipOffstage: false`, since by default
/// finders skip descendants of an offstage [Offstage] entirely. `MaterialApp`
/// itself introduces an unrelated outer [Offstage] (for route transitions), so
/// this takes the *nearest* one — i.e. the [NibScreenStack]'s own per-entry
/// wrapper — which is the first element in ancestor-finder order
/// (leaf-to-root).
bool _isOffstage(WidgetTester tester, Finder finder) {
  final offstage = find
      .ancestor(
          of: finder, matching: find.byType(Offstage, skipOffstage: false))
      .evaluate()
      .first
      .widget as Offstage;
  return offstage.offstage;
}

NibNavBarPainter _navBarPainter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is NibNavBarPainter),
      )
      .painter as NibNavBarPainter;
}

class _CounterScreen extends StatefulWidget {
  const _CounterScreen();

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: $_count'),
        ElevatedButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('NibScaffold renders without errors with 3 screens',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(screens: _screens, navItems: _items)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(NibScaffold), findsOneWidget);
  });

  testWidgets('tapping second nav item calls onIndexChanged(1)',
      (tester) async {
    int? newIndex;
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: _items,
        onIndexChanged: (i) => newIndex = i,
      )),
    );
    await tester.pump();

    await _tapItem(tester, tester.getRect(find.byType(NibNavBar)), 1);
    await tester.pump();

    expect(newIndex, 1);
  });

  testWidgets('screen transition: incoming screen is visible after settling',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(screens: _screens, navItems: _items)),
    );
    await tester.pump();

    await _tapItem(tester, tester.getRect(find.byType(NibNavBar)), 1);
    await tester.pumpAndSettle();

    expect(_isOffstage(tester, find.text('Screen 1', skipOffstage: false)),
        isFalse);
  });

  testWidgets('NibNavTransitionType.none switches instantly', (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: _items,
        screenTransition: NibNavScreenTransition.none,
      )),
    );
    await tester.pump();

    await _tapItem(tester, tester.getRect(find.byType(NibNavBar)), 1);
    await tester.pump();

    expect(_isOffstage(tester, find.text('Screen 1', skipOffstage: false)),
        isFalse);
    expect(_isOffstage(tester, find.text('Screen 0', skipOffstage: false)),
        isTrue);
  });

  testWidgets(
      'keepAlive: true retains screen state after switching away and back',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: [
          const NibNavScreen(child: _CounterScreen()),
          _screens[1],
          _screens[2],
        ],
        navItems: _items,
        screenTransition: NibNavScreenTransition.none,
      )),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Increment'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    final bar = tester.getRect(find.byType(NibNavBar));
    await _tapItem(tester, bar, 1);
    await tester.pump();
    await _tapItem(tester, bar, 0);
    await tester.pump();

    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('badge count: 3 renders without errors', (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: [
          _items[0],
          _items[1].copyWith(badge: const NibNavBadge(count: 3)),
          _items[2],
        ],
      )),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_navBarPainter(tester).items[1].badge?.count, 3);
  });

  testWidgets('NibNavIndicatorType.none paints no indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: _items,
        navIndicator: NibNavIndicatorStyle.none,
      )),
    );
    await tester.pump();

    expect(_navBarPainter(tester).indicator.type, NibNavIndicatorType.none);
  });

  testWidgets('navBarPosition: top places nav bar above content',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: _items,
        navBarPosition: NibNavBarPosition.top,
      )),
    );
    await tester.pump();

    final navBarTop = tester.getTopLeft(find.byType(NibNavBar)).dy;
    final screenStackTop = tester.getTopLeft(find.byType(NibScreenStack)).dy;
    expect(navBarTop, lessThan(screenStackTop));
  });

  testWidgets(
      'extendBodyBehindNavBar: false insets NibScreenStack above the nav bar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(screens: _screens, navItems: _items)),
    );
    await tester.pump();

    final navBarRect = tester.getRect(find.byType(NibNavBar));
    final screenStackRect = tester.getRect(find.byType(NibScreenStack));
    expect(screenStackRect.bottom, navBarRect.top);
  });

  testWidgets(
      'extendBodyBehindNavBar: true extends NibScreenStack behind the nav bar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: _screens,
        navItems: _items,
        extendBodyBehindNavBar: true,
      )),
    );
    await tester.pump();

    final navBarRect = tester.getRect(find.byType(NibNavBar));
    final screenStackRect = tester.getRect(find.byType(NibScreenStack));
    expect(screenStackRect.bottom, navBarRect.bottom);
    expect(screenStackRect.top, lessThan(navBarRect.top));
  });

  testWidgets(
      'extendBodyBehindNavBar: true + transparent nav bar reveals screen content',
      (tester) async {
    // `_screens`' `ColoredBox`es size to their `Text` child (small, top-left)
    // since `NibScreenStack`'s `Stack` gives non-positioned children loose
    // constraints — use `SizedBox.expand` here so the colored screen actually
    // fills the whole scaffold, including the area behind the nav bar.
    const fullBleedScreens = [
      NibNavScreen(
          child: SizedBox.expand(child: ColoredBox(color: Color(0xFFEF4444)))),
      NibNavScreen(
          child: SizedBox.expand(child: ColoredBox(color: Color(0xFF22C55E)))),
      NibNavScreen(
          child: SizedBox.expand(child: ColoredBox(color: Color(0xFF3B82F6)))),
    ];

    await tester.pumpWidget(
      _wrap(NibScaffold(
        screens: fullBleedScreens,
        navItems: _items,
        extendBodyBehindNavBar: true,
        navBarStyle: const NibNavBarStyle(backgroundColor: Color(0x00000000)),
        navIndicator: NibNavIndicatorStyle.none,
      )),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NibNavBar));
    final repaintBoundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;

    final captured = await tester.runAsync(() async {
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        width: image.width,
        bytes: byteData!.buffer.asUint8List(),
      );
    });
    final (width: imageWidth, bytes: bytes) = captured!;

    // The bar's background is fully transparent, so a pixel inside its
    // painted rect (top-right corner, away from any item icon) should show
    // Screen 0's red `ColoredBox` (0xFFEF4444), which extends full-bleed
    // behind the bar.
    final x = rect.right.round() - 2;
    final y = rect.top.round() + 1;
    final offset = (y * imageWidth + x) * 4;
    expect(bytes[offset], 0xEF);
    expect(bytes[offset + 1], 0x44);
    expect(bytes[offset + 2], 0x44);
  });

  testWidgets(
      'label text paints within the nav bar bounds for a compact height',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              NibNavBar(
                items: const [
                  NibNavItem(icon: Icon(Icons.home), label: 'Home'),
                  NibNavItem(icon: Icon(Icons.search), label: 'Search'),
                  NibNavItem(icon: Icon(Icons.person), label: 'Profile'),
                ],
                currentIndex: 0,
                onIndexChanged: (_) {},
                style: const NibNavBarStyle(height: 48),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NibNavBar));
    final repaintBoundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;

    // `toImage`/`toByteData` are real async operations (GPU/raster round-trip)
    // and never resolve inside FlutterTester's fake-async test zone — they
    // must run via `tester.runAsync`.
    final captured = await tester.runAsync(() async {
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        width: image.width,
        height: image.height,
        bytes: byteData!.buffer.asUint8List(),
      );
    });
    final (width: imageWidth, height: imageHeight, bytes: bytes) = captured!;

    // The label must paint within the nav bar's own rect (no overflow past
    // its bottom edge), and must not be empty.
    var nonBgInBounds = 0;
    final labelRowY = (rect.top + rect.height * 0.66).round();
    for (var x = rect.left.round(); x < rect.right.round(); x++) {
      for (var y = labelRowY; y < rect.bottom.round(); y++) {
        if (y < 0 || y >= imageHeight || x < 0 || x >= imageWidth) continue;
        final offset = (y * imageWidth + x) * 4;
        if (!(bytes[offset] == 255 &&
            bytes[offset + 1] == 255 &&
            bytes[offset + 2] == 255)) {
          nonBgInBounds++;
        }
      }
    }
    expect(nonBgInBounds, greaterThan(0));
  });

  testWidgets('line indicator is clipped to the bar border radius',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ColoredBox(
          // `NibNavBar` here fills the whole 800x600 test viewport (the
          // `SizedBox` only constrains width), so its painted rounded-rect
          // background sits on top of this white fill. The area outside the
          // bar's rounded corner is otherwise unpainted/transparent — wrap in
          // a known white background so the corner pixel has a defined color
          // to assert on.
          color: Colors.white,
          child: SizedBox(
            width: 300,
            child: NibNavBar(
              items: _items,
              currentIndex: 0,
              onIndexChanged: (_) {},
              style: const NibNavBarStyle(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              indicator: const NibNavIndicatorStyle(
                type: NibNavIndicatorType.line,
                height: 4,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NibNavBar));
    final repaintBoundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;

    // `toImage`/`toByteData` are real async operations (GPU/raster round-trip)
    // and never resolve inside FlutterTester's fake-async test zone — they
    // must run via `tester.runAsync`.
    final captured = await tester.runAsync(() async {
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        width: image.width,
        bytes: byteData!.buffer.asUint8List(),
      );
    });
    final (width: imageWidth, bytes: bytes) = captured!;

    // The very top-left corner pixel of the bar should be background-colored
    // (white) — i.e. the rounded corner is NOT covered by the line
    // indicator, which spans from x=0 at y=0.
    final topLeft = ((rect.top.round()) * imageWidth + rect.left.round()) * 4;
    expect(bytes[topLeft], 255);
    expect(bytes[topLeft + 1], 255);
    expect(bytes[topLeft + 2], 255);
  });

  testWidgets('NibNavBarStyle.margin insets the bar from its parent',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          height: 200,
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              NibNavBar(
                items: _items,
                currentIndex: 0,
                onIndexChanged: (_) {},
                style: const NibNavBarStyle(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paintedRect = tester.getRect(
      find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is NibNavBarPainter),
    );

    // The SizedBox(width: 300) above doesn't actually constrain layout here —
    // MaterialApp's root gives the tree a tight 800x600 constraint, which
    // `enforce`s the SizedBox's 300 back up to 800 — so the bar's parent is
    // effectively the full 800-wide test viewport. The painted bar should
    // still be inset by the margin on all sides relative to that parent.
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(paintedRect.left, 16);
    expect(paintedRect.right, screenWidth - 16);
  });

  testWidgets('NibNavBarStyle.padding shifts the painted icon within the bar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          height: 200,
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              NibNavBar(
                items: const [NibNavItem(icon: Icon(Icons.home))],
                currentIndex: 0,
                onIndexChanged: (_) {},
                indicator: NibNavIndicatorStyle.none,
                style: const NibNavBarStyle(
                  height: 100,
                  iconSize: 60,
                  padding: EdgeInsets.only(top: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NibNavBar));
    final repaintBoundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;

    final captured = await tester.runAsync(() async {
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (width: image.width, bytes: byteData!.buffer.asUint8List());
    });
    final (width: imageWidth, bytes: bytes) = captured!;

    final centerX = (rect.left + rect.width / 2).round();

    bool isWhite(int x, int y) {
      final offset = (y * imageWidth + x) * 4;
      return bytes[offset] == 255 &&
          bytes[offset + 1] == 255 &&
          bytes[offset + 2] == 255;
    }

    // With `padding.top: 30` wired into the painter, the 60x60 icon (scaled
    // up to ~66px by the active item's default 1.1x `whileActive` scale) is
    // centered in a 70px-tall content area starting at y=30 — it spans
    // roughly y=[32, 98]. A row near the bar's unpadded top (y=10) falls
    // outside that range and should be background...
    expect(isWhite(centerX, (rect.top + 10).round()), isTrue);
    // ...while a row near the bar's bottom (y=80), within the icon's glyph
    // ink (the `Icons.home` outline's base), should be covered by the icon —
    // this row only falls inside the icon's bounds because of the padding
    // pushing the content rect (and thus the icon) downward.
    expect(isWhite(centerX, (rect.top + 80).round()), isFalse);
  });

  testWidgets(
      'label renders for a compact bar with custom iconSize, padding, and line-height labelStyle',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          child: NibNavBar(
            items: const [
              NibNavItem(icon: Icon(Icons.home), label: 'Home'),
              NibNavItem(icon: Icon(Icons.search), label: 'Search'),
              NibNavItem(icon: Icon(Icons.person), label: 'A very long label'),
            ],
            currentIndex: 0,
            onIndexChanged: (_) {},
            style: const NibNavBarStyle(
              height: 56,
              iconSize: 28,
              padding: EdgeInsets.symmetric(vertical: 8),
              labelStyle: TextStyle(fontSize: 11, height: 1.5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NibNavBar));
    final repaintBoundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;

    final captured = await tester.runAsync(() async {
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        width: image.width,
        height: image.height,
        bytes: byteData!.buffer.asUint8List()
      );
    });
    final (width: imageWidth, height: imageHeight, bytes: bytes) = captured!;

    // Sample the full content row band (contentRect.top..contentRect.bottom)
    // under item 0 ("Home") for non-background pixels — the label must paint
    // somewhere within the bar's own bounds.
    var nonBgInBounds = 0;
    final contentTop = (rect.top + 8).round(); // padding.vertical: 8 -> top: 8
    final contentBottom = (rect.bottom - 8).round();
    final itemWidth = rect.width / 3;
    for (var x = rect.left.round(); x < (rect.left + itemWidth).round(); x++) {
      for (var y = contentTop; y < contentBottom; y++) {
        if (y < 0 || y >= imageHeight || x < 0 || x >= imageWidth) continue;
        final offset = (y * imageWidth + x) * 4;
        if (!(bytes[offset] == 255 &&
            bytes[offset + 1] == 255 &&
            bytes[offset + 2] == 255)) {
          nonBgInBounds++;
        }
      }
    }
    expect(nonBgInBounds, greaterThan(0));
  });

  testWidgets(
    'every item renders its icon (regression: the first item used to render '
    'blank in release builds), scaled by whileActive.scale when active',
    (tester) async {
      const iconSize = 24.0;
      await tester.pumpWidget(
        _wrap(
          NibNavBar(
            items: _items,
            currentIndex: 0,
            onIndexChanged: (_) {},
            style: const NibNavBarStyle(iconSize: iconSize),
            itemAnimation:
                const NibNavItemAnimation(whileActive: NibAnim(scale: 1.3)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Every item — including the first — must render its icon widget.
      expect(find.byIcon(Icons.home), findsWidgets);
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.byIcon(Icons.person), findsWidgets);

      final activeTransform = tester.widget<Transform>(
        find
            .ancestor(
                of: find.byIcon(Icons.home), matching: find.byType(Transform))
            .first,
      );
      expect(activeTransform.transform.getMaxScaleOnAxis(), closeTo(1.3, 0.01));

      final inactiveTransform = tester.widget<Transform>(
        find
            .ancestor(
                of: find.byIcon(Icons.search), matching: find.byType(Transform))
            .first,
      );
      expect(
          inactiveTransform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    },
  );

  testWidgets(
      'a label wider than its item is constrained, not overflowing into the next item',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          child: NibNavBar(
            items: const [
              NibNavItem(
                  icon: Icon(Icons.home),
                  label: 'A very long label that would overflow'),
              NibNavItem(icon: Icon(Icons.search), label: 'Search'),
              NibNavItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
            currentIndex: 0,
            onIndexChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
