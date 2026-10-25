import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/scheduler.dart';

import '../values/motion_value.dart';

/// Builds sliver-header content from a collapse-progress [MotionValue].
typedef NibSliverProgressBuilder = Widget Function(
  BuildContext context,
  MotionValue<double> progress,
);

/// A [SliverPersistentHeaderDelegate] that exposes how far the header has
/// collapsed as a [MotionValue] (`0.0` fully expanded → `1.0` fully collapsed)
/// instead of making you rebuild the header on every scroll frame.
///
/// [builder] runs **once**; the returned widget is reused as the sliver
/// re-lays the header out, and only [progress] changes. Pair it with
/// `NibMotion(motionValues: …)` and `mapRange` so the header repaints without
/// rebuilding:
///
/// ```dart
/// SliverPersistentHeader(
///   pinned: true,
///   delegate: NibSliverHeaderDelegate(
///     minExtent: 56,
///     maxExtent: 220,
///     builder: (context, progress) => NibMotion(
///       motionValues: NibMotionValues(
///         opacity: progress.mapRange([0, 1], [1, 0]),
///       ),
///       child: const Hero(),
///     ),
///   ),
/// )
/// ```
///
/// [progress] is written while the sliver lays out, so listen with render
/// objects (`NibMotion`) or derived values, not `ValueListenableBuilder`
/// (which would call `setState` during layout).
class NibSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// Creates a delegate whose header goes from [maxExtent] to [minExtent].
  NibSliverHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  }) : assert(maxExtent >= minExtent, 'maxExtent must be >= minExtent');

  @override
  final double minExtent;

  @override
  final double maxExtent;

  /// Builds the header content once; it receives [progress].
  final NibSliverProgressBuilder builder;

  /// Collapse progress: `0.0` fully expanded, `1.0` fully collapsed.
  final MotionValue<double> progress = _FrameSafeProgress();

  Widget? _content;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    progress.value = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    // Reusing the same widget instance lets Flutter skip rebuilding the
    // subtree as the header's extent changes on every scroll frame.
    return _content ??= builder(context, progress);
  }

  @override
  bool shouldRebuild(covariant NibSliverHeaderDelegate oldDelegate) =>
      oldDelegate.minExtent != minExtent ||
      oldDelegate.maxExtent != maxExtent ||
      oldDelegate.builder != builder;
}

/// Exposes the scroll-through progress of the sliver it is placed in as a
/// [MotionValue] — for a header inside a `SliverAppBar.flexibleSpace`, a
/// `SliverToBoxAdapter`, or any other sliver.
///
/// `progress` is `0.0` while the sliver's leading edge is at the viewport's
/// leading edge and reaches `1.0` after scrolling
/// `expandedExtent - collapsedExtent` pixels. It is computed synchronously
/// from the scroll position and the sliver's `precedingScrollExtent`, so there
/// is no one-frame lag and no rebuild: [builder] runs once.
///
/// Place it inside the sliver (as its child); it finds the nearest enclosing
/// [RenderSliver] and [Scrollable].
class NibSliverProgress extends StatefulWidget {
  /// Creates a progress source for the enclosing sliver.
  const NibSliverProgress({
    super.key,
    required this.expandedExtent,
    this.collapsedExtent = 0.0,
    required this.builder,
  }) : assert(expandedExtent >= collapsedExtent);

  /// The sliver's full (expanded) main-axis extent.
  final double expandedExtent;

  /// The extent it collapses to; progress reaches `1.0` when this much of the
  /// difference has scrolled away.
  final double collapsedExtent;

  /// Builds the content once; it receives the progress value.
  final NibSliverProgressBuilder builder;

  @override
  State<NibSliverProgress> createState() => _NibSliverProgressState();
}

class _NibSliverProgressState extends State<NibSliverProgress> {
  final MotionValue<double> _progress = _FrameSafeProgress();
  ScrollPosition? _position;
  Widget? _content;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_update);
      _position = position;
      position?.addListener(_update);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _update();
    });
  }

  void _update() {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final sliver = context.findAncestorRenderObjectOfType<RenderSliver>();
    if (sliver == null) return;
    final range = widget.expandedExtent - widget.collapsedExtent;
    final scrolled = position.pixels - sliver.constraints.precedingScrollExtent;
    _progress.value = range <= 0 ? 1.0 : (scrolled / range).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _content ??= widget.builder(context, _progress);
  }
}

/// A progress value that is written from inside layout (a sliver delegate's
/// `build` runs during layout) and so must not notify widgets synchronously:
/// `ValueListenableBuilder` and friends would call `setState` mid-layout.
///
/// Its [value] is updated immediately (anything reading it during the same
/// layout/paint sees the new number); listeners are notified right after the
/// frame when the write happened during the build/layout/paint phase, and
/// synchronously otherwise. So a listening widget lags at most one frame.
class _FrameSafeProgress extends MotionValue<double> {
  _FrameSafeProgress() : super(0.0);

  bool _pending = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      super.notifyListeners();
      return;
    }
    if (_pending) return;
    _pending = true;
    binding.addPostFrameCallback((_) {
      _pending = false;
      if (!_disposed) super.notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
