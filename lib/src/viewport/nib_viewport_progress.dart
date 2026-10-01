import 'package:flutter/widgets.dart';

import '../values/motion_value.dart';

/// Holds the continuous scroll-through progress of a [NibViewportProgress]
/// child as [MotionValue]s, so any `NibMotion` (via `motionValues`) or
/// [MotionValue.mapRange] can react to it without rebuilding.
class NibViewportProgressController {
  /// Scroll-through progress along the scroll axis, `0..1`.
  ///
  /// `0` when the child's leading edge is at the viewport's trailing edge (it
  /// is just about to enter), `1` when the child's trailing edge has passed
  /// the viewport's leading edge (it has fully left). It passes `0.5` when
  /// the child is centred.
  final MotionValue<double> progress = MotionValue<double>(0.0);

  /// Fraction of the child's area currently inside the viewport, `0..1`.
  final MotionValue<double> visibleFraction = MotionValue<double>(0.0);

  /// Releases both values.
  void dispose() {
    progress.dispose();
    visibleFraction.dispose();
  }
}

/// Reports how far its [child] has travelled through the viewport as
/// continuous values on [controller] — the continuous counterpart of
/// `NibMotion.whileInView`'s boolean.
///
/// Listens to **every** ancestor [Scrollable] (a horizontal list inside a
/// vertical page reports movement of either), measures against the nearest
/// one's viewport (or the screen when there is none), and only writes
/// [MotionValue]s: scrolling causes no rebuilds. Measurement runs after the
/// frame in which scrolling or layout changed, so values lag scrolling by at
/// most one frame.
///
/// Reverse-axis scrollables are measured in global screen direction, so
/// `progress` still means "leading edge enters first" in the direction the
/// content moves on screen only for forward axes; reversed lists report the
/// mirrored value.
///
/// ```dart
/// final c = NibViewportProgressController();
/// NibViewportProgress(
///   controller: c,
///   child: NibMotion(
///     motionValues: NibMotionValues(
///       opacity: c.progress.mapRange([0, 0.3, 0.7, 1], [0, 1, 1, 0]),
///     ),
///     child: card,
///   ),
/// )
/// ```
class NibViewportProgress extends StatefulWidget {
  /// Creates a progress reporter for [child].
  const NibViewportProgress({
    super.key,
    required this.controller,
    required this.child,
  });

  /// Receives the measured values. The caller owns and disposes it.
  final NibViewportProgressController controller;

  /// The measured widget.
  final Widget child;

  @override
  State<NibViewportProgress> createState() => _NibViewportProgressState();
}

class _NibViewportProgressState extends State<NibViewportProgress> {
  Set<ScrollPosition> _positions = const {};
  // Nearest first, outermost last.
  List<ScrollableState> _scrollables = const [];
  final List<Rect> _viewportRects = <Rect>[];
  ScrollPosition? _nearest;
  AxisDirection _direction = AxisDirection.down;
  bool _scheduled = false;

  // Geometry as of the last layout-consistent measurement (post-frame), and
  // the scroll pixels at that moment. Between measurements the scroll
  // listener extrapolates from the pixel delta, so the published values are
  // correct in the same frame as the scroll instead of one frame late.
  bool _hasMeasure = false;
  Rect _elementRect = Rect.zero;
  Rect _viewportRect = Rect.zero;
  final Map<ScrollPosition, double> _pixelsAtMeasure =
      <ScrollPosition, double>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-measure on window/metrics changes.
    MediaQuery.maybeSizeOf(context);
    _attach();
    _schedule();
  }

  @override
  void didUpdateWidget(NibViewportProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _attach() {
    final found = <ScrollPosition>{};
    final ordered = <ScrollableState>[];
    context.visitAncestorElements((element) {
      final state = element is StatefulElement ? element.state : null;
      if (state is ScrollableState) {
        found.add(state.position);
        ordered.add(state);
      }
      return true;
    });
    _scrollables = ordered;
    final scrollable = Scrollable.maybeOf(context);
    _nearest = scrollable?.position;
    _direction = scrollable?.axisDirection ?? AxisDirection.down;
    if (found.length == _positions.length && found.containsAll(_positions)) {
      return;
    }
    for (final p in _positions) {
      p.removeListener(_onScroll);
    }
    for (final p in found) {
      p.addListener(_onScroll);
    }
    _positions = found;
  }

  /// Scroll moved: publish immediately from the last measurement plus the
  /// pixel delta, then re-measure after layout to correct any drift.
  void _onScroll() {
    if (_hasMeasure) _publish(extrapolate: true);
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final size = box.size;
    if (size.isEmpty) return;

    final scrollable = Scrollable.maybeOf(context);
    final viewportBox = scrollable?.context.findRenderObject();
    if (viewportBox is RenderBox && viewportBox.hasSize) {
      _viewportRect = viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    } else {
      final screen = MediaQuery.maybeSizeOf(context);
      if (screen == null) return;
      _viewportRect = Offset.zero & screen;
    }
    _elementRect = box.localToGlobal(Offset.zero) & size;
    _viewportRects
      ..clear()
      ..addAll([
        for (final state in _scrollables)
          if (state.context.findRenderObject() case final RenderBox vb
              when vb.attached && vb.hasSize)
            vb.localToGlobal(Offset.zero) & vb.size
          else
            _viewportRect,
      ]);
    _pixelsAtMeasure
      ..clear()
      ..addEntries([
        for (final p in _positions)
          if (p.hasPixels) MapEntry(p, p.pixels),
      ]);
    _hasMeasure = true;
    _publish(extrapolate: false);
  }

  /// How far content has visually moved since the last measurement because of
  /// scrolling [positions], in global coordinates. Scrolling forward moves
  /// content *against* the axis direction.
  Offset _scrolledSince(Iterable<ScrollPosition> positions) {
    var dx = 0.0;
    var dy = 0.0;
    for (final p in positions) {
      if (!p.hasPixels) continue;
      final delta = p.pixels - (_pixelsAtMeasure[p] ?? p.pixels);
      switch (p.axisDirection) {
        case AxisDirection.down:
          dy -= delta;
        case AxisDirection.up:
          dy += delta;
        case AxisDirection.right:
          dx -= delta;
        case AxisDirection.left:
          dx += delta;
      }
    }
    return Offset(dx, dy);
  }

  void _publish({required bool extrapolate}) {
    var rect = _elementRect;
    var viewport = _viewportRect;
    if (extrapolate) {
      rect = rect.shift(_scrolledSince(_positions));
      // Only scrollables *outside* the nearest one move its viewport.
      viewport = viewport.shift(
          _scrolledSince(_positions.where((p) => !identical(p, _nearest))));
    }

    // Progress runs in the scroll direction: 0 when the element begins to
    // enter (its leading edge meets the viewport's trailing edge), 1 when it
    // has fully left past the viewport's leading edge — for every axis
    // direction, including reversed lists and RTL horizontal ones.
    final double travelled;
    final double elementSize;
    final double viewportSize;
    switch (_direction) {
      case AxisDirection.down:
        travelled = viewport.bottom - rect.top;
        elementSize = rect.height;
        viewportSize = viewport.height;
      case AxisDirection.up:
        travelled = rect.bottom - viewport.top;
        elementSize = rect.height;
        viewportSize = viewport.height;
      case AxisDirection.right:
        travelled = viewport.right - rect.left;
        elementSize = rect.width;
        viewportSize = viewport.width;
      case AxisDirection.left:
        travelled = rect.right - viewport.left;
        elementSize = rect.width;
        viewportSize = viewport.width;
    }
    final travel = viewportSize + elementSize;
    final progress = travel <= 0 ? 0.0 : (travelled / travel).clamp(0.0, 1.0);

    // Visible means inside *every* enclosing viewport: an inner list that an
    // outer scroll view has scrolled off-screen shows nothing.
    var visible = rect.intersect(viewport);
    for (var i = 0; i < _viewportRects.length; i++) {
      var outerRect = _viewportRects[i];
      if (extrapolate) {
        outerRect = outerRect.shift(_scrolledSince([
          for (var j = i + 1; j < _scrollables.length; j++)
            _scrollables[j].position
        ]));
      }
      visible = visible.intersect(outerRect);
      if (visible.isEmpty) break;
    }
    final visibleArea = visible.isEmpty ? 0.0 : visible.width * visible.height;
    final area = rect.width * rect.height;
    final fraction = area <= 0 ? 0.0 : (visibleArea / area).clamp(0.0, 1.0);

    widget.controller.progress.value = progress;
    widget.controller.visibleFraction.value = fraction;
  }

  @override
  void dispose() {
    for (final p in _positions) {
      p.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
