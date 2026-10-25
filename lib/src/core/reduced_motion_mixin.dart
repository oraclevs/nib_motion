import 'package:flutter/widgets.dart';

import 'reduced_motion.dart';

/// Gives a [State] the central reduced-motion policy without each widget
/// re-implementing the lookup.
///
/// [reduceMotion] resolves through [NibMotionConfig.shouldReduceMotion] (safe
/// from `initState`). The mixin also subscribes to the preference, calling
/// [onReducedMotionChanged] when it flips after the first build.
mixin NibReducedMotionMixin<T extends StatefulWidget> on State<T> {
  bool? _lastReduced;

  /// Whether decorative motion should be skipped right now.
  bool get reduceMotion => NibMotionConfig.shouldReduceMotion(context);

  /// Called when the reduced-motion preference changes while mounted.
  void onReducedMotionChanged(bool reduced) {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = NibMotionConfig.watchReducedMotion(context);
    final last = _lastReduced;
    _lastReduced = reduced;
    if (last != null && last != reduced) onReducedMotionChanged(reduced);
  }
}
