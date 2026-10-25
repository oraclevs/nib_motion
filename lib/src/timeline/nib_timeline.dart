import 'dart:async';

import 'package:flutter/physics.dart' as flutter_physics;

import '../core/nib_anim.dart';
import '../core/nib_transition.dart';
import '../values/motion_value.dart';
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
  /// Creates a timeline. Relative entries ([NibTimelineEntry.after],
  /// [NibTimelineEntry.withStart]) are resolved to absolute times here, in
  /// list order; an entry may only refer to a label defined *earlier* in
  /// [entries].
  NibTimeline(List<NibTimelineEntry> entries)
      : entries = List.unmodifiable(_sorted(_resolve(entries)));

  static List<NibTimelineEntry> _resolve(List<NibTimelineEntry> entries) {
    final resolved = <NibTimelineEntry>[];
    final byLabel = <String, NibTimelineEntry>{};
    for (final entry in entries) {
      NibTimelineEntry out = entry;
      if (entry.anchor != NibTimelineAnchor.absolute) {
        final reference = entry.reference;
        final NibTimelineEntry anchor;
        if (reference == null) {
          if (resolved.isEmpty) {
            throw ArgumentError(
                'NibTimelineEntry.after with no reference needs a previous '
                'entry.');
          }
          anchor = resolved.last;
        } else {
          final found = byLabel[reference];
          if (found == null) {
            throw ArgumentError(
                'NibTimelineEntry refers to unknown or later label '
                '"$reference".');
          }
          anchor = found;
        }
        final base = entry.anchor == NibTimelineAnchor.afterEnd
            ? anchor.at + entryDuration(anchor)
            : anchor.at;
        var at = base + entry.offset;
        if (at < Duration.zero) at = Duration.zero;
        out = entry.resolvedAt(at);
      }
      final label = out.label;
      if (label != null) {
        if (byLabel.containsKey(label)) {
          throw ArgumentError('Duplicate NibTimelineEntry label "$label".');
        }
        byLabel[label] = out;
      }
      resolved.add(out);
    }
    return resolved;
  }

  /// How long [entry] runs once started: its transition's delay plus its
  /// duration (for springs, the time the spring takes to settle).
  static Duration entryDuration(NibTimelineEntry entry) {
    final t = entry.transition ?? const NibTransition();
    final spring = t.spring;
    if (spring == null) return t.delay + t.duration;
    final sim = flutter_physics.SpringSimulation(spring.toFlutter(), 0, 1, 0);
    var seconds = 0.0;
    while (seconds < 10 && !sim.isDone(seconds)) {
      seconds += 0.001;
    }
    return t.delay + Duration(microseconds: (seconds * 1e6).round());
  }

  static List<NibTimelineEntry> _sorted(List<NibTimelineEntry> entries) {
    final sorted = List<NibTimelineEntry>.of(entries);
    sorted.sort((a, b) => a.at.compareTo(b.at));
    return sorted;
  }

  /// The entries with all times resolved to absolute offsets, sorted by start.
  final List<NibTimelineEntry> entries;

  /// Total length: the latest entry end.
  Duration get duration {
    var end = Duration.zero;
    for (final entry in entries) {
      final e = entry.at + entryDuration(entry);
      if (e > end) end = e;
    }
    return end;
  }

  /// Scrub position `0..1` last set by [seek]. [play] does not drive it.
  final MotionValue<double> progress = MotionValue<double>(0.0);

  /// Jumps every entry to the state it would have at [fraction] (`0..1`) of
  /// [duration], without animating, and updates [progress].
  ///
  /// Entries with a [NibTimelineEntry.from] are interpolated `from → target`
  /// (using their curve, or the spring's settle curve). Entries without
  /// `from` cannot be interpolated because their start state is unknown; they
  /// step to their target once their end is reached. Entries that have not
  /// started yet are set to `from` when they have one, otherwise left alone.
  ///
  /// Scrubbing cancels any pending [play] timers.
  void seek(double fraction) {
    _assertNotDisposed();
    _cancelTimers();
    final f = fraction.clamp(0.0, 1.0);
    progress.value = f;
    final now = Duration(microseconds: (duration.inMicroseconds * f).round());
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final length =
          entryDuration(entry) - (entry.transition?.delay ?? Duration.zero);
      final start = entry.at + (entry.transition?.delay ?? Duration.zero);
      final from = _effectiveFrom(i);
      if (now < start) {
        // Not started: hold its start state, but never fight an earlier entry
        // that is still driving (or has finished driving) the same property.
        final held = from == null ? null : _withoutClaimed(i, from);
        if (held != null) entry.controller.set(held);
        continue;
      }
      final local = length.inMicroseconds == 0
          ? 1.0
          : ((now - start).inMicroseconds / length.inMicroseconds);
      if (local >= 1.0) {
        entry.controller.set(entry.target);
      } else if (from != null) {
        entry.controller.set(from.lerp(entry.target, _shape(entry, local)));
      }
    }
  }

  /// Targets of earlier entries on the same controller as entry [index],
  /// merged so the nearest earlier entry wins per property.
  NibAnim? _earlierTargets(int index) {
    final controller = entries[index].controller;
    NibAnim? merged;
    for (var j = index - 1; j >= 0; j--) {
      final earlier = entries[j];
      if (earlier.controller != controller) continue;
      merged = merged == null ? earlier.target : earlier.target.merge(merged);
    }
    return merged;
  }

  /// [from] minus every property an earlier entry on the same controller
  /// animates (those are owned by that entry until this one starts).
  NibAnim? _withoutClaimed(int index, NibAnim from) {
    final claimed = _earlierTargets(index);
    if (claimed == null) return from;
    T? keep<T>(T? value, T? claim) => claim == null ? value : null;
    return NibAnim(
      x: keep(from.x, claimed.x),
      y: keep(from.y, claimed.y),
      scale: keep(from.scale, claimed.scale),
      scaleX: keep(from.scaleX, claimed.scaleX),
      scaleY: keep(from.scaleY, claimed.scaleY),
      rotate: keep(from.rotate, claimed.rotate),
      skewX: keep(from.skewX, claimed.skewX),
      skewY: keep(from.skewY, claimed.skewY),
      rotateX: keep(from.rotateX, claimed.rotateX),
      rotateY: keep(from.rotateY, claimed.rotateY),
      blur: keep(from.blur, claimed.blur),
      tint: keep(from.tint, claimed.tint),
      opacity: keep(from.opacity, claimed.opacity),
      color: keep(from.color, claimed.color),
      borderRadius: keep(from.borderRadius, claimed.borderRadius),
      boxShadow: keep(from.boxShadow, claimed.boxShadow),
    );
  }

  /// The start state of entry [index]: its explicit `from`, otherwise derived
  /// per property — the target of the latest earlier entry on the same
  /// controller that animates that property, else the widget's own initial
  /// state (see `NibMotionController.initialAnim`). `null` if the entry
  /// animates nothing derivable.
  NibAnim? _effectiveFrom(int index) {
    final entry = entries[index];
    final explicit = entry.from;
    if (explicit != null) return explicit;

    final target = entry.target;
    final base = entry.controller.initialAnim;
    final previous = _earlierTargets(index);

    T? pick<T>(T? targetValue, T? before, T? initial) =>
        targetValue == null ? null : (before ?? initial);

    return NibAnim(
      x: pick(target.x, previous?.x, base.x),
      y: pick(target.y, previous?.y, base.y),
      scale: pick(target.scale, previous?.scale, base.scale),
      scaleX: pick(target.scaleX, previous?.scaleX, base.scaleX),
      scaleY: pick(target.scaleY, previous?.scaleY, base.scaleY),
      rotate: pick(target.rotate, previous?.rotate, base.rotate),
      skewX: pick(target.skewX, previous?.skewX, base.skewX),
      skewY: pick(target.skewY, previous?.skewY, base.skewY),
      rotateX: pick(target.rotateX, previous?.rotateX, base.rotateX),
      rotateY: pick(target.rotateY, previous?.rotateY, base.rotateY),
      blur: pick(target.blur, previous?.blur, base.blur),
      tint: pick(target.tint, previous?.tint, base.tint),
      opacity: pick(target.opacity, previous?.opacity, base.opacity),
      color: pick(target.color, previous?.color, base.color),
      borderRadius:
          pick(target.borderRadius, previous?.borderRadius, base.borderRadius),
      boxShadow: pick(target.boxShadow, previous?.boxShadow, base.boxShadow),
    );
  }

  static double _shape(NibTimelineEntry entry, double t) {
    final transition = entry.transition ?? const NibTransition();
    final spring = transition.spring;
    if (spring == null) return transition.curve.transform(t);
    final sim = flutter_physics.SpringSimulation(spring.toFlutter(), 0, 1, 0);
    final settle = entryDuration(entry) - transition.delay;
    return sim.x(t * settle.inMicroseconds / 1e6);
  }

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
    progress.dispose();
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'NibTimeline.play() was called after dispose().');
  }
}
