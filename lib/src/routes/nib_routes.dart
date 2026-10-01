import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/physics.dart' as flutter_physics;
import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_property.dart';
import '../core/render_nib_motion.dart';
import '../core/nib_transition.dart';
import '../physics/spring_description.dart';
import '../values/motion_value.dart';
import 'nib_shared_source.dart';

/// Default hidden state of a route's content (before it enters / after it
/// exits): transparent and slightly small.
const NibAnim _kDefaultDialogHidden = NibAnim(opacity: 0.0, scale: 0.92);

const NibAnim _kDefaultPageHidden = NibAnim(opacity: 0.0, y: 32.0);

const NibTransition _kDefaultRouteTransition = NibTransition(
  spring: NibSpringDescription(mass: 1.0, stiffness: 320.0, damping: 26.0),
);

/// How long [transition] takes to come to rest (delay included).
///
/// Tweens take their duration; springs are simulated until they settle. Used
/// so a route is never removed while its exit motion is still playing.
Duration _settleTime(NibTransition transition) {
  final spring = transition.spring;
  if (spring == null) return transition.delay + transition.duration;
  final simulation =
      flutter_physics.SpringSimulation(spring.toFlutter(), 0.0, 1.0, 0.0);
  var t = 0.0;
  while (t < 10.0 && !simulation.isDone(t)) {
    t += 1 / 120;
  }
  return transition.delay + Duration(microseconds: (t * 1e6).round());
}

Duration _atLeastSettle(Duration requested, NibTransition transition) {
  final settle = _settleTime(transition);
  return settle > requested ? settle : requested;
}

/// Width of the strip at the start edge that begins a back-swipe.
/// Per-navigator progress of an interactive back-swipe: `null` when none is
/// running, otherwise how far the page being swiped has left (0 at rest, 1
/// gone). Routes below read it to slide in from the side behind the page.
final Expando<ValueNotifier<double?>> _backSwipeProgress =
    Expando<ValueNotifier<double?>>('NibBackSwipeProgress');

/// The back-swipe progress notifier for [navigator] (created on first use).
ValueNotifier<double?> _backSwipeProgressFor(NavigatorState navigator) =>
    _backSwipeProgress[navigator] ??= ValueNotifier<double?>(null);

/// Slides its child sideways while the route above is being swiped away.
///
/// Applies only when this route is covered (its `secondaryAnimation` is not
/// dismissed), so the page being dragged never shifts itself.
class _NibParallaxShift extends StatelessWidget {
  const _NibParallaxShift({
    required this.progress,
    required this.secondaryAnimation,
    required this.parallax,
    required this.child,
  });

  final ValueListenable<double?> progress;
  final Animation<double> secondaryAnimation;
  final double parallax;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: Listenable.merge([progress, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final fraction = progress.value;
        final covered = secondaryAnimation.status != AnimationStatus.dismissed;
        final dx = (fraction == null || !covered)
            ? 0.0
            : -dir * parallax * (1.0 - fraction);
        if (dx == 0.0) return child!;
        return FractionalTranslation(translation: Offset(dx, 0), child: child);
      },
    );
  }
}

const double _kBackSwipeEdge = 24.0;

/// Fraction of the width past which releasing a back-swipe pops the route.
const double _kBackSwipeCommitFraction = 0.4;

/// Release speed (px/s toward the back direction) that pops the route.
const double _kBackSwipeCommitVelocity = 700.0;

/// Drives a route's content with a [NibMotion] from the route's own
/// animation: `forward` plays [animate], `reverse` plays [exit].
///
/// The route's lifetime (how long it stays mounted after a pop) is still
/// owned by the route's `AnimationController`; the content's motion is
/// physics-driven by the [NibMotion] runtime, so it inherits velocity on
/// interruption (a pop during the enter spring reverses smoothly) and honours
/// `NibMotionConfig` reduced motion.
class _NibRouteTransition extends StatefulWidget {
  const _NibRouteTransition({
    required this.animation,
    required this.initial,
    required this.animate,
    required this.exit,
    required this.transition,
    required this.child,
    this.backSwipe = false,
    this.onSwipeActive,
    this.sharedFrom,
    this.contentKey,
  });

  final bool backSwipe;

  /// Told when an edge swipe starts/ends so the route can let the page below
  /// show through while the page slides away.
  final ValueChanged<bool>? onSwipeActive;
  final GlobalKey? sharedFrom;
  final GlobalKey? contentKey;
  final Animation<double> animation;
  final NibAnim initial;
  final NibAnim animate;
  final NibAnim exit;
  final NibTransition transition;
  final Widget child;

  @override
  State<_NibRouteTransition> createState() => _NibRouteTransitionState();
}

class _NibRouteTransitionState extends State<_NibRouteTransition> {
  final NibMotionController _controller = NibMotionController();
  final GlobalKey _motionKey = GlobalKey();
  bool _swipeCommitted = false;
  bool _enteredShared = false;
  bool _hidingSource = false;
  int _swipeGeneration = 0;
  bool _dragging = false;
  ValueNotifier<double?>? _parallax;
  MotionValue<double>? _xValue;
  double _dragBack = 0.0;
  double _width = 0.0;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStatus(widget.animation.status);
    });
  }

  /// The transform (on the route's full-size motion box) that paints the
  /// content exactly over the source widget, or `null` when there is no
  /// usable source or content to measure.
  NibAnim? _sharedPose() {
    final source = widget.sharedFrom?.currentContext?.findRenderObject();
    final content = widget.contentKey?.currentContext?.findRenderObject();
    final motion = _motionKey.currentContext?.findRenderObject();
    if (source is! RenderBox ||
        content is! RenderBox ||
        motion is! RenderNibMotion ||
        !source.attached ||
        !content.attached ||
        !source.hasSize ||
        !content.hasSize ||
        !motion.hasSize ||
        motion.child == null) {
      return null;
    }
    final src = source.localToGlobal(Offset.zero) & source.size;
    // The content's *natural* rect: measured in the motion box's child space
    // (excluding the box's own transform), then placed at its layout origin.
    final dstLocal =
        content.localToGlobal(Offset.zero, ancestor: motion.child) &
            content.size;
    final origin = motion.localToGlobal(Offset.zero);
    final dst = dstLocal.shift(origin);
    if (dst.width <= 0 || dst.height <= 0) return null;
    final center = origin + motion.size.center(Offset.zero);
    final sx = src.width / dst.width;
    final sy = src.height / dst.height;
    final scaledDstCenter = center +
        Offset(
            (dst.center.dx - center.dx) * sx, (dst.center.dy - center.dy) * sy);
    final t = src.center - scaledDstCenter;
    return NibAnim(x: t.dx, y: t.dy, scaleX: sx, scaleY: sy);
  }

  void _onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        if (!_enteredShared && widget.sharedFrom != null) {
          _enteredShared = true;
          final pose = _sharedPose();
          if (pose != null) _controller.set(pose.copyWith(opacity: 1.0));
          // The source stays laid out but invisible while this route stands
          // in for it.
          final source = widget.sharedFrom!;
          nibSharedSourceHide(source);
          _hidingSource = true;
        }
        _controller.start(
          target: NibAnim.identity.merge(widget.animate),
          transition: widget.transition,
        );
      case AnimationStatus.reverse:
        final pose = widget.sharedFrom == null ? null : _sharedPose();
        var target = widget.exit;
        if (pose != null) {
          target = pose.copyWith(opacity: widget.exit.opacity);
        } else if (_swipeCommitted) {
          final dir = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
          target = widget.exit.copyWith(x: dir * (_width + 24));
        }
        _controller
            .start(target: target, transition: widget.transition)
            .then((_) => _endParallax());
      case AnimationStatus.dismissed:
        _showSource();
        _endParallax();
    }
  }

  /// Gives the hidden source back once nothing stands in for it any more.
  void _showSource({bool defer = false}) {
    if (!_hidingSource) return;
    _hidingSource = false;
    nibSharedSourceShow(widget.sharedFrom!, defer: defer);
  }

  @override
  void didUpdateWidget(_NibRouteTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    // A route torn down mid-swipe must not leave the navigator in a gesture.
    _endSwipeGesture();
    _endParallax();
    _showSource(defer: true);
    _controller.dispose();
    super.dispose();
  }

  // --- edge back-swipe ---

  double get _dir => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  NavigatorState? _swipeNavigator;

  void _swipeStart(DragStartDetails details) {
    _controller.stop();
    _dragBack = 0.0;
    _dragging = true;
    _swipeGeneration++;
    // Tell the Navigator a user gesture is in flight (as the platform back
    // swipe does) and make the route below paint instead of staying offstage
    // behind this opaque page.
    final navigator = Navigator.of(context)..didStartUserGesture();
    _swipeNavigator = navigator;
    widget.onSwipeActive?.call(true);
    _beginParallax(navigator);
  }

  // --- parallax of the route below ---

  void _beginParallax(NavigatorState navigator) {
    _endParallax();
    final value = _controller.motionValueOf(NibProperty.x);
    if (value == null) return;
    _xValue = value;
    _parallax = _backSwipeProgressFor(navigator);
    value.addListener(_publishParallax);
    _publishParallax();
  }

  /// Tells routes below how far this page has been dragged away (0 at rest,
  /// 1 gone), so they can slide in from the side behind it.
  void _publishParallax() {
    final notifier = _parallax;
    final value = _xValue;
    if (notifier == null || value == null || _width <= 0) return;
    notifier.value = (value.value * _dir / _width).clamp(0.0, 1.0);
  }

  void _endParallax() {
    _xValue?.removeListener(_publishParallax);
    _xValue = null;
    final notifier = _parallax;
    _parallax = null;
    if (notifier != null && notifier.value != null) notifier.value = null;
  }

  void _endSwipeGesture() {
    final navigator = _swipeNavigator;
    _swipeNavigator = null;
    navigator?.didStopUserGesture();
  }

  void _swipeUpdate(DragUpdateDetails details) {
    _dragBack =
        (_dragBack + details.delta.dx * _dir).clamp(0.0, double.infinity);
    _controller.set(NibAnim(x: _dragBack * _dir));
  }

  Future<void> _swipeEnd(DragEndDetails details) async {
    final velocityBack = (details.primaryVelocity ?? 0.0) * _dir;
    final commit = _dragBack > _width * _kBackSwipeCommitFraction ||
        velocityBack > _kBackSwipeCommitVelocity;
    // Hand the finger's velocity to whatever moves the page next.
    _controller
        .motionValueOf(NibProperty.x)
        ?.update(_dragBack * _dir, velocity: velocityBack * _dir);
    _dragging = false;
    final generation = _swipeGeneration;
    _endSwipeGesture();
    if (commit) {
      _swipeCommitted = true;
      final navigator = Navigator.of(context);
      final popped = await navigator.maybePop();
      if (popped) return;
      _swipeCommitted = false;
    }
    if (!mounted) {
      widget.onSwipeActive?.call(false);
      return;
    }
    // Cancelled: the page springs back. The route below must stay painted (and
    // keep its parallax) until it has fully covered it again.
    _controller
        .start(
      target: NibAnim.identity.merge(widget.animate),
      transition: widget.transition,
    )
        .then((_) {
      if (generation != _swipeGeneration || _dragging) return;
      widget.onSwipeActive?.call(false);
      _endParallax();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = NibMotion(
      key: _motionKey,
      controller: _controller,
      initial: widget.initial,
      transition: widget.transition,
      child: widget.child,
    );
    if (!widget.backSwipe) return motion;
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return Stack(
        children: [
          motion,
          Positioned.directional(
            textDirection: Directionality.of(context),
            start: 0,
            top: 0,
            bottom: 0,
            width: _kBackSwipeEdge,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Track the finger from touch-down so the page sits under it.
              dragStartBehavior: DragStartBehavior.down,
              onHorizontalDragStart: _swipeStart,
              onHorizontalDragUpdate: _swipeUpdate,
              onHorizontalDragEnd: _swipeEnd,
            ),
          ),
        ],
      );
    });
  }
}

/// A modal route (dialog, sheet, popover) whose content enters and exits with
/// [NibMotion] physics.
///
/// Built on [PopupRoute], so it gets a barrier, back-button/`Navigator.pop`
/// dismissal and result returning for free. Widgets-only: no Material
/// dependency.
///
/// ```dart
/// final ok = await Navigator.of(context).push(NibModalRoute<bool>(
///   builder: (context) => MyDialog(),
/// ));
/// ```
///
/// The content is [initial] when the route starts, springs to [animate] on
/// enter, and to [exit] when popped. A pop during the enter animation reverses
/// it from the current position *and velocity*.
class NibModalRoute<T> extends PopupRoute<T> {
  /// Creates a modal route showing [builder]'s content.
  NibModalRoute({
    required this.builder,
    this.barrierDismissible = true,
    this.barrierColor = const Color(0x80000000),
    this.barrierLabel,
    this.initial = _kDefaultDialogHidden,
    this.animate = NibAnim.identity,
    NibAnim? exit,
    this.transition = _kDefaultRouteTransition,
    this.alignment = Alignment.center,
    this.duration = const Duration(milliseconds: 350),
    this.reverseDuration = const Duration(milliseconds: 250),
    this.sharedFrom,
    super.settings,
  }) : exit = exit ?? initial;

  /// When set, the content grows out of the widget that owns this key (like a
  /// hero) and shrinks back into it on pop, instead of using [initial]/[exit].
  ///
  /// The widget is measured when the route enters and again when it leaves; if
  /// it is not mounted then, the normal [initial]/[exit] motion is used. The
  /// source must remain in the tree below the route (it is not moved).
  final GlobalKey? sharedFrom;

  final GlobalKey _contentKey = GlobalKey();

  /// Builds the route's content.
  final WidgetBuilder builder;

  /// The content's starting (and, by default, exiting) state.
  final NibAnim initial;

  /// The content's resting state once entered.
  final NibAnim animate;

  /// The state the content animates to when the route is popped. Defaults to
  /// [initial].
  final NibAnim exit;

  /// How the content moves between states.
  final NibTransition transition;

  /// Where the content sits in the route's full-screen area.
  final AlignmentGeometry alignment;

  /// How long the route's enter takes (barrier fade and route lifetime). The
  /// content's own motion is physics-driven and may settle before or after.
  final Duration duration;

  /// The minimum time the route stays mounted after a pop. The route is never
  /// removed before its exit [transition] has come to rest: if the transition
  /// takes longer than this, the route waits for it.
  final Duration reverseDuration;

  @override
  final bool barrierDismissible;

  @override
  final Color? barrierColor;

  @override
  final String? barrierLabel;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration =>
      _atLeastSettle(reverseDuration, transition);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Align(
        alignment: alignment,
        child: KeyedSubtree(key: _contentKey, child: builder(context)),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return _NibRouteTransition(
      animation: animation,
      initial: initial,
      animate: animate,
      exit: exit,
      transition: transition,
      sharedFrom: sharedFrom,
      contentKey: _contentKey,
      child: child,
    );
  }
}

/// Pushes a [NibModalRoute] onto the root navigator of [context] and returns
/// its result.
///
/// A dialog convenience: `showNibDialog<bool>(context: context, builder: …)`.
Future<T?> showNibDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor = const Color(0x80000000),
  String? barrierLabel,
  NibAnim initial = _kDefaultDialogHidden,
  NibAnim animate = NibAnim.identity,
  NibAnim? exit,
  NibTransition transition = _kDefaultRouteTransition,
  AlignmentGeometry alignment = Alignment.center,
  Duration duration = const Duration(milliseconds: 350),
  Duration reverseDuration = const Duration(milliseconds: 250),
  GlobalKey? sharedFrom,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator)
      .push<T>(NibModalRoute<T>(
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    initial: initial,
    animate: animate,
    exit: exit,
    transition: transition,
    alignment: alignment,
    duration: duration,
    reverseDuration: reverseDuration,
    sharedFrom: sharedFrom,
    settings: routeSettings,
  ));
}

/// A full-page route whose content enters and exits with [NibMotion] physics
/// instead of a platform page transition.
///
/// The page is opaque and keeps the route below alive (`maintainState`).
/// Defaults to fading in while sliding up 32px.
class NibPageRoute<T> extends PageRoute<T> {
  /// Creates a page route showing [builder]'s content.
  NibPageRoute({
    required this.builder,
    this.initial = _kDefaultPageHidden,
    this.animate = NibAnim.identity,
    NibAnim? exit,
    this.transition = _kDefaultRouteTransition,
    this.duration = const Duration(milliseconds: 350),
    this.reverseDuration = const Duration(milliseconds: 250),
    this.maintainState = true,
    this.backSwipe = false,
    this.parallax = 0.3,
    this.sharedFrom,
    super.settings,
    super.fullscreenDialog,
  }) : exit = exit ?? initial;

  /// Whether dragging from the start edge (left in LTR, right in RTL) pops the
  /// page. The page follows the finger; releasing past 40% of the width, or
  /// with a fast fling, pops it with the release velocity carried into the
  /// exit spring, and anything less springs it back. Taps in the edge strip
  /// still reach the page. Off by default.
  final bool backSwipe;

  /// How far (as a fraction of its width) this page slides sideways, behind the
  /// page above it, while that page is interactively back-swiped away: it
  /// starts `parallax` of a width off to the side and eases to rest as the top
  /// page leaves (mirrored in RTL), the iOS look. `0` disables it. Only takes
  /// effect while a route above uses `backSwipe`; pushes and ordinary pops
  /// never offset this page.
  final double parallax;

  /// Like [NibModalRoute.sharedFrom]: the page grows out of, and returns to,
  /// the widget owning this key.
  final GlobalKey? sharedFrom;

  final GlobalKey _contentKey = GlobalKey();

  /// Builds the page.
  final WidgetBuilder builder;

  /// The page's starting (and, by default, exiting) state.
  final NibAnim initial;

  /// The page's resting state.
  final NibAnim animate;

  /// The state the page animates to when popped. Defaults to [initial].
  final NibAnim exit;

  /// How the page moves between states.
  final NibTransition transition;

  /// How long the route takes to enter.
  final Duration duration;

  /// How long the route stays mounted after a pop.
  final Duration reverseDuration;

  @override
  final bool maintainState;

  bool _swipeActive = false;

  /// Opaque, except while an edge back-swipe is dragging the page away: then
  /// the route below must be built and painted behind it.
  @override
  bool get opaque => !_swipeActive;

  void _setSwipeActive(bool active) {
    if (_swipeActive == active) return;
    _swipeActive = active;
    if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = opaque;
    changedInternalState();
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration =>
      _atLeastSettle(reverseDuration, transition);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: KeyedSubtree(key: _contentKey, child: builder(context)),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final page = _NibRouteTransition(
      animation: animation,
      initial: initial,
      animate: animate,
      exit: exit,
      transition: transition,
      backSwipe: backSwipe,
      onSwipeActive: backSwipe ? _setSwipeActive : null,
      sharedFrom: sharedFrom,
      contentKey: _contentKey,
      child: child,
    );
    if (parallax <= 0) return page;
    return _NibParallaxShift(
      progress: _backSwipeProgressFor(Navigator.of(context)),
      secondaryAnimation: secondaryAnimation,
      parallax: parallax,
      child: page,
    );
  }
}
