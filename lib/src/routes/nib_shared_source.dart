import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Marks the widget a route grows out of (`sharedFrom`) so it can be hidden
/// while the route's content is standing in for it.
///
/// Wrap the source in a `NibSharedSource` and pass the same [sourceKey] to
/// `NibModalRoute`/`NibPageRoute`/`showNibDialog(sharedFrom:)`. While the
/// route is open the source keeps its layout space but paints nothing, so the
/// grown-out content is not drawn on top of its own thumbnail; it reappears
/// when the route has shrunk back over it.
///
/// Without a `NibSharedSource` (a plain `GlobalKey` on any widget) the hand-off
/// still animates; the source simply stays visible underneath.
///
/// ```dart
/// final key = GlobalKey();
/// NibSharedSource(sourceKey: key, child: Thumbnail());
/// Navigator.push(context, NibPageRoute(sharedFrom: key, builder: ...));
/// ```
class NibSharedSource extends StatefulWidget {
  /// Creates a source that can be hidden by a route using [sourceKey].
  const NibSharedSource({
    super.key,
    required this.sourceKey,
    required this.child,
  });

  /// The key to pass as `sharedFrom`. It is attached to this widget's box, so
  /// the route measures the source's rectangle from it.
  final GlobalKey sourceKey;

  /// The widget the route grows out of.
  final Widget child;

  @override
  State<NibSharedSource> createState() => _NibSharedSourceState();
}

/// Live sources by key, and how many routes currently ask for each to be
/// hidden (several routes may share one source).
final Map<GlobalKey, _NibSharedSourceState> _sources =
    <GlobalKey, _NibSharedSourceState>{};
final Map<GlobalKey, int> _hideCounts = <GlobalKey, int>{};

/// Asks the [NibSharedSource] registered under [key] (if any) to hide.
/// Balanced by [nibSharedSourceShow].
void nibSharedSourceHide(GlobalKey key) {
  _hideCounts[key] = (_hideCounts[key] ?? 0) + 1;
  _sources[key]?._refresh();
}

/// Undoes one [nibSharedSourceHide]. The source reappears when no route still
/// asks for it to be hidden. With [defer], the rebuild happens after the
/// current frame (use it when called while the widget tree is being torn down).
void nibSharedSourceShow(GlobalKey key, {bool defer = false}) {
  final count = (_hideCounts[key] ?? 0) - 1;
  if (count <= 0) {
    _hideCounts.remove(key);
  } else {
    _hideCounts[key] = count;
  }
  _sources[key]?._refresh(defer: defer);
}

class _NibSharedSourceState extends State<NibSharedSource> {
  @override
  void initState() {
    super.initState();
    _sources[widget.sourceKey] = this;
  }

  @override
  void didUpdateWidget(NibSharedSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceKey != widget.sourceKey) {
      if (identical(_sources[oldWidget.sourceKey], this)) {
        _sources.remove(oldWidget.sourceKey);
      }
      _sources[widget.sourceKey] = this;
    }
  }

  @override
  void dispose() {
    if (identical(_sources[widget.sourceKey], this)) {
      _sources.remove(widget.sourceKey);
    }
    super.dispose();
  }

  void _refresh({bool defer = false}) {
    if (!mounted) return;
    if (defer) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = (_hideCounts[widget.sourceKey] ?? 0) > 0;
    return Opacity(
      key: widget.sourceKey,
      opacity: hidden ? 0.0 : 1.0,
      alwaysIncludeSemantics: false,
      child: widget.child,
    );
  }
}
