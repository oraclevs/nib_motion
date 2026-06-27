/// Shorthand for constructing [Duration]s, e.g. `200.ms` instead of
/// `Duration(milliseconds: 200)`.
extension NibDurationExtension on int {
  /// This number of milliseconds, as a [Duration].
  Duration get ms => Duration(milliseconds: this);

  /// This number of seconds, as a [Duration].
  Duration get seconds => Duration(seconds: this);
}
