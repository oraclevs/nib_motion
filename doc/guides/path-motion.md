---
{
  "id": "path-motion",
  "evidence": "MotionNib/motion/lib/src/path/nib_draw_path.dart; MotionNib/motion/lib/src/path/nib_path_motion.dart"
}
---

# Path motion

Draw a Path or move a child along its local geometry.

<!-- section: path-shape -->
## Place the path in a bounded box

A Flutter Path contains coordinates, but it does not choose the surrounding widget’s size. Build it for the box that will display it, such as a 240 by 120 logical-pixel SizedBox, and check that every control point lies where you expect. NibDrawPath reveals the stroke from the beginning of the measured path; it does not move a child. NibPathMotion samples the path tangent at a zero-to-one progress fraction and paints its child there. rotate: true follows the tangent, so an icon’s original orientation matters.

For a static status mark, give NibDrawPath a short path and let autoPlay start it on mount. For a moving icon that must follow scroll, supply an external MotionValue<double> progress. That disables the internal duration, curve, repeat, and autoPlay behavior. Clamp and dispose that value in the caller; the path widget reads it but does not take ownership. The controller play, pause, and restart commands affect only internally driven traversal.

<!-- section: draw -->
## Reveal a stroke

NibDrawPath takes a Flutter Path and paints its stroke progressively. strokeWidth defaults to 2 logical pixels, duration to 1000 ms, curve to easeOut, and autoPlay to true. Use NibDrawPathController for play, pause, and restart; NibMotionController does not control this widget.

```dart
// In build(); signaturePath uses this box’s local coordinates.
NibDrawPath(
  path: signaturePath,
  color: Theme.of(context).colorScheme.primary,
  strokeWidth: 3,
  duration: const Duration(milliseconds: 1200),
)
```

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| path | Path | required | Geometry of the stroke to reveal. |
| strokeWidth | double | 2.0 | Stroke width in logical pixels. |
| duration | Duration | 1000 ms | Time for one draw traversal. |

<!-- section: follow -->
## Move a child along the path

NibPathMotion measures the Path in the widget’s local coordinate space and positions its child at progress zero through one. rotate aligns the child to the path tangent when true. Its internal traversal defaults to 1000 ms, easeInOut, autoPlay true, and no repeat.

Supply an external MotionValue<double> as progress to drive traversal yourself, such as from scroll. In that mode duration, curve, repeat, and autoPlay are ignored. The caller owns and disposes the external value; a NibPathMotionController can play, pause, or restart the internal traversal instead.

<!-- api -->
| Name | Type | Default | Description |
| --- | --- | --- | --- |
| progress | MotionValue<double>? | null | External zero-to-one driver when supplied. |
| rotate | bool | false | Align the child to the path tangent. |
| autoPlay | bool | true | Start internal traversal on mount. |

<!-- section: hands-on -->
## Check replay and a changed parent

Start with the stroke example above, add a NibDrawPathController owned by State, set autoPlay: false, and call restart from a button. Pause halfway, inspect the visible segment, then play again. In the current implementation, play starts a fresh ticker time origin after pause, so the next tick can jump back toward the beginning; test this before promising exact resume. Repeat with NibPathMotion and its separate NibPathMotionController. These controllers do not implement the NibMotionController target API because progress along a path is a different quantity from a NibAnim property target.

Next change the parent box width while traversal is paused. The same Path coordinates may now occupy a different fraction of the available space; decide whether to rebuild the Path from the new constraints. Test the endpoint, child hit area, and tangent rotation. With reduced motion, the internally driven path shows its completed state. Keep the completed mark or destination understandable even when the travel is skipped.

If nothing is visible, first draw the same Path with a static CustomPaint to confirm its bounds before debugging the animation clock. NibPathMotion follows the first measurable contour, so use a continuous contour for one trip or separate multiple trips into distinct widgets. Dispose any external progress value and any controller created by your State. Replacing a path while a controller is paused should be tested at both the old and new endpoints.

<!-- section: geometry -->
## Test the path in its real constraints

A Path is a local geometry object. Verify its bounds and hit behavior inside the final parent layout, especially when a rotated child or transformed ancestor is involved. Keep a static endpoint meaningful when reduced motion skips traversal.
