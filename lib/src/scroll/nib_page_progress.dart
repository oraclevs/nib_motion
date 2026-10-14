import 'package:flutter/material.dart' show TabController;
import 'package:flutter/widgets.dart';

import '../values/derived_motion_value.dart';
import '../values/motion_value.dart';

/// Exposes a [PageController]'s fractional page as a [MotionValue], so page
/// swipes can drive motion (parallax, dots, tab indicators) with no rebuilds.
///
/// ```dart
/// final progress = NibPageProgress(pageController);
/// // Dot for page 2 grows as the pager approaches it:
/// NibMotion(
///   motionValues: NibMotionValues(scaleX: progress.closeness(2).mapRange([0, 1], [1, 1.6])),
///   child: dot,
/// )
/// ```
class NibPageProgress {
  /// Starts following [controller]. Call [dispose] when done.
  NibPageProgress(PageController pageController)
      : controller = pageController,
        tabController = null,
        page = MotionValue<double>(_currentPage(pageController)) {
    pageController.addListener(_onScroll);
  }

  /// Starts following a [TabController]: [page] is its fractional index, so
  /// it moves continuously through both taps (`animateTo`) and swipes of an
  /// attached `TabBarView`. Call [dispose] when done.
  NibPageProgress.tab(TabController controller)
      : controller = null,
        tabController = controller,
        page = MotionValue<double>(_tabPage(controller)) {
    controller.animation?.addListener(_onScroll);
    controller.addListener(_onScroll);
  }

  /// The page controller being followed, or `null` for [NibPageProgress.tab].
  final PageController? controller;

  /// The tab controller being followed, or `null` for the page-controller
  /// constructor.
  final TabController? tabController;

  /// The fractional page (`1.5` is halfway between pages 1 and 2).
  final MotionValue<double> page;

  static double _currentPage(PageController c) =>
      c.hasClients && c.position.haveDimensions
          ? (c.page ?? c.initialPage.toDouble())
          : c.initialPage.toDouble();

  static double _tabPage(TabController c) =>
      c.animation?.value ?? c.index.toDouble();

  void _onScroll() {
    final tab = tabController;
    page.update(tab != null ? _tabPage(tab) : _currentPage(controller!));
  }

  /// `1.0` when the pager is exactly on [index], falling linearly to `0.0`
  /// one page away (and beyond).
  DerivedMotionValue<double, double> closeness(int index) =>
      page.transform<double>((p) => (1.0 - (p - index).abs()).clamp(0.0, 1.0));

  /// Signed distance of the pager from [index] in pages: negative when the
  /// pager is before it, positive after. Useful for parallax offsets.
  DerivedMotionValue<double, double> offsetFrom(int index) =>
      page.transform<double>((p) => p - index);

  /// Stops following the controller and disposes [page]. Derived values from
  /// [closeness]/[offsetFrom] must be disposed by their owners first.
  void dispose() {
    controller?.removeListener(_onScroll);
    tabController?.animation?.removeListener(_onScroll);
    tabController?.removeListener(_onScroll);
    page.dispose();
  }
}
