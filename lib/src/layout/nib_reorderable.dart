import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/nib_anim.dart';
import '../core/nib_motion_controller.dart';
import '../core/nib_motion_widget.dart';
import '../core/nib_transition.dart';
import '../core/render_nib_motion.dart';
import 'nib_layout.dart';
import 'nib_layout_scope.dart';

/// Builds the visual of an item while it is (or is not) being dragged.
typedef NibReorderDecorator = Widget Function(
    BuildContext context, Widget child, bool dragging);

/// A list whose items are reordered by long-press and drag, with the other
/// items gliding out of the way.
///
/// Built from the same runtime as everything else: every item is a
/// `NibMotion(layout: NibLayout.position)`, so when the dragged item crosses a
/// sibling the sibling FLIPs into its new slot (interruptible, velocity
/// preserving, reduced-motion aware). The dragged item follows the pointer with
/// a paint-time translation and springs into its slot on release.
///
/// Each of [children] needs a unique, non-null [Key]. [onReorder] is called once
/// on release with the item's original index and its final index (the index in
/// the resulting list, as after `ReorderableListView` adjusts it); update your
/// list there. If you do not, the items animate back.
///
/// Not scrollable itself: put it inside a scroll view on the same axis. While
/// an item is dragged near the leading or trailing edge of that scroll view it
/// scrolls automatically (faster the closer the pointer is to the edge).
/// Items are separated by [spacing]; the list runs along a single [axis].
class NibReorderable extends StatefulWidget {
  /// Creates a reorderable list.
  const NibReorderable({
    super.key,
    required this.children,
    required this.onReorder,
    this.axis = Axis.vertical,
    this.dragDecorator,
    this.layoutTransition,
    this.dragScale = 1.03,
    this.spacing = 0,
  });

  /// The items, in display order. Each must have a unique, non-null [Key].
  final List<Widget> children;

  /// Called on release when an item ended up at a different index.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// The direction items are laid out and dragged along.
  final Axis axis;

  /// Customises how the dragged item looks (shadow, colour, …). The item is
  /// also lifted by [dragScale].
  final NibReorderDecorator? dragDecorator;

  /// How siblings move into their new slots. Defaults to a snappy spring.
  final NibTransition? layoutTransition;

  /// Scale applied to the dragged item; `1` disables the lift.
  final double dragScale;

  /// Gap between consecutive items along [axis], in logical pixels.
  final double spacing;

  @override
  State<NibReorderable> createState() => _NibReorderableState();
}

class _NibReorderableState extends State<NibReorderable>
    with SingleTickerProviderStateMixin {
  final Map<Key, GlobalKey> _globalKeys = <Key, GlobalKey>{};
  final Map<Key, NibMotionController> _controllers =
      <Key, NibMotionController>{};

  /// Temporary display order while dragging; null means "as given".
  List<Key>? _order;
  Key? _dragged;
  int _originalIndex = 0;
  double _grabOffset = 0; // pointer - painted origin, along the main axis
  Offset _lastPointer = Offset.zero;
  Ticker? _scrollTicker;
  Duration _lastTick = Duration.zero;

  /// Distance from a scroll view's edge within which dragging auto-scrolls.
  static const double _edgeZone = 56;

  /// Auto-scroll speed at the very edge, in logical pixels per second.
  static const double _maxScrollSpeed = 900;

  bool get _horizontal => widget.axis == Axis.horizontal;

  GlobalKey _gk(Key key) => _globalKeys.putIfAbsent(key, GlobalKey.new);
  NibMotionController _ctl(Key key) =>
      _controllers.putIfAbsent(key, NibMotionController.new);

  List<Key> get _givenKeys => [for (final c in widget.children) c.key!];

  @override
  void didUpdateWidget(NibReorderable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = _givenKeys.toSet();
    _globalKeys.removeWhere((key, _) => !keys.contains(key));
    _controllers.removeWhere((key, controller) {
      if (keys.contains(key)) return false;
      controller.dispose();
      return true;
    });
  }

  @override
  void dispose() {
    _scrollTicker?.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  RenderBox? _box(Key key) {
    final object = _gk(key).currentContext?.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  double _main(Offset offset) => _horizontal ? offset.dx : offset.dy;
  double _mainSize(RenderBox box) =>
      _horizontal ? box.size.width : box.size.height;

  RenderBox? _space() {
    final object = context.findRenderObject();
    return object is RenderBox && object.attached && object.hasSize
        ? object
        : null;
  }

  /// Layout position (excluding the item's own transform) in list space.
  double _layoutOrigin(Key key, RenderBox space) =>
      _main(_box(key)!.localToGlobal(Offset.zero, ancestor: space));

  void _start(Key key, Offset pointer) {
    final box = _box(key);
    final space = _space();
    if (box == null || space == null) return;
    final order = _givenKeys;
    setState(() {
      _dragged = key;
      _order = order;
      _originalIndex = order.indexOf(key);
    });
    // Keep pointer, layout slots, and paint translation in the same space.
    final paintedBox = box is RenderNibMotion ? box.child ?? box : box;
    final paintedOrigin =
        _main(paintedBox.localToGlobal(Offset.zero, ancestor: space));
    _grabOffset = _main(space.globalToLocal(pointer)) - paintedOrigin;
    _lastPointer = pointer;
    _updateAutoScroll();
  }

  /// The nearest scroll view running along this list's axis, if any.
  ScrollableState? _scrollable() {
    final state = Scrollable.maybeOf(context);
    if (state == null) return null;
    return axisDirectionToAxis(state.axisDirection) == widget.axis
        ? state
        : null;
  }

  /// Auto-scroll velocity (px/s, signed along the axis) for the pointer's
  /// distance to the scroll view's edges; `0` in the middle.
  double _scrollVelocity(ScrollableState state) {
    final box = state.context.findRenderObject();
    if (box is! RenderBox || !box.attached) return 0;
    final p = _main(box.globalToLocal(_lastPointer));
    final toStart = p;
    final toEnd = _mainSize(box) - p;
    if (toStart < _edgeZone) {
      return -_maxScrollSpeed * ((_edgeZone - toStart) / _edgeZone).clamp(0, 1);
    }
    if (toEnd < _edgeZone) {
      return _maxScrollSpeed * ((_edgeZone - toEnd) / _edgeZone).clamp(0, 1);
    }
    return 0;
  }

  void _updateAutoScroll() {
    final state = _dragged == null ? null : _scrollable();
    if (state == null || _scrollVelocity(state) == 0) {
      _scrollTicker?.stop();
      return;
    }
    final ticker = _scrollTicker ??= createTicker(_onScrollTick);
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    }
  }

  void _onScrollTick(Duration elapsed) {
    final state = _scrollable();
    if (_dragged == null || state == null) {
      _scrollTicker?.stop();
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final velocity = _scrollVelocity(state);
    if (velocity == 0) {
      _scrollTicker?.stop();
      return;
    }
    final position = state.position;
    final target = (position.pixels + velocity * dt)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    position.jumpTo(target);
    // Items moved under the pointer: re-place the dragged item.
    _move(_lastPointer);
  }

  double get _gap => widget.spacing;

  void _move(Offset pointer) {
    _lastPointer = pointer;
    final dragged = _dragged;
    final order = _order;
    if (dragged == null || order == null) return;
    final draggedBox = _box(dragged);
    final space = _space();
    if (draggedBox == null || space == null) return;

    final paintedOrigin = _main(space.globalToLocal(pointer)) - _grabOffset;
    final draggedCenter = paintedOrigin + _mainSize(draggedBox) / 2;

    // Where does the dragged item belong among its siblings?
    final siblings = [
      for (final key in order)
        if (key != dragged) key
    ];
    var newIndex = 0;
    for (final key in siblings) {
      final box = _box(key);
      if (box == null) continue;
      final center = _layoutOrigin(key, space) + _mainSize(box) / 2;
      if (center < draggedCenter) newIndex++;
    }

    final target = [...siblings]..insert(newIndex, dragged);

    // Where the dragged item's slot will start once `target` is laid out:
    // the start of the list plus the sizes of the items before it.
    var listStart = double.infinity;
    for (final key in order) {
      if (_box(key) != null) {
        final origin = _layoutOrigin(key, space);
        if (origin < listStart) listStart = origin;
      }
    }
    var slot = listStart;
    for (final key in target.take(newIndex)) {
      final box = _box(key);
      if (box != null) slot += _mainSize(box) + _gap;
    }

    // Move the item so it stays under the finger in the new layout.
    final offset = paintedOrigin - slot;
    _ctl(dragged).set(NibAnim(
      x: _horizontal ? offset : 0,
      y: _horizontal ? 0 : offset,
    ));

    if (!_sameOrder(target, order)) setState(() => _order = target);
    _updateAutoScroll();
  }

  static bool _sameOrder(List<Key> a, List<Key> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _end() {
    _scrollTicker?.stop();
    final dragged = _dragged;
    final order = _order;
    if (dragged == null || order == null) return;
    final newIndex = order.indexOf(dragged);
    final oldIndex = _originalIndex;
    setState(() {
      _dragged = null;
      _order = null;
    });
    _ctl(dragged).start(
      target: const NibAnim(x: 0, y: 0),
      transition: widget.layoutTransition ?? NibTransition.springSnappy,
    );
    if (newIndex != oldIndex) widget.onReorder(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final byKey = <Key, Widget>{for (final c in widget.children) c.key!: c};
    final keys = _order ?? _givenKeys;
    final decorator = widget.dragDecorator;
    final transition = widget.layoutTransition ?? NibTransition.springSnappy;

    final items = <Widget>[
      for (final key in keys.where(byKey.containsKey))
        _item(context, key, byKey[key]!, transition, decorator),
    ];

    int? raisedIndex;
    final spaced = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && _gap > 0) {
        spaced.add(SizedBox(
            width: _horizontal ? _gap : null,
            height: _horizontal ? null : _gap));
      }
      if (keys.where(byKey.containsKey).elementAt(i) == _dragged) {
        raisedIndex = spaced.length;
      }
      spaced.add(items[i]);
    }

    // The dragged item stays in its slot in the child list (so keys, state and
    // layout are untouched) but paints and hit-tests above its siblings.
    return NibLayoutScope(
      child: _PaintLastFlex(
        direction: widget.axis,
        raisedIndex: raisedIndex,
        children: spaced,
      ),
    );
  }

  Widget _item(BuildContext context, Key key, Widget child,
      NibTransition transition, NibReorderDecorator? decorator) {
    final dragging = key == _dragged;
    final content =
        decorator != null ? decorator(context, child, dragging) : child;
    return NibMotion(
      key: _gk(key),
      controller: _ctl(key),
      layout: dragging ? NibLayout.none : NibLayout.position,
      layoutTransition: transition,
      animate: NibAnim(scale: dragging ? widget.dragScale : 1.0),
      transition: NibTransition.springSnappy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) => _start(key, d.globalPosition),
        onLongPressMoveUpdate: (d) => _move(d.globalPosition),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: content,
      ),
    );
  }
}

/// A [Row]/[Column] (`mainAxisSize: min`) that paints one child last, above its
/// siblings, without changing the child order used for layout.
class _PaintLastFlex extends MultiChildRenderObjectWidget {
  const _PaintLastFlex({
    required this.direction,
    required this.raisedIndex,
    required super.children,
  });

  final Axis direction;

  /// Index (in [children], spacers included) of the child to paint on top.
  final int? raisedIndex;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintLastFlex(
        direction: direction,
        mainAxisSize: MainAxisSize.min,
        textDirection: Directionality.maybeOf(context),
        raisedIndex: raisedIndex,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderPaintLastFlex renderObject) {
    renderObject
      ..direction = direction
      ..textDirection = Directionality.maybeOf(context)
      ..raisedIndex = raisedIndex;
  }
}

class _RenderPaintLastFlex extends RenderFlex {
  _RenderPaintLastFlex({
    super.direction,
    super.mainAxisSize,
    super.textDirection,
    int? raisedIndex,
  }) : _raisedIndex = raisedIndex;

  int? _raisedIndex;
  set raisedIndex(int? value) {
    if (_raisedIndex == value) return;
    _raisedIndex = value;
    markNeedsPaint();
  }

  RenderBox? _raisedChild() {
    final index = _raisedIndex;
    if (index == null) return null;
    var child = firstChild;
    for (var i = 0; child != null; i++) {
      if (i == index) return child;
      child = childAfter(child);
    }
    return null;
  }

  @override
  void defaultPaint(PaintingContext context, Offset offset) {
    final raised = _raisedChild();
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      if (child != raised) context.paintChild(child, data.offset + offset);
      child = data.nextSibling;
    }
    if (raised != null) {
      final data = raised.parentData! as FlexParentData;
      context.paintChild(raised, data.offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final raised = _raisedChild();
    bool hit(RenderBox child) {
      final data = child.parentData! as FlexParentData;
      return result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
    }

    if (raised != null && hit(raised)) return true;
    var child = lastChild;
    while (child != null) {
      if (child != raised && hit(child)) return true;
      child = childBefore(child);
    }
    return false;
  }
}
