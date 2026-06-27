import 'dart:async';

import 'nib_timeline_entry.dart';

/// Plays a list of [NibTimelineEntry]s in time order, dispatching each
/// entry's `controller.start(target:, transition:)` at its [NibTimelineEntry.at]
/// offset from when [play] was called.
///
/// Use this to orchestrate multiple [NibMotionController]s (one per
/// animated element) against a single shared clock — think of it as a
/// playbook for a multi-element animation sequence.
///
/// ```dart
/// final timeline = NibTimeline([
///   NibTimelineEntry(controller: titleController, target: const NibAnim(opacity: 1), at: Duration.zero),
///   NibTimelineEntry(controller: subtitleController, target: const NibAnim(opacity: 1), at: const Duration(milliseconds: 150)),
/// ]);
/// await timeline.play();
/// ```
class NibTimeline {
  /// Creates a timeline that plays [entries] in order of their
  /// [NibTimelineEntry.at] offsets.
  ///
  /// [entries] is sorted by [NibTimelineEntry.at] (stable sort, so entries
  /// sharing the same offset keep their relative order).
  NibTimeline(List<NibTimelineEntry> entries)
      : entries = List.unmodifiable(_sorted(entries));

  static List<NibTimelineEntry> _sorted(List<NibTimelineEntry> entries) {
    final sorted = List<NibTimelineEntry>.of(entries);
    sorted.sort((a, b) => a.at.compareTo(b.at));
    return sorted;
  }

  /// The entries this timeline plays, sorted by [NibTimelineEntry.at].
  final List<NibTimelineEntry> entries;

  final List<Timer> _timers = <Timer>[];
  bool _disposed = false;

  /// Schedules every entry's `controller.start(target:, transition:)` at its
  /// [NibTimelineEntry.at] offset (via internal [Timer]s, so pending entries
  /// can be cancelled by [pause]/[stop]).
  ///
  /// Returns a [Future] that completes once the last entry has fired and its
  /// animation has finished. Calling [play] again while already playing
  /// cancels any still-pending entries from the previous run before
  /// rescheduling all entries from this run.
  Future<void> play() {
    _assertNotDisposed();
    _cancelTimers();

    final completer = Completer<void>();

    if (entries.isEmpty) {
      completer.complete();
      return completer.future;
    }

    var remaining = entries.length;

    for (final entry in entries) {
      final timer = Timer(entry.at, () {
        entry.controller
            .start(target: entry.target, transition: entry.transition)
            .then((_) {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete();
          }
        });
      });
      _timers.add(timer);
    }

    return completer.future;
  }

  /// Cancels every pending (not-yet-fired) entry, leaving already-started
  /// animations running. The [Future] returned by [play] will never
  /// complete after this is called, since the remaining entries won't fire.
  void pause() {
    _cancelTimers();
  }

  /// Cancels every pending (not-yet-fired) entry. Equivalent to [pause];
  /// provided as a separate, explicitly-named method to mirror
  /// [NibAnimationSequence.stop] and [NibMotionController.stop].
  void stop() {
    _cancelTimers();
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Cancels all pending entries and marks this timeline as no longer
  /// usable. Call this when the owner (e.g. a `State`) is disposed.
  void dispose() {
    _cancelTimers();
    _disposed = true;
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'NibTimeline.play() was called after dispose().');
  }
}
