# NibMotion guides

Start with [installation and your first animation](index.mdx), then choose a
guide for the behavior you need. For complete constructor signatures, use the
[published API reference](https://pub.dev/documentation/nib_motion/latest/).

## Build motion

| Goal | Guide |
| --- | --- |
| Animate state changes | [Targets and keyframes](animate.mdx), [transitions](transitions.mdx), [variants](variants.mdx) |
| Tune springs or run a custom simulation | [Spring basics](physics.mdx), [spring tokens and multi-axis values](physics.md), [interruption](interruption.md) |
| Respond to touch and pointer input | [Gesture states](gestures.mdx), [drag, pinch, and swipe dismissal](drag.mdx) |
| Animate layout and shared elements | [Layout groups](layout-animations.mdx), [per-widget layout and geometry limits](layout.md), [routes](routes.md) |
| Animate removals and lists | [Presence](presence.mdx), [lists and stagger](lists-and-stagger.mdx) |
| Connect motion to scrolling | [Viewport and scroll](viewport-and-scroll.mdx), [parallax and reveal](scroll-effects.mdx) |
| Coordinate several animations | [Controllers](motion-controller.mdx), [timeline basics](timeline.mdx), [relative timing and scrubbing](timeline.md) |
| Build reactive motion | [Motion values and ownership](motion-values.md), [architecture](architecture.md) |
| Add visual effects | [Text](text.mdx), [paths](path.mdx), [presets](presets.mdx), [shaders](shaders.mdx), [water](water.md) |
| Build animated navigation | [Navigation bars and screen stacks](navigation.mdx), [route transitions](routes.md) |

## Ship and maintain

- [Compatibility and known limits](compatibility.md)
- [Reduced motion and accessibility](accessibility.md)
- [Migration from Flutter controllers and other packages](migration.md)
- [Troubleshooting](troubleshooting.md)
- [Debugger](debugging.mdx), [spring tuner and replay tools](debug-tools.md)
- [Performance measurements and reproduction instructions](performance.md)
- [Runnable example application](../example/README.md)
- [Contributing](../CONTRIBUTING.md)

Examples that define a widget class can be placed in a Flutter application.
Short expressions and statements are contextual fragments: they assume the
surrounding widget, imports, and application values described by that guide.
Blocks marked `text` describe signatures or integration sketches, not complete
Dart programs. The [README examples](../example/lib/readme/) provide complete
entry points.

The `.mdx` guides remain at their existing paths. The shorter `.md` guides
cover runtime contracts and newer APIs in more detail; neither requires a
website build to read on GitHub.
