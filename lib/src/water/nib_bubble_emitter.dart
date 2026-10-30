import 'dart:math' as math;
import 'dart:ui';
import 'nib_water_controller.dart';

/// Deterministic, bounded decorative air-bubble motion for one water controller.
///
/// Rise and lateral drift are artistic approximations, not fluid simulation.
/// The controller owns advancement. Do not share an emitter between controllers.
class NibBubbleEmitter {
  /// Creates at most ten bubbles; defaults match a quiet, slow rise.
  NibBubbleEmitter(
      {this.seed = 1,
      this.maxBubbles = 6,
      this.interval = .55,
      this.minRadius = 11,
      this.maxRadius = 24,
      this.minLifetime = 4.5,
      this.maxLifetime = 6.7,
      this.drift = 25})
      : _random = math.Random(seed) {
    if (maxBubbles < 1 || maxBubbles > 10) {
      throw ArgumentError.value(maxBubbles, 'maxBubbles');
    }
    for (final entry in <String, (double, double, double)>{
      'interval': (interval, .1, 60),
      'minRadius': (minRadius, 8, 128),
      'maxRadius': (maxRadius, minRadius, 128),
      'minLifetime': (minLifetime, 1, 120),
      'maxLifetime': (maxLifetime, minLifetime, 120),
      'drift': (drift, 0, 256),
    }.entries) {
      final (value, low, high) = entry.value;
      if (!value.isFinite || value < low || value > high) {
        throw ArgumentError.value(value, entry.key);
      }
    }
  }

  /// Seed reused by reset for replay.
  final int seed;

  /// Maximum live bodies, within the shader's ten-body capacity.
  final int maxBubbles;

  /// Seconds between emission attempts.
  final double interval;

  /// Minimum radius in logical pixels.
  final double minRadius;

  /// Maximum radius before the small exit expansion.
  final double maxRadius;

  /// Shortest rise lifetime in seconds.
  final double minLifetime;

  /// Longest rise lifetime in seconds.
  final double maxLifetime;

  /// Maximum lateral drift in logical pixels.
  final double drift;
  math.Random _random;
  final List<_Bubble> _bubbles = [];
  int _nextId = 0;
  double _untilSpawn = 0;
  bool _emitting = true;

  /// Whether new bubbles may be emitted.
  bool get emitting => _emitting;

  /// Whether emission or existing bodies still need a frame clock.
  bool get isActive => _emitting || _bubbles.isNotEmpty;

  /// Stops spawning while existing bubbles finish their rise.
  void stop() => _emitting = false;

  /// Allows spawning again. Notify the owning controller via setEmitting.
  void start() => _emitting = true;

  /// Clears bodies and resets the seeded sequence, preserving emission policy.
  void reset() {
    _bubbles.clear();
    _nextId = 0;
    _untilSpawn = 0;
    _random = math.Random(seed);
  }

  /// Advances bounded active time and returns one batched scene snapshot.
  /// The owning controller supplies at most 66 ms per frame.
  List<NibWaterDrop> advance(double seconds, Size bounds) {
    if (!seconds.isFinite ||
        seconds < 0 ||
        seconds > .066 ||
        !bounds.isFinite ||
        bounds.isEmpty ||
        bounds.longestSide > 100000) {
      throw ArgumentError('Invalid bubble time or bounds');
    }
    for (final bubble in _bubbles) {
      bubble.age += seconds;
    }
    _bubbles.removeWhere((bubble) => bubble.age >= bubble.lifetime);
    _untilSpawn -= seconds;
    if (_untilSpawn <= 0) {
      _untilSpawn = interval;
      if (_emitting && _bubbles.length < maxBubbles) {
        _bubbles.add(_Bubble(
            _nextId++,
            _random.nextDouble(),
            minRadius + _random.nextDouble() * (maxRadius - minRadius),
            minLifetime + _random.nextDouble() * (maxLifetime - minLifetime),
            _random.nextDouble() * math.pi * 2));
      }
    }
    return [
      for (final bubble in _bubbles)
        NibWaterDrop(
            id: bubble.id,
            center: Offset(
                bubble.x * bounds.width +
                    math.sin(bubble.age * 1.5 + bubble.phase) * drift,
                bounds.height +
                    bubble.radius -
                    bubble.age /
                        bubble.lifetime *
                        (bounds.height + bubble.radius * 3)),
            radius: bubble.radius *
                (1 + math.max(0, bubble.age / bubble.lifetime - .92) * 5))
    ];
  }
}

class _Bubble {
  _Bubble(this.id, this.x, this.radius, this.lifetime, this.phase);
  final int id;
  final double x, radius, lifetime, phase;
  double age = 0;
}
