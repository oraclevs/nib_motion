import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../debug/motion_value_inspector.dart';
import '../gestures/drag_handler.dart';
import '../gestures/gesture_state.dart';
import '../physics/inertia_solver.dart';
import '../physics/spring_description.dart';
import '../physics/spring_solver.dart';
import '../presence/presence_scope.dart';
import '../values/motion_value.dart';
import '../values/motion_value_types.dart';
import '../variants/nib_variants.dart';
import '../variants/variants_scope.dart';
import '../viewport/nib_in_view_config.dart';
import 'nib_anim.dart';
import 'nib_keyframe.dart';
import 'nib_motion_animator.dart';
import 'nib_motion_controller.dart';
import 'nib_motion_gate.dart';
import 'nib_motion_replay_scope.dart';
import 'nib_motion_values.dart';
import 'nib_transition.dart';
import 'reduced_motion.dart';
import 'render_nib_motion.dart';

/// Bridges the [MotionValue]s owned by [NibMotion] to [RenderNibMotion].
class _NibMotionBox extends SingleChildRenderObjectWidget {
  const _NibMotionBox({
    required this.opacity,
    required this.translateX,
    required this.translateY,
    required this.scaleX,
    required this.scaleY,
    required this.rotate,
    required this.skewX,
    required this.skewY,
    required this.color,
    required this.borderRadius,
    required this.boxShadow,
    super.child,
  });

  final MotionValue<double> opacity;
  final MotionValue<double> translateX;
  final MotionValue<double> translateY;
  final MotionValue<double> scaleX;
  final MotionValue<double> scaleY;
  final MotionValue<double> rotate;
  final MotionValue<double> skewX;
  final MotionValue<double> skewY;
  final MotionValue<Color?> color;
  final MotionValue<BorderRadius?> borderRadius;
  final BoxShadowMotionValue boxShadow;

  @override
  RenderNibMotion createRenderObject(BuildContext context) {
    return RenderNibMotion(
      opacity: opacity,
      translateX: translateX,
      translateY: translateY,
      scaleX: scaleX,
      scaleY: scaleY,
      rotate: rotate,
      skewX: skewX,
      skewY: skewY,
      color: color,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderNibMotion renderObject) {
    renderObject
      ..opacity = opacity
      ..translateX = translateX
      ..translateY = translateY
      ..scaleX = scaleX
      ..scaleY = scaleY
      ..rotate = rotate
      ..skewX = skewX
      ..skewY = skewY
      ..color = color
      ..borderRadius = borderRadius
      ..boxShadow = boxShadow;
  }
}

/// Declarative, physics-based animation for a single child.
///
/// `NibMotion` owns a [MotionValue] for each animatable property and drives
/// them with [SpringSolver] (when [NibTransition.spring] is set) or a
/// curve-based tween (otherwise). The [MotionValue]s are passed straight to
/// [RenderNibMotion], so animating never triggers a widget rebuild.
class NibMotion extends StatefulWidget {
  /// Creates a `NibMotion`.
  ///
  /// If [exit] is provided, [key] must be non-null so an ancestor
  /// `NibPresence` can track this widget across removals.
  const NibMotion({
    super.key,
    this.initial,
    this.animate,
    this.exit,
    this.whileTap,
    this.whileHover,
    this.whileFocus,
    this.whileDrag,
    this.drag,
    this.whileInView,
    this.viewport,
    this.variants,
    this.keyframes,
    this.motionValues,
    this.transition,
    this.controller,
    this.repeatAnimationInLoop = false,
    required this.child,
  }) : assert(
         exit == null || key != null,
         'NibMotion: exit animation requires a non-null key for NibPresence tracking.',
       ),
       assert(
         initial == null || initial is String || initial is NibAnim,
         'NibMotion.initial must be a String variant name or a NibAnim.',
       ),
       assert(
         animate == null || animate is String || animate is NibAnim,
         'NibMotion.animate must be a String variant name or a NibAnim.',
       );

  /// The animation values applied immediately on first build, before any
  /// transition runs. Defaults to [NibAnim.identity].
  ///
  /// Either a [NibAnim] or a [String] naming an entry in [variants].
  final Object? initial;

  /// The animation values to transition toward. `null` means "no change",
  /// unless [variants] is set and an ancestor `NibMotion` has propagated a
  /// variant name that matches one of its keys.
  ///
  /// Either a [NibAnim] or a [String] naming an entry in [variants]. When a
  /// [String], the name is also propagated to descendant `NibMotion`s with a
  /// matching [variants] entry and no explicit [animate].
  final Object? animate;

  /// The animation values to transition toward when an ancestor
  /// `NibPresence` removes this widget. Requires [key] to be set.
  final NibAnim? exit;

  /// The animation values to transition toward while this widget is pressed.
  final NibAnim? whileTap;

  /// The animation values to transition toward while the pointer hovers over
  /// this widget.
  final NibAnim? whileHover;

  /// The animation values to transition toward while this widget has input
  /// focus.
  final NibAnim? whileFocus;

  /// The animation values to transition toward while this widget is being
  /// dragged. Reverted to [animate] (or [initial]) when the drag ends.
  final NibAnim? whileDrag;

  /// Enables dragging this widget. If `null`, dragging is disabled.
  final NibDragConfig? drag;

  /// The animation values to transition toward while this widget is visible
  /// within the screen, according to [viewport].
  ///
  /// Unless [viewport]'s `once` is `true`, this reverts to [animate] (or
  /// [initial]) when the widget scrolls out of view.
  final NibAnim? whileInView;

  /// Configures the visibility check used by [whileInView]. Defaults to
  /// [NibInViewConfig.new]'s defaults when [whileInView] is set.
  final NibInViewConfig? viewport;

  /// Named animation states this widget can resolve [initial]/[animate]
  /// string names against, and that it checks against the variant name
  /// propagated by an ancestor `NibMotion` when [animate] is `null`.
  final NibVariants? variants;

  /// A multi-step enter animation that overrides [initial] and [animate].
  ///
  /// When non-null, this widget starts at `keyframes.first.value`, then runs
  /// a single tween [AnimationController] from `0.0` to `1.0` over
  /// [NibTransition.duration], applying [computeAnimFromKeyframes] at each
  /// tick. Spring transitions ([NibTransition.spring]) are not supported with
  /// [keyframes]; [NibTransition.curve] is used as the default per-segment
  /// curve.
  final List<NibKeyframe>? keyframes;

  /// Pre-built [MotionValue]s that drive this widget's animatable
  /// properties directly, bypassing the internal spring/tween system for
  /// any property they provide.
  final NibMotionValues? motionValues;

  /// The transition used for [animate] (and as a default for gesture
  /// states that don't specify their own).
  ///
  /// If `null`, falls back to `NibMotionConfig.defaultTransitionOf(context)`
  /// (or [NibTransition]'s defaults if there is no `NibMotionConfig`
  /// ancestor).
  final NibTransition? transition;

  /// An optional external handle for driving this widget's animations.
  final NibMotionController? controller;

  /// When `true`, instead of running the normal one-shot entrance animation
  /// (`initial` -> `animate`, or [keyframes] `0.0` -> `1.0`), this widget
  /// ping-pongs forever: `initial` -> `animate` (or [keyframes] `0.0` ->
  /// `1.0` -> `0.0` -> `1.0` ...) -> `initial` -> `animate` -> ..., using
  /// [NibTransition.duration]/[NibTransition.curve] from [transition] (or
  /// `NibMotionConfig.defaultTransitionOf(context)`).
  ///
  /// Has no effect if [motionValues] is set. If
  /// `NibMotionConfig.shouldReduceMotion(context)` is `true`, this jumps to
  /// the end of the cycle once and does not loop.
  ///
  /// Can be toggled at runtime via [NibMotionController.repeat] (using
  /// [controller]), independent of this field's value.
  final bool repeatAnimationInLoop;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  State<NibMotion> createState() => _NibMotionState();
}

class _NibMotionState extends State<NibMotion> with TickerProviderStateMixin implements NibMotionAnimator {
  late final MotionValue<double> _opacity;
  late final MotionValue<double> _translateX;
  late final MotionValue<double> _translateY;
  late final MotionValue<double> _scaleX;
  late final MotionValue<double> _scaleY;
  late final MotionValue<double> _rotate;
  late final MotionValue<double> _skewX;
  late final MotionValue<double> _skewY;
  late final MotionValue<Color?> _color;
  late final MotionValue<BorderRadius?> _borderRadius;
  late final BoxShadowMotionValue _boxShadow;

  /// A stable id for this instance's entries in [NibMotionRegistry] —
  /// the widget's own [Key] if it has one (so the debugger can show a
  /// meaningful name), falling back to this State's identity hash.
  late final String _debugId =
      'NibMotion#${widget.key ?? identityHashCode(this)}';

  final Map<String, SpringSolver> _springSolvers = <String, SpringSolver>{};
  final Map<String, AnimationController> _tweenControllers = <String, AnimationController>{};
  final Map<String, VoidCallback> _tweenListeners = <String, VoidCallback>{};
  final Map<String, InertiaSolver> _inertiaSolvers = <String, InertiaSolver>{};

  NibGestureState _gestureState = NibGestureState.none;
  bool _isHovering = false;
  NibPresenceRegistration? _presenceRegistration;
  DragHandler? _dragHandler;
  Offset _dragBase = Offset.zero;

  final VariantsIndexCounter _childIndexCounter = VariantsIndexCounter();
  String? _lastVariantName;
  int? _staggerIndex;
  Timer? _staggerTimer;
  Timer? _delayedAnimateTimer;
  Timer? _entranceGateTimer;
  Timer? _replayTimer;
  VoidCallback? _entranceGateListener;
  bool _runningEntranceGateCallback = false;
  bool _deactivated = false;
  AnimationController? _keyframeController;
  AnimationController? _loopController;
  bool? _wasTickerEnabled;
  bool _isInView = false;
  Set<ScrollPosition> _scrollPositions = const {};
  NibMotionReplaySignal? _replaySignal;

  @override
  void initState() {
    super.initState();
    final keyframes = widget.keyframes;
    final start = keyframes != null
        ? computeAnimFromKeyframes(keyframes, 0.0, Curves.linear)
        : (_resolveAnim(widget.initial) ?? NibAnim.identity);
    final external = widget.motionValues;
    _opacity = external?.opacity ?? MotionValue(start.opacity ?? NibAnim.identity.opacity!);
    _translateX = external?.translateX ?? MotionValue(start.x ?? NibAnim.identity.x!);
    _translateY = external?.translateY ?? MotionValue(start.y ?? NibAnim.identity.y!);
    _scaleX = external?.scaleX ?? MotionValue(_resolveScaleX(start) ?? NibAnim.identity.scaleX!);
    _scaleY = external?.scaleY ?? MotionValue(_resolveScaleY(start) ?? NibAnim.identity.scaleY!);
    _rotate = external?.rotate ?? MotionValue(start.rotate ?? NibAnim.identity.rotate!);
    _skewX = external?.skewX ?? MotionValue(start.skewX ?? NibAnim.identity.skewX!);
    _skewY = external?.skewY ?? MotionValue(start.skewY ?? NibAnim.identity.skewY!);
    _color = external?.color ?? MotionValue<Color?>(start.color);
    _borderRadius = external?.borderRadius ?? MotionValue<BorderRadius?>(start.borderRadius);
    _boxShadow = external?.boxShadow ?? MotionValue<List<BoxShadow>?>(start.boxShadow);

    if (kDebugMode) _registerDebugValues();

    widget.controller?.attach(this);

    if (widget.whileInView != null) _scheduleInViewCheck();

    if (widget.repeatAnimationInLoop) {
      _startRepeatLoop();
      return;
    }

    if (keyframes != null) {
      _startKeyframeAnimation(keyframes);
      return;
    }

    final animate = widget.animate;
    if (animate is String) _lastVariantName = animate;
    final target = _resolveAnim(animate);
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Reduced-motion entrances jump straight to `target` with no visible
        // animation, so there's nothing for the splash/warm-up gate to hide —
        // skip it so `setImmediately` isn't held behind a timer.
        if (NibMotionConfig.shouldReduceMotion(context)) {
          setImmediately(target);
          return;
        }
        _afterEntranceGate(() {
          if (!mounted) return;
          animateTo(target);
        });
      });
    }
  }

  /// Defers [callback] until [NibMotionGate.ready] is `true` and
  /// [NibMotionConfig.entranceWarmup] has elapsed since app start.
  ///
  /// Used to hold entrance animations (`animate`/`keyframes` on first build,
  /// and an immediately-visible `whileInView`) until the app is actually
  /// visible to the user. No-op delay once both conditions are already met,
  /// which is always true after the app's initial warm-up window.
  void _afterEntranceGate(VoidCallback callback) {
    if (!NibMotionGate.ready.value) {
      void listener() {
        if (!NibMotionGate.ready.value) return;
        NibMotionGate.ready.removeListener(listener);
        _entranceGateListener = null;
        _afterEntranceGate(callback);
      }

      _entranceGateListener = listener;
      NibMotionGate.ready.addListener(listener);
      return;
    }

    final remaining = NibMotionConfig.remainingWarmup(context);
    if (remaining <= Duration.zero) {
      callback();
      return;
    }
    _entranceGateTimer = Timer(remaining, () {
      _entranceGateTimer = null;
      if (!mounted) return;
      _runningEntranceGateCallback = true;
      try {
        callback();
      } finally {
        _runningEntranceGateCallback = false;
      }
    });
    // Keep a frame scheduled until the timer above fires, so widget tests
    // using `pumpAndSettle` (which only keeps pumping while a frame is
    // scheduled) advance through the warm-up window instead of bailing out
    // early.
    _keepFrameScheduledUntilGateTimerFires();
  }

  /// Cancels any pending entrance-gate timer/listener from [_afterEntranceGate].
  ///
  /// Called whenever [animateTo] runs for a reason other than the deferred
  /// entrance animation itself (e.g. a `whileTap`/`whileHover` interaction).
  /// Without this, a deferred entrance `animate` call that resolves later
  /// could overwrite the in-progress interaction animation with its own
  /// (often identical-looking, but stale) target.
  void _cancelEntranceGate() {
    _entranceGateTimer?.cancel();
    _entranceGateTimer = null;
    final listener = _entranceGateListener;
    if (listener != null) {
      NibMotionGate.ready.removeListener(listener);
      _entranceGateListener = null;
    }
  }

  void _keepFrameScheduledUntilGateTimerFires() {
    if (_entranceGateTimer == null) return;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;
      _keepFrameScheduledUntilGateTimerFires();
    });
  }

  /// Drives this widget's enter animation through [keyframes] via a single
  /// tween [AnimationController] going `0.0` → `1.0`, applying
  /// [computeAnimFromKeyframes] at each tick. See [NibMotion.keyframes].
  void _startKeyframeAnimation(List<NibKeyframe> keyframes) {
    final transition = widget.transition ?? NibMotionConfig.defaultTransitionOf(context);

    if (NibMotionConfig.shouldReduceMotion(context)) {
      setImmediately(computeAnimFromKeyframes(keyframes, 1.0, transition.curve));
      return;
    }

    final controller = AnimationController(vsync: this, duration: transition.duration);
    _keyframeController = controller;
    controller.addListener(() {
      setImmediately(computeAnimFromKeyframes(keyframes, controller.value, transition.curve));
    });
    _afterEntranceGate(() {
      if (!mounted) return;
      controller.forward(from: 0.0);
    });
  }

  /// Starts (or restarts) [NibMotion.repeatAnimationInLoop]'s forever
  /// ping-pong loop: `initial` -> `animate` (or [NibMotion.keyframes] `0.0`
  /// -> `1.0`) -> `initial` -> `animate` -> ..., via a repeating
  /// [AnimationController] with `reverse: true`.
  ///
  /// Has no effect if [NibMotion.motionValues] is set. If
  /// `NibMotionConfig.shouldReduceMotion(context)` is `true`, jumps to the
  /// end of the cycle once and does not loop.
  void _startRepeatLoop() {
    if (widget.motionValues != null) return;

    final transition = widget.transition ?? NibMotionConfig.defaultTransitionOf(context);
    final keyframes = widget.keyframes;

    if (NibMotionConfig.shouldReduceMotion(context)) {
      if (keyframes != null) {
        setImmediately(computeAnimFromKeyframes(keyframes, 1.0, transition.curve));
      } else {
        final from = NibAnim.identity.merge(_resolveAnim(widget.initial) ?? NibAnim.identity);
        final to = NibAnim.identity.merge(_resolveAnim(widget.animate) ?? from);
        setImmediately(to);
      }
      return;
    }

    _loopController?.dispose();
    final controller = AnimationController(vsync: this, duration: transition.duration);
    _loopController = controller;

    if (keyframes != null) {
      controller.addListener(() {
        setImmediately(computeAnimFromKeyframes(keyframes, controller.value, transition.curve));
      });
    } else {
      final from = NibAnim.identity.merge(_resolveAnim(widget.initial) ?? NibAnim.identity);
      final to = NibAnim.identity.merge(_resolveAnim(widget.animate) ?? from);
      controller.addListener(() {
        setImmediately(from.lerp(to, transition.curve.transform(controller.value)));
      });
    }

    _afterEntranceGate(() {
      if (!mounted) return;
      controller.repeat(reverse: true);
    });
  }

  static double? _resolveScaleX(NibAnim anim) => anim.scaleX ?? anim.scale;
  static double? _resolveScaleY(NibAnim anim) => anim.scaleY ?? anim.scale;

  /// Resolves [value] (a [NibMotion.initial]/[NibMotion.animate]) to a
  /// [NibAnim]: returns it directly if it already is one, looks it up in
  /// [NibMotion.variants] if it's a variant name [String], or `null` if
  /// [value] is `null` or the name isn't in [NibMotion.variants].
  NibAnim? _resolveAnim(Object? value) {
    if (value == null) return null;
    if (value is NibAnim) return value;
    if (value is String) return widget.variants?[value];
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registration = NibPresenceScope.maybeOf(context);
    if (!identical(registration, _presenceRegistration)) {
      final key = widget.key;
      if (key != null) {
        _presenceRegistration?.unregister(key);
        registration?.register(key, this);
      }
      _presenceRegistration = registration;
    }

    // ignore: deprecated_member_use, TickerMode.valuesOf requires a newer Flutter than this package's minimum.
    final tickerEnabled = TickerMode.of(context);
    if (_wasTickerEnabled == false && tickerEnabled) {
      _replayEntranceAnimation();
    }
    _wasTickerEnabled = tickerEnabled;

    if (widget.whileInView != null) {
      // Establishes a MediaQuery dependency so resizes re-run this method.
      MediaQuery.sizeOf(context);
      _attachScrollListener();
      _scheduleInViewCheck();
    }

    final replaySignal = NibMotionReplayScope.maybeOf(context);
    if (!identical(replaySignal, _replaySignal)) {
      _replaySignal?.removeListener(_onReplaySignal);
      replaySignal?.addListener(_onReplaySignal);
      _replaySignal = replaySignal;
    }
  }

  /// Replays the enter animation, as if this widget had just been built for
  /// the first time.
  ///
  /// Called when [TickerMode] turns back on after being off — which happens
  /// when a [Route] that was covered by another route (e.g. via
  /// [Navigator.push]) becomes current again (e.g. via [Navigator.pop]).
  /// This lets a screen's entrance animation play again on return without
  /// requiring a [NibMotionController].
  void _replayEntranceAnimation() {
    if (widget.motionValues != null) return;

    _gestureState = NibGestureState.none;

    if (widget.whileInView != null) {
      _isInView = false;
      _scheduleInViewCheckRepeatedly();
    }

    if (widget.repeatAnimationInLoop) {
      _loopController?.dispose();
      _loopController = null;
      final keyframes = widget.keyframes;
      if (keyframes != null) {
        final start = computeAnimFromKeyframes(keyframes, 0.0, Curves.linear);
        setImmediately(NibAnim.identity.merge(start));
      } else {
        final start = _resolveAnim(widget.initial) ?? NibAnim.identity;
        setImmediately(NibAnim.identity.merge(start));
      }
      _startRepeatLoop();
      return;
    }

    final keyframes = widget.keyframes;
    if (keyframes != null) {
      final start = computeAnimFromKeyframes(keyframes, 0.0, Curves.linear);
      setImmediately(NibAnim.identity.merge(start));
      _keyframeController?.dispose();
      _keyframeController = null;
      _startKeyframeAnimation(keyframes);
      return;
    }

    final start = _resolveAnim(widget.initial) ?? NibAnim.identity;
    setImmediately(NibAnim.identity.merge(start));
    final target = _resolveAnim(widget.animate);
    if (target != null) animateTo(target);
  }

  /// Called when the nearest ancestor [NibMotionReplayScope]'s
  /// [NibMotionReplaySignal] fires — replays this widget's entrance
  /// animation, the same as [_replayEntranceAnimation].
  void _onReplaySignal() {
    if (!mounted) return;
    final delay = _replaySignal?.lastReplayDelay ?? Duration.zero;
    if (delay == Duration.zero) {
      _replayEntranceAnimation();
      return;
    }
    _replayTimer?.cancel();
    _replayTimer = Timer(delay, () {
      _replayTimer = null;
      if (mounted) _replayEntranceAnimation();
    });
  }

  @override
  void didUpdateWidget(NibMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    final animate = widget.animate;
    if (animate != null && animate != oldWidget.animate && _gestureState == NibGestureState.none) {
      if (animate is String) _lastVariantName = animate;
      final target = _resolveAnim(animate);
      if (target != null) animateTo(target);
    }

    if (widget.whileInView == null && oldWidget.whileInView != null) {
      for (final position in _scrollPositions) {
        position.removeListener(_onScrollOrResize);
      }
      _scrollPositions = const {};
      _isInView = false;
    } else if (widget.whileInView != null && oldWidget.whileInView == null) {
      _scheduleInViewCheck();
    }

    if (widget.repeatAnimationInLoop != oldWidget.repeatAnimationInLoop) {
      if (widget.repeatAnimationInLoop) {
        _startRepeatLoop();
      } else {
        _loopController?.stop();
      }
    }
  }

  @override
  Future<void> animateTo(NibAnim target, {NibTransition? transition}) {
    // `GestureRecognizer.dispose()` can synchronously trigger
    // `handleTapCancel` -> `_onTapEnd` -> `_revertFromGesture` -> `animateTo`
    // while this element is inactive/being unmounted (see [deactivate] and
    // [dispose]). Bail out rather than touching `context` (e.g. via
    // `shouldReduceMotion`) on a deactivated element.
    if (_deactivated || !context.mounted) return Future.value();

    if (!_runningEntranceGateCallback) _cancelEntranceGate();

    if (NibMotionConfig.shouldReduceMotion(context)) {
      setImmediately(target);
      return Future.value();
    }

    final effective = transition ?? widget.transition ?? NibMotionConfig.defaultTransitionOf(context);

    final delay = effective.delay;
    if (delay > Duration.zero) {
      _delayedAnimateTimer?.cancel();
      final completer = Completer<void>();
      _delayedAnimateTimer = Timer(delay, () {
        _runAnimation(target, effective).then((_) {
          if (!completer.isCompleted) completer.complete();
        });
      });
      return completer.future;
    }

    return _runAnimation(target, effective);
  }

  Future<void> _runAnimation(NibAnim target, NibTransition effective) {
    final futures = <Future<void>>[];

    void addDouble(MotionValue<double> value, String key, double? targetValue) {
      final future = _animateDouble(value, key, targetValue, effective);
      if (future != null) futures.add(future);
    }

    addDouble(_opacity, 'opacity', target.opacity);
    addDouble(_translateX, 'translateX', target.x);
    addDouble(_translateY, 'translateY', target.y);
    addDouble(_scaleX, 'scaleX', _resolveScaleX(target));
    addDouble(_scaleY, 'scaleY', _resolveScaleY(target));
    addDouble(_rotate, 'rotate', target.rotate);
    addDouble(_skewX, 'skewX', target.skewX);
    addDouble(_skewY, 'skewY', target.skewY);

    final color = target.color;
    if (color != null) {
      futures.add(_animateWithTween<Color?>(_color, 'color', color, effective, Color.lerp));
    }

    final borderRadius = target.borderRadius;
    if (borderRadius != null) {
      futures.add(_animateWithTween<BorderRadius?>(_borderRadius, 'borderRadius', borderRadius, effective, BorderRadius.lerp));
    }

    final boxShadow = target.boxShadow;
    if (boxShadow != null) {
      futures.add(_animateWithTween<List<BoxShadow>?>(_boxShadow, 'boxShadow', boxShadow, effective, BoxShadow.lerpList));
    }

    return Future.wait(futures).then((_) {});
  }

  Future<void>? _animateDouble(MotionValue<double> value, String key, double? target, NibTransition transition) {
    if (target == null) return null;

    _inertiaSolvers[key]?.stop();

    final spring = transition.spring;
    if (spring != null) {
      _tweenControllers[key]?.stop();
      final solver = _springSolvers.putIfAbsent(key, () => SpringSolver(vsync: this, value: value, spring: spring));
      solver.spring = spring;
      final completer = Completer<void>();
      solver.onComplete = () {
        if (!completer.isCompleted) completer.complete();
      };
      solver.animateTo(target: target);
      return completer.future;
    }

    _springSolvers[key]?.stop();
    return _animateWithTween<double>(value, key, target, transition, (a, b, t) => a + (b - a) * t);
  }

  Future<void> _animateWithTween<T>(
    MotionValue<T> value,
    String key,
    T target,
    NibTransition transition,
    T Function(T a, T b, double t) lerp,
  ) {
    final begin = value.value;
    if (begin == target) return Future.value();

    final controller = _tweenControllers.putIfAbsent(key, () => AnimationController(vsync: this));
    final oldListener = _tweenListeners.remove(key);
    if (oldListener != null) controller.removeListener(oldListener);

    void listener() {
      final t = transition.curve.transform(controller.value);
      value.value = lerp(begin, target, t);
    }

    _tweenListeners[key] = listener;
    controller.addListener(listener);
    controller.duration = transition.duration;
    return controller.forward(from: 0.0).then((_) {});
  }

  @override
  Future<void> triggerExit() {
    final exit = widget.exit;
    if (exit == null) return Future.value();
    return animateTo(exit);
  }

  @override
  void setImmediately(NibAnim target) {
    void setDouble(MotionValue<double> value, String key, double? targetValue) {
      if (targetValue == null) return;
      _springSolvers[key]?.stop();
      _tweenControllers[key]?.stop();
      _inertiaSolvers[key]?.stop();
      value.value = targetValue;
    }

    setDouble(_opacity, 'opacity', target.opacity);
    setDouble(_translateX, 'translateX', target.x);
    setDouble(_translateY, 'translateY', target.y);
    setDouble(_scaleX, 'scaleX', _resolveScaleX(target));
    setDouble(_scaleY, 'scaleY', _resolveScaleY(target));
    setDouble(_rotate, 'rotate', target.rotate);
    setDouble(_skewX, 'skewX', target.skewX);
    setDouble(_skewY, 'skewY', target.skewY);

    final color = target.color;
    if (color != null) {
      _tweenControllers['color']?.stop();
      _color.value = color;
    }

    final borderRadius = target.borderRadius;
    if (borderRadius != null) {
      _tweenControllers['borderRadius']?.stop();
      _borderRadius.value = borderRadius;
    }

    final boxShadow = target.boxShadow;
    if (boxShadow != null) {
      _tweenControllers['boxShadow']?.stop();
      _boxShadow.value = boxShadow;
    }
  }

  @override
  void stopAnimations() {
    for (final solver in _springSolvers.values) {
      solver.stop();
    }
    for (final controller in _tweenControllers.values) {
      controller.stop();
    }
    for (final solver in _inertiaSolvers.values) {
      solver.stop();
    }
  }

  @override
  Future<void> replayEntrance() {
    _replayEntranceAnimation();
    return Future.value();
  }

  @override
  Future<void> playKeyframes(List<NibKeyframe> keyframes, {NibTransition? transition}) {
    if (_deactivated || !context.mounted) return Future.value();

    final effective = transition ?? widget.transition ?? NibMotionConfig.defaultTransitionOf(context);

    if (NibMotionConfig.shouldReduceMotion(context)) {
      setImmediately(computeAnimFromKeyframes(keyframes, 1.0, effective.curve));
      return Future.value();
    }

    _keyframeController?.dispose();

    final controller = AnimationController(vsync: this, duration: effective.duration);
    _keyframeController = controller;
    controller.addListener(() {
      setImmediately(computeAnimFromKeyframes(keyframes, controller.value, effective.curve));
    });

    return controller.forward(from: 0.0).then((_) {});
  }

  @override
  void setRepeatLoop(bool enabled) {
    if (enabled) {
      _startRepeatLoop();
    } else {
      _loopController?.stop();
    }
  }

  void _onTapDown(TapDownDetails details) {
    _gestureState = NibGestureState.tap;
    final target = widget.whileTap;
    if (target != null) animateTo(target, transition: NibTransition.springSnappy);
  }

  void _onTapEnd() {
    _gestureState = _isHovering ? NibGestureState.hover : NibGestureState.none;
    _revertFromGesture();
  }

  void _onHoverEnter(PointerEnterEvent event) {
    _isHovering = true;
    if (_gestureState == NibGestureState.tap || _gestureState == NibGestureState.drag) return;
    _gestureState = NibGestureState.hover;
    final target = widget.whileHover;
    if (target != null) animateTo(target);
  }

  void _onHoverExit(PointerExitEvent event) {
    _isHovering = false;
    if (_gestureState == NibGestureState.tap || _gestureState == NibGestureState.drag) return;
    _gestureState = NibGestureState.none;
    _revertFromGesture();
  }

  void _onFocusChange(bool focused) {
    if (focused) {
      if (_gestureState == NibGestureState.tap ||
          _gestureState == NibGestureState.hover ||
          _gestureState == NibGestureState.drag) {
        return;
      }
      _gestureState = NibGestureState.focus;
      final target = widget.whileFocus;
      if (target != null) animateTo(target);
    } else if (_gestureState == NibGestureState.focus) {
      _gestureState = NibGestureState.none;
      _revertFromGesture();
    }
  }

  void _revertFromGesture() {
    final hoverTarget = widget.whileHover;
    final target = _gestureState == NibGestureState.hover && hoverTarget != null
        ? hoverTarget
        : (_resolveAnim(widget.animate) ?? _resolveAnim(widget.initial) ?? NibAnim.identity);
    animateTo(target);
  }

  /// Attaches [_onScrollOrResize] to every ancestor [Scrollable]'s
  /// [ScrollPosition], replacing any previously attached listeners.
  ///
  /// A single nearest-ancestor lookup isn't enough: a widget with
  /// `whileInView` that lives inside a horizontal list nested in a vertical
  /// scroll view only has the horizontal list as its nearest [Scrollable],
  /// so it would never be notified when the outer (vertical) scroll view
  /// moves it on/off screen. Listening to every ancestor scroll position
  /// covers nested scrollables in any combination.
  void _attachScrollListener() {
    final positions = <ScrollPosition>{};
    context.visitAncestorElements((element) {
      final state = element is StatefulElement ? element.state : null;
      if (state is ScrollableState) positions.add(state.position);
      return true;
    });

    if (setEquals(positions, _scrollPositions)) return;

    for (final position in _scrollPositions) {
      position.removeListener(_onScrollOrResize);
    }
    for (final position in positions) {
      position.addListener(_onScrollOrResize);
    }
    _scrollPositions = positions;
  }

  void _onScrollOrResize() {
    _scheduleInViewCheck();
  }

  /// Defers [_checkInView] to a post-frame callback, since layout hasn't
  /// caught up with the latest scroll offset or size yet when this is
  /// called.
  void _scheduleInViewCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkInView();
    });
  }

  /// Like [_scheduleInViewCheck], but keeps re-checking for up to
  /// [framesRemaining] subsequent frames.
  ///
  /// Used when replaying the entrance animation on route-revisit: the
  /// covered route becoming current again drives a page-transition
  /// animation that transiently translates/scales this whole subtree for
  /// its duration (commonly ~300ms). A single post-frame check can land
  /// mid-transition, see this widget shifted partially off-screen, and
  /// permanently conclude it's out of view even though it ends up fully
  /// visible once the transition settles. Re-checking on each subsequent
  /// frame rides out the transition and lands on its final position. The
  /// chain stops on its own once frames stop being produced.
  void _scheduleInViewCheckRepeatedly([int framesRemaining = 30]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkInView();
      if (framesRemaining > 0) _scheduleInViewCheckRepeatedly(framesRemaining - 1);
    });
  }

  /// Computes how much of this widget is visible within the screen and
  /// updates [_isInView] accordingly. See [NibMotion.whileInView].
  void _checkInView() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) return;

    final size = renderObject.size;
    if (size.isEmpty) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);

    final config = widget.viewport ?? const NibInViewConfig();
    final screenSize = MediaQuery.sizeOf(context);
    final margin = config.margin;
    final viewportBounds = Rect.fromLTRB(
      -margin.left,
      -margin.top,
      screenSize.width + margin.right,
      screenSize.height + margin.bottom,
    );

    final intersection = bounds.intersect(viewportBounds);
    final visibleArea = intersection.isEmpty ? 0.0 : intersection.width * intersection.height;
    final totalArea = bounds.width * bounds.height;
    final visibleFraction = totalArea <= 0 ? 0.0 : visibleArea / totalArea;

    _updateInView(visibleFraction >= config.amount);
  }

  void _updateInView(bool inView) {
    if (inView == _isInView) return;
    _isInView = inView;

    if (inView) {
      final target = widget.whileInView;
      if (target != null) {
        _afterEntranceGate(() {
          if (!mounted) return;
          animateTo(target);
        });
      }
      if (widget.viewport?.once ?? false) {
        for (final position in _scrollPositions) {
          position.removeListener(_onScrollOrResize);
        }
        _scrollPositions = const {};
      }
    } else {
      _revertFromInView();
    }
  }

  void _revertFromInView() {
    final target = _resolveAnim(widget.animate) ?? _resolveAnim(widget.initial) ?? NibAnim.identity;
    animateTo(target);
  }

  void _onPanStart(DragStartDetails details) {
    final drag = widget.drag;
    if (drag == null) return;

    _gestureState = NibGestureState.drag;
    _dragBase = Offset(_translateX.value, _translateY.value);

    _springSolvers['translateX']?.stop();
    _springSolvers['translateY']?.stop();
    _inertiaSolvers['translateX']?.stop();
    _inertiaSolvers['translateY']?.stop();
    _tweenControllers['translateX']?.stop();
    _tweenControllers['translateY']?.stop();

    _dragHandler = DragHandler(
      config: drag,
      onUpdate: (offset) {
        _translateX.value = _dragBase.dx + offset.dx;
        _translateY.value = _dragBase.dy + offset.dy;
      },
      onRelease: _onDragRelease,
    )..handlePanStart(details);

    final target = widget.whileDrag;
    if (target != null) animateTo(target);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragHandler?.handlePanUpdate(details);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragHandler?.handlePanEnd(details);
    _dragHandler = null;
  }

  void _onDragRelease(Offset offset, Velocity velocity) {
    final drag = widget.drag!;
    drag.onDragEnd?.call(velocity);

    _gestureState = _isHovering ? NibGestureState.hover : NibGestureState.none;

    final snapPoints = drag.snapPoints;
    if (snapPoints != null && snapPoints.isNotEmpty) {
      final current = Offset(_translateX.value, _translateY.value);
      final nearest = snapPoints.reduce(
        (a, b) => (a - current).distanceSquared <= (b - current).distanceSquared ? a : b,
      );
      _springTo(nearest, velocity);
    } else {
      switch (drag.releaseMode) {
        case NibDragReleaseMode.springBack:
          _springTo(_dragBase, velocity);
        case NibDragReleaseMode.inertia:
          _coastWithInertia(velocity);
        case NibDragReleaseMode.stay:
          break;
      }
    }

    if (widget.whileDrag != null) {
      final base = _resolveAnim(widget.animate) ?? _resolveAnim(widget.initial) ?? NibAnim.identity;
      animateTo(
        NibAnim(
          scale: base.scale,
          scaleX: base.scaleX,
          scaleY: base.scaleY,
          rotate: base.rotate,
          skewX: base.skewX,
          skewY: base.skewY,
          opacity: base.opacity,
          color: base.color,
          borderRadius: base.borderRadius,
          boxShadow: base.boxShadow,
        ),
      );
    }
  }

  void _springTo(Offset target, Velocity velocity) {
    final transition = widget.transition ?? NibMotionConfig.defaultTransitionOf(context);
    final spring = transition.spring ?? NibSpringDescription.gentle;

    _tweenControllers['translateX']?.stop();
    _tweenControllers['translateY']?.stop();
    _inertiaSolvers['translateX']?.stop();
    _inertiaSolvers['translateY']?.stop();

    final solverX = _springSolvers.putIfAbsent('translateX', () => SpringSolver(vsync: this, value: _translateX, spring: spring));
    solverX.spring = spring;
    solverX.animateTo(target: target.dx, initialVelocity: velocity.pixelsPerSecond.dx);

    final solverY = _springSolvers.putIfAbsent('translateY', () => SpringSolver(vsync: this, value: _translateY, spring: spring));
    solverY.spring = spring;
    solverY.animateTo(target: target.dy, initialVelocity: velocity.pixelsPerSecond.dy);
  }

  /// Resolves this widget's `animate` against the variant name set by its
  /// own [NibMotion.animate] (if a [String]) or propagated by the nearest
  /// ancestor [VariantsScope] (if [NibMotion.animate] is `null` and
  /// [NibMotion.variants] is set), and animates toward the matching
  /// [NibMotion.variants] entry if the resolved name changed and has a match.
  ///
  /// When inheriting the variant name from [ancestorScope], the animation is
  /// offset by `ancestorScope.delayChildren + index * ancestorScope.staggerChildren`,
  /// where `index` is this widget's claimed [VariantsIndexCounter] index.
  void _maybeSyncVariant(VariantsScope? ancestorScope) {
    final animate = widget.animate;
    String? variantName;
    var delay = Duration.zero;

    if (animate is String) {
      variantName = animate;
    } else if (animate == null && widget.variants != null && ancestorScope != null) {
      variantName = ancestorScope.variant;
      _staggerIndex ??= ancestorScope.indexCounter.next();
      delay = ancestorScope.delayChildren + ancestorScope.staggerChildren * _staggerIndex!;
    }

    if (variantName == null || variantName == _lastVariantName) return;
    _lastVariantName = variantName;

    final target = widget.variants?[variantName];
    if (target == null) return;

    if (delay == Duration.zero) {
      animateTo(target);
    } else {
      _staggerTimer?.cancel();
      _staggerTimer = Timer(delay, () => animateTo(target));
    }
  }

  void _coastWithInertia(Velocity velocity) {
    _tweenControllers['translateX']?.stop();
    _tweenControllers['translateY']?.stop();
    _springSolvers['translateX']?.stop();
    _springSolvers['translateY']?.stop();

    final solverX = _inertiaSolvers.putIfAbsent('translateX', () => InertiaSolver(vsync: this, value: _translateX));
    solverX.animateTo(velocity: velocity.pixelsPerSecond.dx);

    final solverY = _inertiaSolvers.putIfAbsent('translateY', () => InertiaSolver(vsync: this, value: _translateY));
    solverY.animateTo(velocity: velocity.pixelsPerSecond.dy);
  }

  @override
  void deactivate() {
    // Marks this element as no longer safe for ancestor lookups
    // (`getInheritedWidgetOfExactType`, etc). When a whole subtree is
    // removed, every element in it is deactivated together, before any of
    // their `dispose()` methods run. A descendant `GestureDetector`'s
    // `TapGestureRecognizer.dispose()` can synchronously call
    // `handleTapCancel` -> `_onTapEnd` -> `_revertFromGesture` ->
    // `animateTo` on *this* state while this element is `inactive` but not
    // yet `defunct` (so `context.mounted` is still true) — `animateTo` must
    // bail out in that case too, or ancestor lookups throw "Looking up a
    // deactivated widget's ancestor is unsafe".
    _deactivated = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _deactivated = false;
  }

  /// Registers every animatable [MotionValue] this instance owns with
  /// [NibMotionRegistry], so `NibMotionDebugger`'s live-values panel has
  /// something to show. No-op outside [kDebugMode] (checked by the caller,
  /// and again by [NibMotionRegistry] itself).
  void _registerDebugValues() {
    final registry = NibMotionRegistry.instance;
    registry.register('$_debugId.opacity', _opacity);
    registry.register('$_debugId.translateX', _translateX);
    registry.register('$_debugId.translateY', _translateY);
    registry.register('$_debugId.scaleX', _scaleX);
    registry.register('$_debugId.scaleY', _scaleY);
    registry.register('$_debugId.rotate', _rotate);
    registry.register('$_debugId.skewX', _skewX);
    registry.register('$_debugId.skewY', _skewY);
    registry.register('$_debugId.color', _color);
    registry.register('$_debugId.borderRadius', _borderRadius);
    registry.register('$_debugId.boxShadow', _boxShadow);
  }

  /// Removes every entry [_registerDebugValues] added.
  void _unregisterDebugValues() {
    final registry = NibMotionRegistry.instance;
    registry.unregister('$_debugId.opacity');
    registry.unregister('$_debugId.translateX');
    registry.unregister('$_debugId.translateY');
    registry.unregister('$_debugId.scaleX');
    registry.unregister('$_debugId.scaleY');
    registry.unregister('$_debugId.rotate');
    registry.unregister('$_debugId.skewX');
    registry.unregister('$_debugId.skewY');
    registry.unregister('$_debugId.color');
    registry.unregister('$_debugId.borderRadius');
    registry.unregister('$_debugId.boxShadow');
  }

  @override
  void dispose() {
    if (kDebugMode) _unregisterDebugValues();
    _replaySignal?.removeListener(_onReplaySignal);
    _staggerTimer?.cancel();
    _delayedAnimateTimer?.cancel();
    _replayTimer?.cancel();
    _cancelEntranceGate();
    _keyframeController?.dispose();
    _loopController?.dispose();
    for (final position in _scrollPositions) {
      position.removeListener(_onScrollOrResize);
    }
    final key = widget.key;
    if (key != null) _presenceRegistration?.unregister(key);
    widget.controller?.detach(this);

    for (final solver in _springSolvers.values) {
      solver.dispose();
    }
    for (final controller in _tweenControllers.values) {
      controller.dispose();
    }
    for (final solver in _inertiaSolvers.values) {
      solver.dispose();
    }

    final external = widget.motionValues;
    if (external?.opacity == null) _opacity.dispose();
    if (external?.translateX == null) _translateX.dispose();
    if (external?.translateY == null) _translateY.dispose();
    if (external?.scaleX == null) _scaleX.dispose();
    if (external?.scaleY == null) _scaleY.dispose();
    if (external?.rotate == null) _rotate.dispose();
    if (external?.skewX == null) _skewX.dispose();
    if (external?.skewY == null) _skewY.dispose();
    if (external?.color == null) _color.dispose();
    if (external?.borderRadius == null) _borderRadius.dispose();
    if (external?.boxShadow == null) _boxShadow.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancestorScope = VariantsScope.of(context);
    _maybeSyncVariant(ancestorScope);

    final animate = widget.animate;
    final propagatedVariant = animate is String ? animate : ancestorScope?.variant;
    final effectiveTransition = widget.transition ?? NibMotionConfig.defaultTransitionOf(context);

    Widget result = _NibMotionBox(
      opacity: _opacity,
      translateX: _translateX,
      translateY: _translateY,
      scaleX: _scaleX,
      scaleY: _scaleY,
      rotate: _rotate,
      skewX: _skewX,
      skewY: _skewY,
      color: _color,
      borderRadius: _borderRadius,
      boxShadow: _boxShadow,
      child: VariantsScope(
        variant: propagatedVariant,
        delayChildren: effectiveTransition.delayChildren,
        staggerChildren: effectiveTransition.staggerChildren,
        indexCounter: _childIndexCounter,
        child: widget.child,
      ),
    );

    if (widget.whileFocus != null) {
      result = Focus(onFocusChange: _onFocusChange, child: result);
    }

    if (widget.whileHover != null) {
      result = MouseRegion(onEnter: _onHoverEnter, onExit: _onHoverExit, child: result);
    }

    if (widget.whileTap != null || widget.drag != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.whileTap != null ? _onTapDown : null,
        onTapUp: widget.whileTap != null ? (_) => _onTapEnd() : null,
        onTapCancel: widget.whileTap != null ? _onTapEnd : null,
        onPanStart: widget.drag != null ? _onPanStart : null,
        onPanUpdate: widget.drag != null ? _onPanUpdate : null,
        onPanEnd: widget.drag != null ? _onPanEnd : null,
        child: result,
      );
    }

    return result;
  }
}
