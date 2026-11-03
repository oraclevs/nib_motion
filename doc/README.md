# NibMotion guides

The canonical website guides are authored here in GitHub. Edit the Markdown
under `doc/guides/`; the website imports an immutable commit at build time.
`doc/website.json` declares the supported package version and complete inventory.
Existing guide paths below remain available as supplemental API and runtime notes.

## Canonical website guides

- [Introduction](guides/introduction.md)
- [Installation](guides/installation.md)
- [Getting started](guides/getting-started.md)
- [First animation](guides/first-animation.md)
- [Springs](guides/springs.md)
- [Keyframes](guides/keyframes.md)
- [Motion values](guides/motion-values.md)
- [Presence](guides/presence.md)
- [Gestures](guides/gestures.md)
- [Scroll motion](guides/scroll-motion.md)
- [Accessibility](guides/accessibility.md)
- [Transitions](guides/transitions.md)
- [Variants stagger](guides/variants-stagger.md)
- [Layout animations](guides/layout-animations.md)
- [Layout presence](guides/layout-presence.md)
- [Performance](guides/performance.md)
- [Api](guides/api.md)
- [Platform limits](guides/platform-limits.md)
- [Troubleshooting](guides/troubleshooting.md)
- [Controllers](guides/controllers.md)
- [Timeline](guides/timeline.md)
- [Text motion](guides/text-motion.md)
- [Path motion](guides/path-motion.md)
- [Navigation](guides/navigation.md)
- [Shaders](guides/shaders.md)
- [Physics](guides/physics.md)
- [Presets](guides/presets.md)
- [Motion lists](guides/motion-lists.md)
- [Viewport motion](guides/viewport-motion.md)
- [Drag and drop](guides/drag-and-drop.md)
- [Animation sequences](guides/animation-sequences.md)
- [Routes](guides/routes.md)
- [Water](guides/water.md)
- [Debugging](guides/debugging.md)
- [Migration](guides/migration.md)

## Package guides

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
