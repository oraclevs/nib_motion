---
{
  "id": "navigation",
  "evidence": "MotionNib/motion/lib/src/routes/nib_routes.dart; MotionNib/motion/lib/src/nav/nib_scaffold.dart; MotionNib/motion/lib/src/nav/nib_screen_stack.dart"
}
---

# Navigation motion

Animate route content or use the package’s bottom navigation shell.

<!-- section: routes -->
## Animate a page or modal route

NibPageRoute and NibModalRoute wrap route content in NibMotion. Their defaults fade and shift a page or scale a modal toward identity. The route duration controls route lifetime and barrier timing; the content transition can be spring-driven. Reverse route lifetime is extended to let the exit transition settle.

NibPageRoute.backSwipe is off by default. When enabled, a start-edge drag can pop after crossing 40 percent of the page width or a fast release. Keep a non-gesture back action and test RTL and nested navigation in the host app.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| builder | WidgetBuilder | required | Route content. |
| backSwipe | bool | false | Enable start-edge interactive pop on a page route. |
| duration | Duration | 350 ms | Route entrance lifetime, distinct from content spring settling. |

```dart
// Inside a button callback with a mounted context.
Navigator.of(context).push(
  NibPageRoute<void>(builder: (_) => const DetailsPage()),
);
```

<!-- section: route-lifecycle -->
## Understand the route and content clocks

NibPageRoute builds content through builder and wraps it in motion between initial, animate, and exit. Its default page state starts transparent and 32 logical pixels lower, then settles at identity. NibModalRoute starts transparent and slightly smaller. Both default exit to their initial state. The route duration is 350 ms by default, while the content transition is spring-driven by default; reverse route lifetime is extended when needed so the exit spring can finish before removal.

Keep navigation intent in the Navigator. The animation is a visual transition around that route, not a replacement for route state or back behavior. A page may remain mounted while another covers it when maintainState is true. Back-swipe is opt-in; it begins from a 24 logical-pixel start-edge strip, commits after 40 percent width or a 700 logical-pixel-per-second release toward back, and mirrors in RTL. Test a normal back button as well as the gesture.

<!-- section: shell -->
## Use an animated tab shell

NibScaffold accepts equal-length screens and navItems lists and owns the selected tab index. NibScreenStack keeps screens mounted according to each NibNavScreen.keepAlive value and animates outgoing and incoming content. NibNavScreenTransition chooses fade, horizontal or vertical slide, scale, shared-axis, or none.

A nav badge with null count is a dot, zero hides it, and counts above 99 display 99+. Test labels, focus order, and route state retention after repeated tab changes.

<!-- section: tab-shell-exercise -->
## Choose route motion or tab motion

Use a page route when a screen is pushed onto a navigation stack and should be popped later. Use NibScaffold when the user switches between peer destinations. Give NibScaffold equal-length screens and navItems lists. NibNavScreen.keepAlive defaults to true, so decide whether a tab should retain forms, scroll position, and controllers while another is selected. A non-retained tab can rebuild from its initial state after return.

Try the route snippet by pushing a details page, popping it, then repeating with backSwipe enabled. Next build two tab screens and switch while the first has a half-filled form. Observe whether the form persists with keepAlive true, then set it false. Exercise keyboard focus and screen-reader labels during these changes. When placing a floating navigation bar over content, account for the body inset or extendBodyBehindNavBar intentionally so controls are not obscured.

<!-- section: shared -->
## Use shared-source handoffs carefully

The route sharedFrom key can animate content out of an existing source widget. The source must remain mounted below the route when measured; otherwise the route falls back to its normal initial and exit states. Treat that as a conditional visual enhancement, not a required navigation path.

<!-- section: shared-exercise -->
## Make the shared source optional

Wrap a source thumbnail in NibSharedSource with a GlobalKey, then pass that key as sharedFrom to the pushed route. Keep the source mounted below the new route during both entry and return; the route measures it when transitioning. If the source disappears because a filter changes or a list item is disposed, the route uses its ordinary initial and exit states. Verify both paths. Do not make completion of a business action depend on the shared measurement succeeding.
