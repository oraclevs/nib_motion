---
{
  "id": "scroll-motion",
  "evidence": "MotionNib/motion/lib/src/scroll/nib_scroll_reveal.dart; MotionNib/motion/lib/src/scroll/nib_scroll_motion.dart; MotionNib/motion/lib/src/scroll/scroll_motion_bridge.dart"
}
---

# Scroll motion

Reveal content on entry or map scroll position to paint values.

<!-- section: which-tool -->
## Choose entry or continuous progress

Use NibScrollReveal when a child should react once it becomes visible. Its initial and animate values describe two states; amount is the visible fraction needed to trigger, and once controls whether leaving the viewport restores the hidden state. This is a good fit for a card entering a list.

Use NibScrollMotion or ScrollMotionBridge when position itself should drive a value continuously, such as a header fading over the first 200 logical pixels of scroll. A reveal checks a visibility threshold; a bridge tracks offset. NibParallax is a convenience for a factor-based offset, where zero pins the layer and one follows the scroll movement one-to-one.

<!-- section: reveal -->
## Trigger on viewport entry

NibScrollReveal wraps a child in viewport-driven NibMotion. Its default initial state fades from opacity zero and y: 32; animate defaults to identity. once defaults to true and amount defaults to 0.2, meaning roughly one fifth of the widget must be visible before activation.

Scroll inside the framed window in the live example. The final card uses once: false, so it can reveal again after leaving and re-entering that viewport. Use a one-time reveal for content that should stay visible after first exposure.

```dart
NibScrollReveal(
  once: false,
  amount: 0.2,
  child: const Text('In view'),
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| initial | NibAnim | opacity: 0, y: 32 | State before the child enters the viewport. |
| once | bool | true | Keep the revealed state after the first entry. |
| amount | double | 0.2 | Fraction of the child that must be visible. |

<!-- section: viewport -->
## Use the actual viewport

A nested scrolling panel has its own viewport. Test entry and exit by scrolling that panel, not only the page around it. Avoid hiding essential text until a scroll gesture occurs; reduced motion should still reveal the final content.

<!-- section: try-the-viewport -->
## Scroll the framed panel

The live example contains a 160-pixel-high ListView inside the documentation page. Drag inside that framed list. The last card starts outside its viewport and reveals when it enters. Drag back out and in again: because the example sets once: false, it returns to its initial state on exit and can replay. Change once to true in a copied example to keep the card visible after its first reveal.

Scroll the outer page without touching the inner list. Its last card remains below the inner viewport, so the outer scroll alone cannot reveal it. Visibility is checked against both the screen and enclosing scroll viewports. Testing only the page scroll can therefore miss a nested-view problem. Keep required content accessible even if the reveal never fires.

<!-- section: link -->
## Map an existing ScrollController

NibScrollMotion takes a ScrollController and gives its builder a ScrollMotionBridge. The bridge exposes scrollX and scrollY MotionValues. Map a range of scrollY into opacity or position, then pass the derived value through NibMotionValues.

NibScrollMotion owns its bridge, but the application still owns the ScrollController. If you construct ScrollMotionBridge directly, dispose it yourself. NibParallax offers a simpler factor-based offset: zero pins the child and one follows scrolling one-to-one.

<!-- section: drive-from-offset -->
## Own the scroll controller and derived value

For a continuously fading header, create a ScrollController in your State and attach it to the actual ListView. Create a ScrollMotionBridge from that controller, then derive opacity from bridge.scrollY with mapRange([0, 200], [1, 0]). Pass that derived value through NibMotionValues(opacity: ...). These numbers mean fully visible at offset zero and transparent at 200 logical pixels.

NibScrollMotion can create and dispose the bridge for its builder, but a mapRange value you create from the bridge is still your derived value to manage. If you own the bridge directly, dispose the derived value first, then the bridge, then the ScrollController. Creating a new derived value on every build can leave listeners behind.

```dart
final controller = ScrollController();
late final bridge = ScrollMotionBridge(controller: controller);
late final opacity = bridge.scrollY.mapRange([0, 200], [1, 0]);

// In build, attach controller to the scroll view and pass opacity to:
NibMotion(motionValues: NibMotionValues(opacity: opacity), child: header)

// In dispose: opacity.dispose(); bridge.dispose(); controller.dispose();
```

<!-- section: scroll-errors -->
## Check the right controller and lifetime

If nothing changes, check that the same ScrollController is attached to the scrolling widget and the bridge. If the motion jumps, inspect the mapRange stops and whether clamping is appropriate. If a removed screen still has scroll listeners, inspect the disposal order and any derived values created inside builder callbacks.

The value path avoids rebuilding the animated child for each scroll tick, but it does not make a large page free to rasterize. The next lesson on Motion values explains derived values in isolation; Accessibility covers the endpoint when motion is reduced.
