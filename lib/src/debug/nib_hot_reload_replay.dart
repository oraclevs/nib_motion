import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/nib_motion_replay_scope.dart';

/// Replays every descendant `NibMotion` entrance animation when the app is
/// hot reloaded, so a tweak to `initial`/`animate`/`transition` is visible
/// immediately instead of only on the next navigation.
///
/// It listens to [State.reassemble] (called on hot reload and by
/// `WidgetsBinding.reassembleApplication`) and fires the ambient
/// `NibMotionReplaySignal`. In release/profile builds it does nothing and
/// adds only the replay scope.
///
/// ```dart
/// NibHotReloadReplay(child: MyScreen())
/// ```
class NibHotReloadReplay extends StatefulWidget {
  /// Creates a replay-on-reassemble wrapper around [child].
  const NibHotReloadReplay({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  /// The subtree whose entrance animations replay.
  final Widget child;

  /// Delay before the replay starts (forwarded to the replay signal).
  final Duration delay;

  /// Set to `false` to disable replay (it is always off outside debug mode).
  final bool enabled;

  @override
  State<NibHotReloadReplay> createState() => _NibHotReloadReplayState();
}

class _NibHotReloadReplayState extends State<NibHotReloadReplay> {
  final NibMotionReplaySignal _signal = NibMotionReplaySignal();

  @override
  void reassemble() {
    super.reassemble();
    if (kDebugMode && widget.enabled) _signal.replay(delay: widget.delay);
  }

  @override
  void dispose() {
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NibMotionReplayScope(signal: _signal, child: widget.child);
  }
}
