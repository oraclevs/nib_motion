import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tracks a single child managed by `NibPresence`.
class NibPresenceEntry {
  /// Creates an entry for [key] currently rendering [child].
  NibPresenceEntry(
      {required this.key, required this.child, this.isExiting = false});

  /// The key shared with [child], used to diff `NibPresence.children` across
  /// rebuilds.
  final Key key;

  /// The latest widget supplied for [key].
  Widget child;

  /// Whether this entry has been removed from `NibPresence.children` and is
  /// playing its exit animation before being removed from the tree.
  bool isExiting;

  /// Resolves once the exit animation started for this entry has run to
  /// completion (or is superseded by re-entry).
  Completer<void>? exitCompleter;

  /// Identity of this entry's wrapper, so it can move between the layout flow
  /// and the exit overlay without remounting (and losing its animation).
  final GlobalKey wrapperKey = GlobalKey();

  /// Where the entry was, in `NibPresence` coordinates, when its exit began.
  /// Used by `NibExitLayout.pop` to overlay it while siblings reflow.
  Rect? exitRect;

  /// Pending staggered start of the exit animation.
  Timer? exitTimer;
}
