import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../core/reduced_motion_mixin.dart';
import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../shaders/nib_glass.dart';
import '../shaders/shader_loader.dart';
import '../values/motion_value.dart';
import 'nib_nav_bar_painter.dart';
import 'nib_nav_item.dart';
import 'nib_nav_style.dart';

/// An animated navigation bar that renders [items] as evenly spaced tabs.
///
/// The active-item indicator and the bar's background/labels are driven by
/// [SpringSolver]s writing to [MotionValue]s consumed by [NibNavBarPainter]
/// via `CustomPainter`'s `repaint` listenable — no `setState` occurs on
/// those animation ticks.
///
/// Icons are the one exception: they're real `Icon` widgets positioned over
/// the painter (via [AnimatedBuilder], scoped tightly to just the icon
/// subtree) rather than canvas-painted bitmaps. An earlier version
/// pre-rendered each icon to a [Widget]-rasterized image so it could be
/// scaled crisply for `whileActive`, capturing it from an off-screen
/// `RepaintBoundary` built into this same tree. That capture sat fully
/// occluded behind the painter's `CustomPaint` every frame, and in
/// release/AOT builds the engine can skip rasterizing a layer it determines
/// is fully covered — `toImage()` then intermittently returned blank, most
/// visibly for the first item. Real `Icon` widgets scaled via
/// [Transform.scale] don't need a rasterized-bitmap workaround at all:
/// Skia rasterizes the glyph at the final transformed size, so they stay
/// crisp at any scale with no bitmap, no off-screen capture, and no race.
class NibNavBar extends StatefulWidget {
  /// Creates a navigation bar.
  const NibNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onIndexChanged,
    this.style = NibNavBarStyle.standard,
    this.indicator = const NibNavIndicatorStyle(),
    this.itemAnimation = const NibNavItemAnimation(),
  });

  /// The tabs to render.
  final List<NibNavItem> items;

  /// The index of the currently active tab.
  final int currentIndex;

  /// Called with the tapped item's index whenever the user taps a tab.
  final ValueChanged<int> onIndexChanged;

  /// The visual style of the bar's container.
  final NibNavBarStyle style;

  /// The visual style of the active-item indicator.
  final NibNavIndicatorStyle indicator;

  /// Per-item tap/active animation configuration.
  final NibNavItemAnimation itemAnimation;

  @override
  State<NibNavBar> createState() => _NibNavBarState();
}

class _NibNavBarState extends State<NibNavBar>
    with TickerProviderStateMixin, NibReducedMotionMixin {
  late MotionValue<double> _indicatorX;
  late MotionValue<double> _indicatorWidth;
  late MotionValue<double> _indicatorHeight;
  late MotionValue<double> _indicatorOpacity;

  late List<MotionValue<double>> _itemScales;
  late List<MotionValue<double>> _itemOpacities;

  late SpringSolver _indicatorXSolver;
  late SpringSolver _indicatorWidthSolver;
  late List<SpringSolver> _itemScaleSolvers;
  late List<SpringSolver> _itemOpacitySolvers;

  ui.FragmentShader? _liquidShader;
  late final AnimationController _liquidClock;
  late final MotionValue<double> _liquidPhase;
  late final MotionValue<double> _liquidTail;
  late final SpringSolver _liquidTailSolver;

  Future<void> _loadLiquid() async {
    if (widget.indicator.type != NibNavIndicatorType.liquid ||
        _liquidShader != null) {
      return;
    }
    try {
      final program = await NibShaderLoader.load(
          'packages/nib_motion/lib/shaders/nav_water.frag');
      if (mounted && _liquidShader == null) {
        setState(() => _liquidShader = program.fragmentShader());
      }
    } catch (_) {
      // The painted lens remains usable if a backend cannot load shaders.
    }
  }

  double _lastWidth = 0;
  bool _hasLaidOut = false;

  @override
  void initState() {
    super.initState();

    _indicatorX = motionValue(0);
    _indicatorWidth = motionValue(0);
    _indicatorHeight = motionValue(_indicatorHeightValue);
    _indicatorOpacity = motionValue(_indicatorOpacityValue);

    _indicatorXSolver = SpringSolver(
      vsync: this,
      value: _indicatorX,
      spring: widget.indicator.spring,
    );
    _indicatorWidthSolver = SpringSolver(
      vsync: this,
      value: _indicatorWidth,
      spring: widget.indicator.spring,
    );

    _liquidPhase = motionValue(1);
    _liquidTail = motionValue(0);
    _liquidTailSolver = SpringSolver(
      vsync: this,
      value: _liquidTail,
      spring: const NibSpringDescription(stiffness: 100, damping: 18),
    );
    _liquidClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
      value: 1,
    )..addListener(() => _liquidPhase.value = _liquidClock.value);
    _loadLiquid();
    _initItemMotion();
  }

  @override
  void didUpdateWidget(covariant NibNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLiquid();

    if (widget.items.length != oldWidget.items.length) {
      _disposeItemMotion();
      _initItemMotion();
      if (_hasLaidOut) _syncIndicatorToCurrentIndex();
    }

    if (widget.indicator != oldWidget.indicator ||
        widget.style != oldWidget.style) {
      _indicatorHeight.value = _indicatorHeightValue;
      _indicatorOpacity.value = _indicatorOpacityValue;
      _indicatorXSolver.spring = widget.indicator.spring;
      _indicatorWidthSolver.spring = widget.indicator.spring;
      if (_hasLaidOut) _syncIndicatorToCurrentIndex();
    }

    if (widget.currentIndex != oldWidget.currentIndex) {
      _animateIndicatorTo(widget.currentIndex);
      _animateActiveItem(oldWidget.currentIndex, widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _liquidClock.dispose();
    _liquidTailSolver.dispose();
    _liquidTail.dispose();
    _liquidPhase.dispose();
    _liquidShader?.dispose();
    _indicatorXSolver.dispose();
    _indicatorWidthSolver.dispose();
    _disposeItemMotion();
    _indicatorX.dispose();
    _indicatorWidth.dispose();
    _indicatorHeight.dispose();
    _indicatorOpacity.dispose();
    super.dispose();
  }

  @override
  void onReducedMotionChanged(bool reduced) {
    if (!reduced) return;
    _liquidClock.stop();
    _liquidClock.value = 1;
    _syncIndicatorToCurrentIndex();
    for (var i = 0; i < widget.items.length; i++) {
      _go(
          _itemScaleSolvers[i],
          _itemScales[i],
          i == widget.currentIndex
              ? (widget.itemAnimation.whileActive?.scale ?? 1)
              : 1);
      _go(_itemOpacitySolvers[i], _itemOpacities[i],
          i == widget.currentIndex ? 1 : 0);
    }
  }

  // ---------------------------------------------------------------------
  // Motion value setup
  // ---------------------------------------------------------------------

  void _initItemMotion() {
    final tapSpring = widget.itemAnimation.tapTransition.spring ??
        NibSpringDescription.snappy;
    final activeScale = widget.itemAnimation.whileActive?.scale ?? 1.0;

    _itemScales = [
      for (var i = 0; i < widget.items.length; i++)
        motionValue(i == widget.currentIndex ? activeScale : 1.0),
    ];
    _itemOpacities = [
      for (var i = 0; i < widget.items.length; i++)
        motionValue(i == widget.currentIndex ? 1.0 : 0.0),
    ];
    _itemScaleSolvers = [
      for (final value in _itemScales)
        SpringSolver(vsync: this, value: value, spring: tapSpring),
    ];
    _itemOpacitySolvers = [
      for (final value in _itemOpacities)
        SpringSolver(vsync: this, value: value, spring: tapSpring),
    ];
  }

  void _disposeItemMotion() {
    for (final solver in _itemScaleSolvers) {
      solver.dispose();
    }
    for (final solver in _itemOpacitySolvers) {
      solver.dispose();
    }
    for (final value in _itemScales) {
      value.dispose();
    }
    for (final value in _itemOpacities) {
      value.dispose();
    }
  }

  double get _indicatorHeightValue {
    if (widget.indicator.height != null) return widget.indicator.height!;
    switch (widget.indicator.type) {
      case NibNavIndicatorType.liquid:
      case NibNavIndicatorType.pill:
        return (widget.style.height - 8).clamp(0, widget.style.height);
      case NibNavIndicatorType.highlight:
        return widget.style.height;
      case NibNavIndicatorType.line:
        return 3;
      case NibNavIndicatorType.dot:
        return 4;
      case NibNavIndicatorType.none:
        return 0;
    }
  }

  double get _indicatorOpacityValue =>
      widget.indicator.type == NibNavIndicatorType.none ? 0.0 : 1.0;

  double _targetIndicatorWidth(double itemWidth) {
    if (widget.indicator.width != null) return widget.indicator.width!;
    switch (widget.indicator.type) {
      case NibNavIndicatorType.liquid:
      case NibNavIndicatorType.pill:
        return (itemWidth - 8).clamp(0.0, itemWidth);
      case NibNavIndicatorType.dot:
        return itemWidth * 0.6;
      case NibNavIndicatorType.highlight:
      case NibNavIndicatorType.line:
        return itemWidth;
      case NibNavIndicatorType.none:
        return 0;
    }
  }

  // ---------------------------------------------------------------------
  // Layout-dependent indicator placement
  // ---------------------------------------------------------------------

  void _syncIndicatorToCurrentIndex() {
    if (widget.items.isEmpty) return;
    final padding = widget.style.padding;
    final contentWidth =
        (_lastWidth - padding.horizontal).clamp(0.0, _lastWidth);
    final itemWidth = contentWidth / widget.items.length;
    final targetWidth = _targetIndicatorWidth(itemWidth);
    final targetX = padding.left +
        itemWidth * widget.currentIndex +
        (itemWidth - targetWidth) / 2;
    if (!_hasLaidOut) {
      _indicatorX.value = targetX;
      _liquidTail.value = targetX;
      _indicatorWidth.value = targetWidth;
      _hasLaidOut = true;
    } else {
      _go(_liquidTailSolver, _liquidTail, targetX);
      _go(_indicatorXSolver, _indicatorX, targetX);
      _go(_indicatorWidthSolver, _indicatorWidth, targetWidth);
    }
  }

  /// Springs [value] to [target] via [solver], or jumps there under reduced
  /// motion.
  void _go(SpringSolver solver, MotionValue<double> value, double target) {
    if (reduceMotion) {
      solver.stop();
      value.value = target;
    } else {
      solver.animateTo(target: target);
    }
  }

  void _animateIndicatorTo(int index) {
    if (!_hasLaidOut || widget.items.isEmpty) return;
    final padding = widget.style.padding;
    final contentWidth =
        (_lastWidth - padding.horizontal).clamp(0.0, _lastWidth);
    final itemWidth = contentWidth / widget.items.length;
    final targetWidth = _targetIndicatorWidth(itemWidth);
    final targetX =
        padding.left + itemWidth * index + (itemWidth - targetWidth) / 2;
    if (widget.indicator.type == NibNavIndicatorType.liquid) {
      _go(_liquidTailSolver, _liquidTail, targetX);
      if (reduceMotion) {
        _liquidClock.value = 1;
      } else {
        _liquidClock.forward(from: 0);
      }
    }
    _go(_indicatorXSolver, _indicatorX, targetX);
    _go(_indicatorWidthSolver, _indicatorWidth, targetWidth);
  }

  /// Springs the outgoing item's icon back to resting scale and fades out its
  /// active tint, while springing the incoming item's icon up to
  /// [NibNavItemAnimation.whileActive]'s scale and fading in its active tint.
  ///
  /// Both solvers default to `initialVelocity: 0`, so the outgoing item
  /// settles smoothly from whatever scale it was at (normally
  /// [NibNavItemAnimation.whileActive]'s scale) back to `1.0`.
  void _animateActiveItem(int fromIndex, int toIndex) {
    final restingScale = 1.0;
    final activeScale = widget.itemAnimation.whileActive?.scale ?? 1.0;

    if (fromIndex >= 0 && fromIndex < _itemScaleSolvers.length) {
      _go(_itemScaleSolvers[fromIndex], _itemScales[fromIndex], restingScale);
      _go(_itemOpacitySolvers[fromIndex], _itemOpacities[fromIndex], 0.0);
    }
    if (toIndex >= 0 && toIndex < _itemScaleSolvers.length) {
      _go(_itemScaleSolvers[toIndex], _itemScales[toIndex], activeScale);
      _go(_itemOpacitySolvers[toIndex], _itemOpacities[toIndex], 1.0);
    }
  }

  // ---------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------

  /// Springs the tapped item's icon down to [NibNavItemAnimation.whileTap]'s
  /// scale, then notifies [NibNavBar.onIndexChanged].
  ///
  /// [NibNavItemAnimation]'s default constructor sets `whileTap` to
  /// `NibAnim(scale: 0.85)`; if [NibNavItemAnimation.whileTap] is `null`
  /// (as in [NibNavItemAnimation.none]), no tap animation is played.
  void _onItemTapped(int index) {
    final tapScale = widget.itemAnimation.whileTap?.scale;
    if (tapScale != null && index < _itemScaleSolvers.length) {
      _go(_itemScaleSolvers[index], _itemScales[index], tapScale);
    }
    widget.onIndexChanged(index);
  }

  /// Springs every item's icon back to its resting scale after a tap ends —
  /// [NibNavItemAnimation.whileActive]'s scale for the active item, `1.0`
  /// for all others.
  void _onTapReleased() {
    for (var i = 0; i < _itemScaleSolvers.length; i++) {
      final resting = i == widget.currentIndex
          ? (widget.itemAnimation.whileActive?.scale ?? 1.0)
          : 1.0;
      _go(_itemScaleSolvers[i], _itemScales[i], resting);
    }
  }

  // ---------------------------------------------------------------------
  // Icon geometry — kept in sync with `NibNavBarPainter._iconRect` so the
  // real icon widgets land exactly where the painter's badges anchor to.
  // ---------------------------------------------------------------------

  double _iconCenterY(Rect contentRect) {
    final hasLabels = widget.items.any((item) => item.label != null);
    return hasLabels
        ? contentRect.top + contentRect.height * 0.38
        : contentRect.top + contentRect.height / 2;
  }

  /// Wraps the bar's painter in a [NibGlass] liquid-glass surface when
  /// [NibNavBarStyle.glass] is set, so the content behind the bar refracts
  /// through it; otherwise returns [child] untouched.
  Widget _maybeGlass(Widget child) {
    final style = widget.style;
    if (!style.glass) return child;
    return NibGlass(
      borderRadius: style.borderRadius ?? BorderRadius.zero,
      blurSigma: style.glassBlur,
      tint: style.glassTint ?? const Color(0x1FFFFFFF),
      highlight: style.glassHighlight,
      child: child,
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.style.margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (widget.items.isNotEmpty &&
              width.isFinite &&
              width != _lastWidth) {
            _lastWidth = width;
            _syncIndicatorToCurrentIndex();
          }

          final padding = widget.style.padding;
          final contentWidth = (width - padding.horizontal).clamp(0.0, width);
          final itemWidth =
              widget.items.isEmpty ? 0.0 : contentWidth / widget.items.length;
          final iconSize = widget.style.iconSize;
          final contentRect = Rect.fromLTWH(
            padding.left,
            padding.top,
            contentWidth,
            (widget.style.height - padding.vertical)
                .clamp(0.0, widget.style.height),
          );
          final iconCenterY = _iconCenterY(contentRect);

          // When glass, the painter draws only the indicator + labels — the
          // opaque background is replaced by the NibGlass surface below.
          final painterStyle = widget.style.glass
              ? widget.style.copyWith(
                  backgroundColor: const Color(0x00000000),
                  elevation: 0,
                )
              : widget.style;

          return SizedBox(
            width: width,
            height: widget.style.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The bar's background, indicator, and labels.
                GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTapDown: itemWidth <= 0
                      ? null
                      : (details) {
                          final localX =
                              details.localPosition.dx - padding.left;
                          final index = (localX / itemWidth)
                              .floor()
                              .clamp(0, widget.items.length - 1);
                          _onItemTapped(index);
                        },
                  onTapUp: (_) => _onTapReleased(),
                  onTapCancel: _onTapReleased,
                  child: _maybeGlass(
                    CustomPaint(
                      size: Size(width, widget.style.height),
                      painter: NibNavBarPainter(
                        items: widget.items,
                        currentIndex: widget.currentIndex,
                        style: painterStyle,
                        indicator: widget.indicator,
                        indicatorX: _indicatorX,
                        indicatorWidth: _indicatorWidth,
                        indicatorHeight: _indicatorHeight,
                        indicatorOpacity: _indicatorOpacity,
                        liquidShader: _liquidShader,
                        liquidTail: _liquidTail,
                        liquidPhase: _liquidPhase,
                        itemScales: _itemScales,
                        itemOpacities: _itemOpacities,
                      ),
                    ),
                  ),
                ),
                // Icons — real widgets layered on top of the painter, one
                // per item, scaled/crossfaded by that item's MotionValues.
                if (itemWidth > 0)
                  for (var i = 0; i < widget.items.length; i++)
                    Positioned(
                      left: padding.left +
                          itemWidth * i +
                          (itemWidth - iconSize) / 2,
                      top: iconCenterY - iconSize / 2,
                      width: iconSize,
                      height: iconSize,
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[
                              _itemScales[i],
                              _itemOpacities[i],
                            ]),
                            builder: (context, _) {
                              final activeOpacity =
                                  _itemOpacities[i].value.clamp(0.0, 1.0);
                              return Transform.scale(
                                scale: _itemScales[i].value,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 1 - activeOpacity,
                                      child: IconTheme(
                                        data: IconThemeData(
                                          color: widget.style.inactiveColor,
                                          size: iconSize,
                                        ),
                                        child: widget.items[i].icon,
                                      ),
                                    ),
                                    Opacity(
                                      opacity: activeOpacity,
                                      child: IconTheme(
                                        data: IconThemeData(
                                          color: widget.style.activeColor,
                                          size: iconSize,
                                        ),
                                        child: widget.items[i].activeIcon ??
                                            widget.items[i].icon,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                if (itemWidth > 0)
                  for (var i = 0; i < widget.items.length; i++)
                    Positioned(
                      left: padding.left + itemWidth * i,
                      top: 0,
                      width: itemWidth,
                      height: widget.style.height,
                      child: _NavTabTarget(
                        label: widget.items[i].tooltip ?? widget.items[i].label,
                        selected: widget.currentIndex == i,
                        focusColor: widget.style.activeColor,
                        onActivate: () {
                          _onItemTapped(i);
                          _onTapReleased();
                        },
                        onTapDown: () => _onItemTapped(i),
                        onTapReleased: _onTapReleased,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Keep focus updates local to the hit target: the shader and bar do not rebuild
// when keyboard traversal changes the focus highlight.
class _NavTabTarget extends StatefulWidget {
  const _NavTabTarget({
    required this.label,
    required this.selected,
    required this.focusColor,
    required this.onActivate,
    required this.onTapDown,
    required this.onTapReleased,
  });

  final String? label;
  final bool selected;
  final Color focusColor;
  final VoidCallback onActivate;
  final VoidCallback onTapDown;
  final VoidCallback onTapReleased;

  @override
  State<_NavTabTarget> createState() => _NavTabTargetState();
}

class _NavTabTargetState extends State<_NavTabTarget> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        button: true,
        selected: widget.selected,
        onTap: widget.onActivate,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (show) => setState(() => _showFocus = show),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => widget.onTapDown(),
            onTapUp: (_) => widget.onTapReleased(),
            onTapCancel: widget.onTapReleased,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: _showFocus
                      ? Border.all(color: widget.focusColor, width: 2)
                      : null,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
}
