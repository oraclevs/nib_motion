import 'dart:async';

/// Tracks the future of the animation a driver is currently running.
///
/// Every animation started on a driver gets a future. It completes when the
/// animation settles *or* is superseded/stopped — never errors and never
/// hangs, so callers awaiting an exit or a sequence step cannot deadlock on
/// an interruption.
class DriverCompleter {
  Completer<void>? _current;

  /// Resolves the previous animation's future (it was superseded) and returns
  /// the future for the new one.
  Future<void> begin() {
    resolve();
    final completer = Completer<void>();
    _current = completer;
    return completer.future;
  }

  /// Completes the current future, if any.
  void resolve() {
    final completer = _current;
    _current = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
