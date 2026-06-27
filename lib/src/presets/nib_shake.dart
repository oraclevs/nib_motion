import 'package:flutter/widgets.dart';

import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import 'nib_anim_presets.dart';

/// Plays a rapid left-right shake animation on [child], commonly used for
/// input validation feedback.
///
/// The shake does not play automatically — trigger it on demand by calling
/// [NibShakeController.shake] on a controller passed to [controller]:
///
/// ```dart
/// final shakeController = NibShakeController();
///
/// NibShake(
///   controller: shakeController,
///   child: const NibInput(...),
/// )
///
/// // Elsewhere, e.g. on validation failure:
/// shakeController.shake();
/// ```
///
/// If [controller] is omitted, `NibShake` creates and owns one internally —
/// in that case, trigger the shake by wrapping `NibShake` in a widget that
/// has access to it via a [GlobalKey], or simply provide your own
/// [NibShakeController] when you need to trigger playback from outside this
/// widget.
class NibShake extends StatefulWidget {
  /// Creates a `NibShake`.
  const NibShake({
    super.key,
    required this.child,
    this.controller,
    this.duration = const Duration(milliseconds: 600),
  });

  /// The widget to shake.
  final Widget child;

  /// Triggers the shake animation via [NibShakeController.shake]. If `null`,
  /// this widget creates and owns its own controller internally.
  final NibShakeController? controller;

  /// How long one shake animation takes to play out.
  final Duration duration;

  @override
  State<NibShake> createState() => _NibShakeState();
}

class _NibShakeState extends State<NibShake> {
  NibShakeController? _internalController;

  NibShakeController get _controller => widget.controller ?? (_internalController ??= NibShakeController());

  @override
  void didUpdateWidget(NibShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibMotion(
      controller: _controller._motionController,
      transition: NibTransition(duration: widget.duration),
      child: widget.child,
    );
  }
}

/// Imperative handle for triggering [NibShake]'s shake animation on demand.
///
/// Call [shake] to play the shake animation once. Must be disposed via
/// [dispose] when no longer needed (unless owned internally by a
/// [NibShake] that was constructed without an explicit `controller`, which
/// disposes it automatically).
class NibShakeController {
  final NibMotionController _motionController = NibMotionController();

  /// Plays the shake keyframe animation once on every attached `NibShake`.
  Future<void> shake() {
    return _motionController.start(keyframes: NibAnimPresets.shake);
  }

  /// Releases this controller's resources. Safe to call once.
  void dispose() {
    _motionController.dispose();
  }
}
