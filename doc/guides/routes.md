---
{
  "id": "routes",
  "evidence": "MotionNib/motion/lib/src/routes/nib_routes.dart; MotionNib/motion/lib/src/routes/nib_shared_source.dart"
}
---

# Page and modal routes

Move a Navigator route while keeping dismissal and state ownership clear.

<!-- section: push-page -->
## Push a page with a visible endpoint

NibPageRoute is a PageRoute. Pass a builder to Navigator.push and let the Navigator own the route lifetime. Its default content starts transparent and 32 logical pixels lower, then reaches NibAnim.identity. Popping uses the starting pose as the default exit. The default transition is a spring. duration controls the route entrance; reverseDuration is a minimum exit lifetime and grows if the spring needs longer to settle.

Keep page data and decisions in the destination widget as usual. A route animation should not become the only way to understand which page is open. Press Back during entrance and check that the content heads toward its exit without briefly returning to the start pose.

```dart
Navigator.of(context).push(
  NibPageRoute<void>(
    builder: (_) => const Scaffold(
      body: Center(child: Text('Details')),
    ),
  ),
);
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| backSwipe | bool | false | Enable the start-edge interactive pop gesture. |
| parallax | double | 0.3 | Fractional shift of the covered route during a back swipe above it. |
| maintainState | bool | true | Keep the covered page state alive. |

<!-- section: back-swipe -->
## Test an interrupted back swipe

backSwipe is off by default. When enabled, a drag from the start-edge strip follows the pointer; releasing beyond 40 percent of page width or with a fast fling pops, while a shorter gesture springs back. The direction mirrors in right-to-left layouts. parallax shifts the route below only during that interactive gesture, and zero disables the effect.

Test a cancelled drag, a committed drag, a fast fling, and a pop while entrance is still running. Check the edge hit target against any control placed there. A compiled route cannot establish physical touch behavior, so perform these interactions on the platform you claim to support.

<!-- section: modal -->
## Use a modal route for a dialog result

NibModalRoute is a PopupRoute with a barrier, Navigator dismissal, and a result type. showNibDialog pushes one on the root Navigator by default. Its initial pose is transparent at 92 percent scale; its default duration and reverseDuration are 350 and 250 ms. The barrier is dismissible by default, so turn that off when the host action requires an explicit decision.

The builder supplies the content. Put confirmation semantics, focus order, and the real action in that content; the route only animates it. A result from Navigator.pop returns through the Future. Check that a pending confirmation is invalidated when its underlying state changes, rather than treating the animation as authorization.

```dart
final confirmed = await showNibDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => Center(
    child: TextButton(
      onPressed: () => Navigator.of(dialogContext).pop(true),
      child: const Text('Confirm'),
    ),
  ),
);
```

<!-- section: shared-source -->
## Mark the source of a shared transition

Give a NibSharedSource a GlobalKey and pass the same key as sharedFrom to NibPageRoute, NibModalRoute, or showNibDialog. The source keeps its layout space while the route stands in for it, then reappears when the route leaves. Without the wrapper, a plain GlobalKey can still provide geometry, but its source remains visible beneath the route.

Keep the source mounted long enough for the transition to measure it. A shared pose depends on rectangles across the source and destination; perspective, nearly singular transforms, and clipped overlays are outside the current verified geometry contract. Test focus and hit targets when the source is hidden and restored.

```dart
final sourceKey = GlobalKey(); // Keep in State.

NibSharedSource(
  sourceKey: sourceKey,
  child: const Icon(Icons.photo),
)

// In a button callback:
Navigator.of(context).push(
  NibPageRoute<void>(
    sharedFrom: sourceKey,
    builder: (_) => const Scaffold(body: Icon(Icons.photo)),
  ),
);
```

<!-- section: route-next -->
## Choose route motion for a navigation job

Use NibScreenStack and NibNavBar for persistent tab screens; use NibPageRoute for a pushed page and NibModalRoute for an overlay with a result. These solve different ownership problems. Continue to Navigation for tab state retention and to Accessibility for reduced motion and focus checks.
