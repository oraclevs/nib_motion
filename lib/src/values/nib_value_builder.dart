import 'package:flutter/widgets.dart';

import '../core/nib_transition.dart';
import '../core/reduced_motion.dart';
import '../physics/multi_spring_solver.dart';
import '../physics/nib_spring.dart';
import '../physics/spring_description.dart';
import 'motion_converter.dart';
import 'motion_value.dart';

/// Springs a value of any [MotionConverter]-supported type toward [target] and
/// rebuilds [builder] as it moves.
///
/// Use it for things `NibMotion` does not animate because they change layout
/// (padding, size, alignment) or are arbitrary values (a `Rect`, a `Color`
/// fed to a painter). Changing [target] mid-flight retargets every axis from
/// its current position *and* velocity. Respects `NibMotionConfig` reduced
/// motion (the value jumps).
///
/// Unlike `NibMotion`, this rebuilds the builder subtree every frame; keep
/// the built subtree small, or prefer `NibMotion` for paint-only properties.
///
/// ```dart
/// NibValueBuilder<EdgeInsets>(
///   target: expanded ? const EdgeInsets.all(24) : EdgeInsets.zero,
///   builder: (context, padding) => Padding(padding: padding, child: card),
/// )
/// ```
class NibValueBuilder<T> extends StatefulWidget {
  /// Creates a value builder.
  ///
  /// [converter] may be omitted for `double`, `Offset`, `Size`, `Rect`,
  /// `Alignment`, `EdgeInsets` and `Color`; otherwise it is required.
  const NibValueBuilder({
    super.key,
    required this.target,
    required Widget Function(BuildContext context, T value) builder,
    this.converter,
    this.spring,
    this.transition,
    this.initial,
    this.onEnd,
  })  : _builder = builder,
        _childBuilder = null,
        child = null;

  /// Like the default constructor, but passes a prebuilt [child] through to
  /// [childBuilder] so the static part of the subtree is built once and never
  /// rebuilt while the value animates (the same idea as
  /// `ValueListenableBuilder.child`).
  ///
  /// ```dart
  /// NibValueBuilder<EdgeInsets>.withChild(
  ///   target: padding,
  ///   child: const ExpensiveCard(),
  ///   childBuilder: (context, p, child) => Padding(padding: p, child: child),
  /// )
  /// ```
  const NibValueBuilder.withChild({
    super.key,
    required this.target,
    required Widget this.child,
    required Widget Function(BuildContext context, T value, Widget child)
        childBuilder,
    this.converter,
    this.spring,
    this.transition,
    this.initial,
    this.onEnd,
  })  : _builder = null,
        _childBuilder = childBuilder;

  /// The value to animate toward.
  final T target;

  /// The value to start from on first build; defaults to [target] (no
  /// entrance animation).
  final T? initial;

  final Widget Function(BuildContext context, T value)? _builder;
  final Widget Function(BuildContext context, T value, Widget child)?
      _childBuilder;

  /// The prebuilt static subtree passed to the builder by
  /// [NibValueBuilder.withChild]; `null` for the default constructor.
  final Widget? child;

  /// Splits [T] into channels. Required for types without a built-in one.
  final MotionConverter<T>? converter;

  /// The spring, default [NibSpring.smooth]. Ignored when [transition] is a
  /// tween.
  final NibSpringDescription? spring;

  /// How to get to [target]: a spring transition (`NibTransition(spring:)`)
  /// or a curve-based tween (`NibTransition(duration:, curve:)`, linearly
  /// interpolating every channel). When null, [spring] (or
  /// [NibSpring.smooth]) is used.
  ///
  /// A tween cannot carry velocity, so a spring that follows one starts from
  /// rest.
  final NibTransition? transition;

  /// Called when the value settles on [target] (not when superseded).
  final VoidCallback? onEnd;

  @override
  State<NibValueBuilder<T>> createState() => _NibValueBuilderState<T>();
}

class _NibValueBuilderState<T> extends State<NibValueBuilder<T>>
    with TickerProviderStateMixin {
  late final MotionConverter<T> _converter;
  late final MotionValue<T> _value;
  late final MultiSpringSolver<T> _solver;
  AnimationController? _tween;

  @override
  void initState() {
    super.initState();
    _converter = widget.converter ??
        MotionConverter.maybeFor<T>() ??
        (throw ArgumentError(
            'NibValueBuilder<$T> needs a converter: no built-in one exists.'));
    _value = MotionValue<T>(widget.initial ?? widget.target);
    _solver = MultiSpringSolver<T>(
      vsync: this,
      value: _value,
      converter: _converter,
      spring: _spring,
      onComplete: () => widget.onEnd?.call(),
    );
    if (widget.initial != null && widget.initial != widget.target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retarget();
      });
    }
  }

  NibSpringDescription get _spring =>
      widget.transition?.spring ?? widget.spring ?? NibSpring.smooth;

  bool get _isTween =>
      widget.transition != null && widget.transition!.spring == null;

  void _retarget() {
    if (NibMotionConfig.shouldReduceMotion(context)) {
      _tween?.stop();
      _solver.animateTo(widget.target, immediate: true);
      return;
    }
    if (_isTween) {
      _solver.stop();
      _runTween(widget.transition!);
      return;
    }
    _tween?.stop();
    _solver.spring = _spring;
    _solver.animateTo(widget.target);
  }

  void _runTween(NibTransition transition) {
    final from = _converter.normalize(_value.value);
    final to = _converter.normalize(widget.target);
    final controller = _tween ??= AnimationController(vsync: this);
    controller
      ..stop()
      ..duration = transition.duration
      ..value = 0.0;
    void tick() {
      final t = transition.curve.transform(controller.value);
      _value.update(_converter.denormalize([
        for (var i = 0; i < from.length; i++) from[i] + (to[i] - from[i]) * t,
      ]));
    }

    controller.removeListener(_tweenListener ?? () {});
    _tweenListener = tick;
    controller.addListener(tick);
    controller.forward().then((_) {
      if (!mounted) return;
      _value.update(widget.target);
      widget.onEnd?.call();
    }, onError: (_) {});
  }

  VoidCallback? _tweenListener;

  @override
  void didUpdateWidget(NibValueBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != oldWidget.target) _retarget();
  }

  @override
  void dispose() {
    _solver.dispose();
    _tween?.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: _value,
      child: widget.child,
      builder: (context, value, child) {
        final withChild = widget._childBuilder;
        if (withChild != null) return withChild(context, value, child!);
        return widget._builder!(context, value);
      },
    );
  }
}
