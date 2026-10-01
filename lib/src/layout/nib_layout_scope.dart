import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Defines the coordinate space `NibMotion.layout` widgets are measured in,
/// and connects `layoutId`s across the subtree.
///
/// Wrap the container whose children animate (a `Wrap`, a `Stack`, a whole
/// screen). Movement of the scope itself — the container being resized,
/// re-positioned, or scrolled — is *not* a layout change for its descendants;
/// only movement relative to the scope is. Without a scope, widgets are
/// measured up to the nearest scrollable, so a moving container above them
/// animates its children too.
///
/// A scope is also required for `NibMotion.layoutId`: a widget that mounts with
/// an id another (just-unmounted) widget in the same scope was using animates
/// from that widget's last rectangle — a shared-element transition that works
/// across parents.
class NibLayoutScope extends StatefulWidget {
  /// Creates a layout scope around [child].
  const NibLayoutScope({super.key, required this.child});

  /// The subtree measured in this scope's coordinate space.
  final Widget child;

  /// The nearest scope's shared-id registry, or null.
  static NibLayoutScopeData? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_NibLayoutScopeInherited>()?.data;

  @override
  State<NibLayoutScope> createState() => _NibLayoutScopeState();
}

class _NibLayoutScopeState extends State<NibLayoutScope> {
  final NibLayoutScopeData _data = NibLayoutScopeData();

  @override
  Widget build(BuildContext context) {
    return _NibLayoutScopeInherited(
      data: _data,
      child: _NibLayoutScopeBox(child: widget.child),
    );
  }
}

class _NibLayoutScopeInherited extends InheritedWidget {
  const _NibLayoutScopeInherited({required this.data, required super.child});

  final NibLayoutScopeData data;

  @override
  bool updateShouldNotify(_NibLayoutScopeInherited oldWidget) =>
      data != oldWidget.data;
}

class _NibLayoutScopeBox extends SingleChildRenderObjectWidget {
  const _NibLayoutScopeBox({super.child});

  @override
  RenderNibLayoutScope createRenderObject(BuildContext context) =>
      RenderNibLayoutScope();
}

/// Marker render object that bounds layout measurement (see [NibLayoutScope]).
class RenderNibLayoutScope extends RenderProxyBox {
  /// Creates the scope's render object.
  RenderNibLayoutScope([super.child]);
}

class _Snapshot {
  _Snapshot(this.rect, this.owner, this.at);
  final Rect rect;
  final RenderObject owner;
  final Duration at;
}

/// The last-seen rectangle of every `layoutId` in a [NibLayoutScope].
class NibLayoutScopeData {
  final Map<Object, _Snapshot> _snapshots = <Object, _Snapshot>{};

  /// A snapshot older than this (measured in frame time) is not reused.
  static const Duration maxAge = Duration(milliseconds: 250);

  Duration _now() => SchedulerBinding.instance.currentSystemFrameTimeStamp;

  /// Records where [owner] laid out [id], in scope space.
  void record(Object id, Rect rect, RenderObject owner) {
    final now = _now();
    _snapshots[id] = _Snapshot(rect, owner, now);
    if (_snapshots.length > 32 && now - _lastPrune > maxAge) _prune(now);
  }

  // Entries of unmounted owners are only useful for `maxAge`; without pruning
  // every id ever seen would stay here, pinning its detached render object.
  Duration _lastPrune = Duration.zero;

  void _prune(Duration now) {
    _lastPrune = now;
    _snapshots.removeWhere((_, s) => !s.owner.attached && now - s.at > maxAge);
  }

  /// The rectangle a *previous, now-unmounted* owner of [id] last had, or
  /// null. A live owner is never taken over: two mounted widgets with the same
  /// id are not a shared transition.
  Rect? claim(Object id, RenderObject claimant) {
    final snapshot = _snapshots[id];
    if (snapshot == null || identical(snapshot.owner, claimant)) return null;
    if (snapshot.owner.attached) return null;
    if (_now() - snapshot.at > maxAge) return null;
    return snapshot.rect;
  }

  /// Number of remembered ids (for tests).
  int get length => _snapshots.length;
}
