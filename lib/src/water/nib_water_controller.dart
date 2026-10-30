import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'nib_bubble_emitter.dart';

/// The current decorative body's coalescence or separation phase.
///
/// This is a two-dimensional visual model, not a fluid-volume simulation.
enum NibWaterPhase {
  /// Constituent droplets have independent body identities.
  separated,

  /// Connected droplets recover toward their area-weighted center.
  merging,

  /// At least two constituents retain a shared, settled body identity.
  merged,

  /// An explicit split is restoring separated constituent regions.
  splitting,
}

/// Bounded simulation and optical settings for a water surface.
///
/// All distances are receiver-local logical pixels and all times are seconds.
/// The const constructor permits inexpensive presets; [NibWaterController]
/// checks the ranges in release builds when accepting a configuration.
@immutable
class NibWaterConfig {
  /// Creates settings; see each property for its accepted range and units.
  const NibWaterConfig({
    this.waveSpeed = 180,
    this.damping = 2.4,
    this.impulseStrength = 5,
    this.wavelength = 46,
    this.recovery = 14,
    this.refraction = 16,
    this.highlight = .6,
  });

  /// Wave propagation speed, in logical pixels per second, from 0 to 1000.
  final double waveSpeed;

  /// Exponential wave amplitude decay rate, per second, from .25 to 12.
  final double damping;

  /// Default artistic wave height, in logical pixels, from 0 to 24.
  final double impulseStrength;

  /// Distance between successive wave crests, from 8 to 256 logical pixels.
  final double wavelength;

  /// Critical spring recovery rate, per second, from 1 to 30.
  ///
  /// This controls droplet recovery, independently of wave [damping].
  final double recovery;

  /// Artistic optical displacement strength, from 0 to 48.
  ///
  /// This is not a measured refractive index.
  final double refraction;

  /// Artistic surface-light strength, from 0 to 2.
  final double highlight;

  /// Copies settings while keeping unspecified properties unchanged.
  NibWaterConfig copyWith({
    double? waveSpeed,
    double? damping,
    double? impulseStrength,
    double? wavelength,
    double? recovery,
    double? refraction,
    double? highlight,
  }) =>
      NibWaterConfig(
        waveSpeed: waveSpeed ?? this.waveSpeed,
        damping: damping ?? this.damping,
        impulseStrength: impulseStrength ?? this.impulseStrength,
        wavelength: wavelength ?? this.wavelength,
        recovery: recovery ?? this.recovery,
        refraction: refraction ?? this.refraction,
        highlight: highlight ?? this.highlight,
      );

  void _validate() {
    _checkRange(waveSpeed, 'waveSpeed', 0, 1000);
    _checkRange(damping, 'damping', .25, 12);
    _checkRange(impulseStrength, 'impulseStrength', 0, 24);
    _checkRange(wavelength, 'wavelength', 8, 256);
    _checkRange(recovery, 'recovery', 1, 30);
    _checkRange(refraction, 'refraction', 0, 48);
    _checkRange(highlight, 'highlight', 0, 2);
  }
}

/// An immutable constituent of a decorative water body.
///
/// Radius remains unchanged during merge and split. The conserved quantity is
/// the sum of `pi * radius * radius`, not the union silhouette area or 3D volume.
@immutable
class NibWaterDrop {
  /// Creates a constituent in receiver-local logical pixels.
  ///
  /// IDs must be unique within a controller. Radius must be in 8..256 and each
  /// center coordinate in -1,000,000..1,000,000. Initial velocity is accepted
  /// up to 4000 logical pixels per second. Values are checked by the controller.
  /// Matching [bodyId] values declare an initially shared body; the controller
  /// canonicalizes each body's identity to its lowest constituent ID.
  const NibWaterDrop({
    required this.id,
    required this.center,
    this.radius = 64,
    int? bodyId,
    this.velocity = Offset.zero,
  }) : bodyId = bodyId ?? id;

  /// Stable constituent identity, retained across merge, split and reset.
  final int id;

  /// Current center, in receiver-local logical pixels.
  final Offset center;

  /// Unchanging Gaussian half-height radius, in logical pixels.
  final double radius;

  /// Shared body's identity, equal to its lowest constituent ID.
  final int bodyId;

  /// Current receiver-local velocity, in logical pixels per second.
  final Offset velocity;
}

/// An immutable analytical disturbance consumed by the surface renderer.
@immutable
class NibWaterImpulse {
  const NibWaterImpulse._(this.center, this.age, this.strength);

  /// Fixed origin, in receiver-local logical pixels.
  final Offset center;

  /// Linear simulation time elapsed since creation, in seconds.
  final double age;

  /// Original artistic wave-height amplitude, in logical pixels.
  ///
  /// The current amplitude is `strength * exp(-config.damping * age)`.
  final double strength;
}

/// Bounded water-body recovery and analytical wave state.
///
/// The owner must call [dispose]. The surface drives [advance]; do not attach
/// two independently ticking surfaces to one controller. No timer or ticker is
/// allocated here. Listeners receive one synchronous notification after a
/// completed mutation, and should invalidate painting rather than rebuild the
/// widget tree for each step.
///
/// Two connected Gaussian regions coalesce automatically while being moved.
/// The neck must exceed .52 (the visible contour is .5). Coalescence persists
/// after release; only [split] separates a body. An explicit split disables
/// automatic coalescence until another drag begins or [merge] is requested.
/// A body can belong to only one pointer at a time. Two separately owned bodies
/// do not coalesce until one pointer releases them.
///
/// This is a physically informed visual approximation. It does not implement
/// pressure, incompressibility, real surface tension, or 3D fluid volume.
class NibWaterController extends ChangeNotifier {
  /// Creates a controller with zero to ten decorative constituents.
  ///
  /// Empty [drops] are useful for a continuous water surface. Configuration,
  /// IDs, radii, positions and velocities are validated in release builds.
  NibWaterController({
    required List<NibWaterDrop> drops,
    this.emitter,
    NibWaterConfig config = const NibWaterConfig(),
  }) : _config = config {
    config._validate();
    if (drops.length > 10) {
      throw ArgumentError.value(drops.length, 'drops.length', 'Maximum is 10');
    }
    final ids = <int>{};
    for (final drop in drops) {
      if (!ids.add(drop.id)) {
        throw ArgumentError.value(drop.id, 'id', 'Must be unique');
      }
      _checkPoint(drop.center, 'center');
      _checkPoint(drop.velocity, 'velocity');
      _checkRange(drop.velocity.distance, 'velocity magnitude', 0, 4000);
      _checkRange(drop.radius, 'radius', 8, 256);
    }
    final canonical = <int, int>{};
    for (final drop in drops) {
      canonical.update(
        drop.bodyId,
        (id) => math.min(id, drop.id),
        ifAbsent: () => drop.id,
      );
    }
    _initial = List.unmodifiable(
      drops.map(
        (drop) => NibWaterDrop(
          id: drop.id,
          center: drop.center,
          radius: drop.radius,
          bodyId: canonical[drop.bodyId],
          velocity: drop.velocity,
        ),
      ),
    );
    _restore();
  }

  /// Optional decorative emitter, advanced by this controller's existing clock.
  /// Emitted bubbles stay independent; merge/split remains for manual droplets.
  final NibBubbleEmitter? emitter;

  static const double _ln2 = .6931471805599453;
  static const double _maxStep = .066;
  static const double _substep = 1 / 120;
  static const double _maxSpeed = 4000;
  late final List<NibWaterDrop> _initial;
  final List<_Drop> _drops = [];
  final List<NibWaterImpulse> _impulses = [];
  final Map<int, _Drag> _inputs = {};
  NibWaterConfig _config;
  NibWaterPhase _phase = NibWaterPhase.separated;
  bool _reducedMotion = false;
  bool _disposed = false;
  bool _autoMerge = true;
  double _simulationTime = 0;
  int _lastStepMicros = 0;

  /// Current immutable configuration.
  NibWaterConfig get config => _config;

  /// Immutable snapshots of current constituent position, identity and speed.
  List<NibWaterDrop> get drops => List.unmodifiable(
        _drops.map(
          (drop) => NibWaterDrop(
            id: drop.id,
            center: drop.center,
            radius: drop.radius,
            bodyId: drop.bodyId,
            velocity: drop.velocity,
          ),
        ),
      );

  /// Immutable snapshots of at most twelve live analytical wave impulses.
  List<NibWaterImpulse> get impulses => List.unmodifiable(_impulses);

  /// Current coalescence/separation phase, updated before notifying listeners.
  NibWaterPhase get phase => _phase;

  /// Whether an advance can change positions or waves.
  ///
  /// A motionless held pointer does not require continuous simulation work.
  bool get isActive =>
      !_disposed &&
      !_reducedMotion &&
      ((emitter?.isActive ?? false) ||
          _impulses.isNotEmpty ||
          _drops.any((drop) => !drop.settled));

  /// Number of pointers that currently own a decorative body.
  int get activeInputs => _inputs.length;

  /// Sum of constituent `pi * radius²`, in squared logical pixels.
  ///
  /// Conserved between explicit scene replacement or emission operations. This is not the visible union area or 3D volume.
  double get massProxy => _drops.fold(
        0,
        (total, drop) => total + math.pi * drop.radius * drop.radius,
      );

  /// Accepted active simulation seconds; paused or discarded time is excluded.
  double get simulationTime => _simulationTime;

  /// Wall-clock microseconds spent in the latest [advance], excluding listeners.
  ///
  /// A diagnostic CPU measurement, not a frame/raster/GPU timing guarantee.
  int get lastStepMicros => _lastStepMicros;

  /// Whether motion reduction currently resolves changes without animation.
  bool get isReducedMotion => _reducedMotion;

  /// Whether the owner has disposed this controller.
  bool get isDisposed => _disposed;

  /// Applies validated settings without resetting bodies, impulses or time.
  void configure(NibWaterConfig config) {
    _checkAlive();
    config._validate();
    _config = config;
    notifyListeners();
  }

  /// Advances linear simulation time by at most 66 milliseconds per call.
  ///
  /// Larger gaps are discarded, not accumulated for a catch-up burst. Each
  /// accepted interval is divided into steps no larger than 1/120 second.
  /// [seconds] must be finite and nonnegative. Zero or idle advances do nothing.
  /// Critical spring recovery preserves current velocity when retargeted and
  /// caps velocity/displacement at 4000 logical pixels per second.
  void advance(double seconds, {Size? bounds}) {
    _checkAlive();
    if (!seconds.isFinite || seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', 'Must be finite and >= 0');
    }
    if (seconds == 0 || !isActive) {
      _lastStepMicros = 0;
      return;
    }
    final watch = Stopwatch()..start();
    final elapsed = math.min(seconds, _maxStep);
    if (emitter != null && bounds != null && !bounds.isEmpty) {
      _replaceDrops(emitter!.advance(elapsed, bounds));
    }
    var remaining = elapsed;
    while (remaining > 1e-10) {
      final dt = math.min(_substep, remaining);
      for (final drop in _drops) {
        _stepDrop(drop, dt);
      }
      if (_autoMerge && _phase != NibWaterPhase.splitting) {
        _mergeConnected();
      }
      remaining -= dt;
    }
    _simulationTime += elapsed;
    for (var i = _impulses.length - 1; i >= 0; i--) {
      final old = _impulses[i];
      final age = old.age + elapsed;
      if (age >= 8 || old.strength * math.exp(-_config.damping * age) < .01) {
        _impulses.removeAt(i);
      } else {
        _impulses[i] = NibWaterImpulse._(old.center, age, old.strength);
      }
    }
    _finishPhase();
    watch.stop();
    _lastStepMicros = watch.elapsedMicroseconds;
    notifyListeners();
  }

  /// Replaces the decorative scene in one notification; IDs remain caller-owned.
  /// At most ten validated bodies. Existing pointer ownership is cancelled.
  /// Reset restores the constructor's original scene. Do not combine with an emitter.
  void setDrops(List<NibWaterDrop> drops) {
    _checkAlive();
    if (emitter != null) throw StateError('The emitter owns this scene');
    _replaceDrops(drops);
    notifyListeners();
  }

  /// Adds or moves one decorative body, preserving other body snapshots.
  void putDrop(NibWaterDrop drop) => setDrops([
        for (final old in drops)
          if (old.id != drop.id) old,
        drop
      ]);

  /// Removes a decorative body by stable ID; no change if it is absent.
  void removeDrop(int id) {
    _checkAlive();
    if (_drops.any((drop) => drop.id == id)) {
      setDrops(drops.where((drop) => drop.id != id).toList());
    }
  }

  /// Starts or stops emission without changing the simulation clock.
  void setEmitting(bool value) {
    _checkAlive();
    if (emitter == null) throw StateError('This controller has no emitter');
    if (value) {
      emitter!.start();
    } else {
      emitter!.stop();
    }
    notifyListeners();
  }

  void _replaceDrops(List<NibWaterDrop> drops) {
    if (drops.length > 10) {
      throw ArgumentError.value(drops.length, 'drops.length');
    }
    final ids = <int>{};
    for (final drop in drops) {
      if (!ids.add(drop.id)) throw ArgumentError.value(drop.id, 'id');
      _checkPoint(drop.center, 'center');
      _checkPoint(drop.velocity, 'velocity');
      _checkRange(drop.velocity.distance, 'velocity magnitude', 0, 4000);
      _checkRange(drop.radius, 'radius', 8, 256);
    }
    _inputs.clear();
    _drops
      ..clear()
      ..addAll(drops.map(_Drop.new));
    for (final group in _groups()) {
      final id = group.map((drop) => drop.id).reduce(math.min);
      for (final drop in group) {
        drop.bodyId = id;
      }
    }
    _phase = NibWaterPhase.separated;
  }

  /// Adds a bounded disturbance at [center] in receiver-local logical pixels.
  ///
  /// Strength is in 0..24; zero strength and reduced motion create no impulse.
  /// The thirteenth impulse replaces the oldest. Impulses expire at amplitude
  /// below .01 or after eight active simulation seconds, whichever is first.
  void disturb(Offset center, {double? strength}) {
    _checkAlive();
    _checkPoint(center, 'center');
    final amplitude = strength ?? _config.impulseStrength;
    _checkRange(amplitude, 'strength', 0, 24);
    if (_reducedMotion || amplitude == 0) return;
    if (_impulses.length == 12) _impulses.removeAt(0);
    _impulses.add(NibWaterImpulse._(center, 0, amplitude));
    notifyListeners();
  }

  /// Returns the visible Gaussian field value at a receiver-local point.
  ///
  /// Each constituent contributes `exp(-ln(2) * distance² / radius²)`.
  /// The renderer's contour threshold is .5. This value is not a fluid height.
  double fieldAt(Offset point) {
    _checkAlive();
    _checkPoint(point, 'point');
    return _drops.fold(0, (field, drop) => field + _field(drop, point));
  }

  /// Returns the nearest contributing constituent ID inside the .5 contour.
  ///
  /// Returns null outside the visible field. This is a decorative handle hit
  /// test; it must not be used to combine independently actionable UI controls.
  int? hitTest(Offset point) {
    if (fieldAt(point) < .5) return null;
    _Drop? closest;
    var contribution = -1.0;
    for (final drop in _drops) {
      final value = _field(drop, point);
      if (value > contribution) {
        contribution = value;
        closest = drop;
      }
    }
    return closest?.id;
  }

  /// Claims the body hit at [point] for [pointer], without moving it.
  ///
  /// Returns false for a missed hit, a reused pointer, or an already owned body.
  /// The grab offset is retained: subsequent [dragTo] calls move the existing
  /// target by the pointer delta rather than jumping its center to the pointer.
  bool beginDrag(int pointer, Offset point) {
    _checkAlive();
    _checkPoint(point, 'point');
    if (_inputs.containsKey(pointer)) return false;
    final id = hitTest(point);
    if (id == null) return false;
    final drop = _drops.firstWhere((drop) => drop.id == id);
    if (_inputs.values.any((input) => input.bodyId == drop.bodyId)) {
      return false;
    }
    _inputs[pointer] = _Drag(drop.bodyId, point);
    _autoMerge = true;
    notifyListeners();
    return true;
  }

  /// Retargets the owned body by a receiver-local pointer delta.
  ///
  /// An unknown pointer is ignored. Position and velocity stay continuous until
  /// [advance], except under reduced motion, which resolves the target at once.
  void dragTo(int pointer, Offset point) {
    _checkAlive();
    _checkPoint(point, 'point');
    final input = _inputs[pointer];
    if (input == null) return;
    final delta = point - input.point;
    input.point = point;
    for (final drop in _drops.where((drop) => drop.bodyId == input.bodyId)) {
      drop.target = _boundedPoint(drop.target + delta);
    }
    if (_reducedMotion) {
      _resolveTargets();
      if (_phase != NibWaterPhase.splitting) _mergeConnected();
      _resolveTargets();
    }
    notifyListeners();
  }

  /// Releases ownership, allowing recovery to the last pointer target.
  ///
  /// Cancellation removes pointer translation and clears velocities. A singleton
  /// freezes in place; a merging body continues recovery toward its current
  /// centroid, and a splitting body retains its separation targets. A normal
  /// release preserves velocity and the target. Neither path implicitly splits.
  void endDrag(int pointer, {bool cancelled = false}) {
    _checkAlive();
    final input = _inputs.remove(pointer);
    if (input == null) return;
    if (cancelled) {
      _cancelBody(input.bodyId);
      _finishPhase();
    } else if (_autoMerge && _phase != NibWaterPhase.splitting) {
      _mergeConnected();
      if (_reducedMotion) _resolveTargets();
    }
    notifyListeners();
  }

  /// Cancels all active owners without leaving latent pointer targets.
  ///
  /// Impulses and bodies that have no owner continue their current recovery.
  void cancelInputs() {
    _checkAlive();
    if (_inputs.isEmpty) return;
    final bodies = _inputs.values.map((input) => input.bodyId).toSet();
    for (final body in bodies) {
      _cancelBody(body);
    }
    _inputs.clear();
    _finishPhase();
    notifyListeners();
  }

  /// Coalesces all constituents toward their area-weighted centroid.
  ///
  /// This explicit command releases pointer ownership. Centers and velocities
  /// remain continuous while body identity changes before notification.
  void merge() {
    _checkAlive();
    if (_drops.length < 2) return;
    _inputs.clear();
    _autoMerge = true;
    _combine(_drops);
    if (_reducedMotion) _resolveTargets();
    notifyListeners();
  }

  /// Continuously separates each body's constituent regions.
  ///
  /// Initial relative positions are centered on the body's current centroid
  /// and expanded until pairwise separation is at least 1.7 times the sum of
  /// radii. Coincident or unrepresentable initial layouts use deterministic
  /// horizontal ordering. A common translation keeps all targets inside the
  /// coordinate bounds without collapsing their separation.
  /// The small extra gap provides hysteresis beyond the visible merge neck.
  /// Identities separate on settlement, and automatic merging stays disabled
  /// until the next drag or explicit merge. This command cancels ownership,
  /// but preserves instantaneous position and velocity unless motion is reduced.
  void split() {
    _checkAlive();
    final groups = _groups().where((group) => group.length > 1).toList();
    if (groups.isEmpty) return;
    _inputs.clear();
    _autoMerge = false;
    for (final group in groups) {
      final center = _centroid(group);
      final initial = group
          .map((drop) => _initial.firstWhere((item) => item.id == drop.id))
          .toList();
      final total =
          initial.fold(0.0, (sum, drop) => sum + _weight(drop.radius));
      final origin = initial.fold(
            Offset.zero,
            (sum, drop) => sum + drop.center * _weight(drop.radius),
          ) /
          total;
      var offsets = initial.map((drop) => drop.center - origin).toList();
      var coincident = false;
      var expansion = 1.0;
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final distance = (offsets[i] - offsets[j]).distance;
          if (distance < .01) {
            coincident = true;
          } else {
            expansion = math.max(
              expansion,
              1.7 * (group[i].radius + group[j].radius) / distance,
            );
          }
        }
      }
      final expanded = offsets.map((offset) => offset * expansion).toList();
      final extentX = expanded.map((offset) => offset.dx).reduce(math.max) -
          expanded.map((offset) => offset.dx).reduce(math.min);
      final extentY = expanded.map((offset) => offset.dy).reduce(math.max) -
          expanded.map((offset) => offset.dy).reduce(math.min);
      if (coincident || extentX > 2000000 || extentY > 2000000) {
        var x = 0.0;
        offsets = [];
        for (var i = 0; i < group.length; i++) {
          if (i > 0) x += 1.7 * (group[i - 1].radius + group[i].radius);
          offsets.add(Offset(x, 0));
        }
        var weighted = Offset.zero;
        for (var i = 0; i < group.length; i++) {
          weighted += offsets[i] * _weight(group[i].radius);
        }
        offsets = offsets.map((offset) => offset - weighted / total).toList();
        expansion = 1;
      }
      final targets =
          offsets.map((offset) => center + offset * expansion).toList();
      final minimumX = targets.map((target) => target.dx).reduce(math.min);
      final maximumX = targets.map((target) => target.dx).reduce(math.max);
      final minimumY = targets.map((target) => target.dy).reduce(math.min);
      final maximumY = targets.map((target) => target.dy).reduce(math.max);
      final translation = Offset(
        minimumX < -1000000
            ? -1000000 - minimumX
            : maximumX > 1000000
                ? 1000000 - maximumX
                : 0,
        minimumY < -1000000
            ? -1000000 - minimumY
            : maximumY > 1000000
                ? 1000000 - maximumY
                : 0,
      );
      for (var i = 0; i < group.length; i++) {
        group[i].target = _boundedPoint(targets[i] + translation);
      }
    }
    _phase = NibWaterPhase.splitting;
    if (_reducedMotion) _resolveTargets();
    notifyListeners();
  }

  /// Restores original drops/velocities and clears inputs, waves and time.
  ///
  /// Current settings and reduced-motion preference are retained. Reduced
  /// motion also resolves any initially shared body to its final center.
  void reset() {
    _checkAlive();
    _restore();
    if (_reducedMotion) _resolveTargets();
    notifyListeners();
  }

  /// Applies motion reduction, which takes precedence over active motion.
  ///
  /// Enabling it clears waves, resolves current targets, zeros velocities and
  /// finishes merge/split synchronously. Disabling it does not replay old work.
  void setReducedMotion(bool value) {
    _checkAlive();
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    if (value) {
      _impulses.clear();
      _resolveTargets();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _drops.clear();
    _inputs.clear();
    _impulses.clear();
    emitter?.reset();
    super.dispose();
  }

  void _cancelBody(int bodyId) {
    final group = _drops.where((drop) => drop.bodyId == bodyId).toList();
    if (group.isEmpty) return;
    final center = _centroid(group);
    for (final drop in group) {
      if (_phase != NibWaterPhase.splitting) {
        drop.target = group.length == 1 ? drop.center : center;
      }
      drop.velocity = Offset.zero;
    }
    if (_reducedMotion) _resolveTargets();
  }

  void _restore() {
    _drops
      ..clear()
      ..addAll(_initial.map(_Drop.new));
    _inputs.clear();
    _impulses.clear();
    _simulationTime = 0;
    _lastStepMicros = 0;
    _autoMerge = emitter == null;
    emitter?.reset();
    _phase = NibWaterPhase.separated;
    for (final group in _groups()) {
      if (group.length > 1) _combine(group);
    }
    _mergeConnected();
    _finishPhase();
  }

  void _stepDrop(_Drop drop, double dt) {
    if (drop.settled) {
      drop.center = drop.target;
      drop.velocity = Offset.zero;
      return;
    }
    final rate = _config.recovery;
    final error = drop.center - drop.target;
    final combined = drop.velocity + error * rate;
    final decay = math.exp(-rate * dt);
    final desired = drop.target + (error + combined * dt) * decay;
    final movement = _limit(desired - drop.center, _maxSpeed * dt);
    drop.center = _boundedPoint(drop.center + movement);
    drop.velocity =
        _limit((drop.velocity - combined * (rate * dt)) * decay, _maxSpeed);
  }

  void _mergeConnected() {
    var changed = true;
    while (changed) {
      changed = false;
      final groups = _groups();
      for (var i = 0; i < groups.length && !changed; i++) {
        for (var j = i + 1; j < groups.length && !changed; j++) {
          final ids = {groups[i].first.bodyId, groups[j].first.bodyId};
          if (_inputs.values
                  .where((input) => ids.contains(input.bodyId))
                  .length >
              1) {
            continue;
          }
          if (groups[i].any((a) => groups[j].any((b) => _connected(a, b)))) {
            _combine([...groups[i], ...groups[j]]);
            changed = true;
          }
        }
      }
    }
  }

  bool _connected(_Drop a, _Drop b) {
    final distance = (a.center - b.center).distance;
    if (distance > math.sqrt2 * (a.radius + b.radius)) return false;
    // A conservative interval bound, not isolated point samples: over each
    // interval each Gaussian is at least its value at its farther endpoint.
    // This ensures the complete segment stays inside the .52 neck threshold.
    for (var i = 0; i < 32; i++) {
      final farA = distance * (i + 1) / 32;
      final farB = distance * (1 - i / 32);
      final lower = math.exp(-_ln2 * farA * farA / _weight(a.radius)) +
          math.exp(-_ln2 * farB * farB / _weight(b.radius));
      if (lower < .52) return false;
    }
    return true;
  }

  void _combine(List<_Drop> group) {
    final previousIds = group.map((drop) => drop.bodyId).toSet();
    final bodyId = group.map((drop) => drop.id).reduce(math.min);
    final center = _centroid(group);
    for (final drop in group) {
      drop.bodyId = bodyId;
      drop.target = center;
    }
    for (final input in _inputs.values) {
      if (previousIds.contains(input.bodyId)) input.bodyId = bodyId;
    }
    _phase = NibWaterPhase.merging;
  }

  List<List<_Drop>> _groups() {
    final groups = <int, List<_Drop>>{};
    for (final drop in _drops) {
      (groups[drop.bodyId] ??= []).add(drop);
    }
    return groups.values.toList();
  }

  void _resolveTargets() {
    for (final drop in _drops) {
      drop.center = drop.target;
      drop.velocity = Offset.zero;
    }
    _finishPhase();
  }

  void _finishPhase() {
    if (_drops.any((drop) => !drop.settled)) return;
    // Snap only below .01 px / .02 px/s, never a visible separation reset.
    for (final drop in _drops) {
      drop.center = drop.target;
      drop.velocity = Offset.zero;
    }
    if (_phase == NibWaterPhase.splitting) {
      for (final drop in _drops) {
        drop.bodyId = drop.id;
      }
    }
    _phase = _groups().any((group) => group.length > 1)
        ? NibWaterPhase.merged
        : NibWaterPhase.separated;
  }

  void _checkAlive() {
    if (_disposed) throw StateError('NibWaterController has been disposed');
  }

  static double _field(_Drop drop, Offset point) => math.exp(
        -_ln2 * (point - drop.center).distanceSquared / _weight(drop.radius),
      );

  static Offset _centroid(List<_Drop> group) {
    var sum = Offset.zero;
    var weight = 0.0;
    for (final drop in group) {
      final mass = _weight(drop.radius);
      sum += drop.center * mass;
      weight += mass;
    }
    return sum / weight;
  }

  static double _weight(double radius) => radius * radius;

  static Offset _limit(Offset value, double maximum) =>
      value.distance > maximum ? value / value.distance * maximum : value;

  static Offset _boundedPoint(Offset point) => Offset(
        point.dx.clamp(-1000000, 1000000).toDouble(),
        point.dy.clamp(-1000000, 1000000).toDouble(),
      );
}

class _Drop {
  _Drop(NibWaterDrop drop)
      : id = drop.id,
        radius = drop.radius,
        bodyId = drop.bodyId,
        center = drop.center,
        target = drop.center,
        velocity = drop.velocity;

  final int id;
  final double radius;
  int bodyId;
  Offset center;
  Offset target;
  Offset velocity;

  bool get settled =>
      (center - target).distanceSquared < .0001 &&
      velocity.distanceSquared < .0004;
}

class _Drag {
  _Drag(this.bodyId, this.point);
  int bodyId;
  Offset point;
}

void _checkRange(double value, String name, double minimum, double maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
        value, name, 'Must be finite and in $minimum..$maximum');
  }
}

void _checkPoint(Offset point, String name) {
  _checkRange(point.dx, '$name.dx', -1000000, 1000000);
  _checkRange(point.dy, '$name.dy', -1000000, 1000000);
}
