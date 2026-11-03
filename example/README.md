# NibMotion interactive gallery

The gallery runs real Flutter examples using the local `nib_motion` package.
It includes all **21 original demos**, the **Daily Focus** application, both
**README quick starts**, and **five new examples** covering text, bundled
shaders and glass, paths, variants and presets, and animated navigation.
Only the selected example is mounted; the overview uses static cards.

## Open the gallery

From a repository checkout with Flutter 3.29 or newer:

```bash
flutter pub get
cd example
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 -t lib/demos.dart
```

Open **http://127.0.0.1:8080**. Keep that terminal running. The gallery uses
hash routes, so a link such as `http://127.0.0.1:8080/#/demo/interruption`
can be refreshed or shared with someone who can reach the same server.
Use `flutter run -d chrome -t lib/demos.dart` for Chrome debugging.

The web scaffold is tracked in Git. Other platform directories, and the web
directory in a pub.dev package download, can be generated when needed:

```bash
flutter create --empty --platforms=web --project-name nib_motion_example .
```

Inspect existing platform files before regenerating them. Replace `web` with
`linux`, `android`, or `ios` for a native target. The entry points remain:

- `lib/demos.dart`: the interactive gallery.
- `lib/main.dart`: the standalone Daily Focus application.
- `lib/readme/entrance.dart` and `lib/readme/retarget.dart`: complete README examples.

## Explore and review

Desktop shows search and categories in the sidebar. On phones, open the menu.
Every page has instructions, a source link, replay/reset, and previous/next
navigation. The toolbar changes theme and motion preference. The default motion
preference follows the system.

Open **Show owner review** in the toolbar. Each example accepts a status and
notes. **Export JSON** shows all 29 decisions as selectable text, with a copy
button. Save that text to a local file; **Import JSON** restores it later.
Reviews remain in memory: **export before refreshing or closing the page**.
Import validates the entire document before changing any decisions and merges
recognized entries with the current review.

The [maintainer audit](../doc/maintainers/showcase-audit.md) records functional
checks, presentation recommendations, and known limitations. Shader loading
and glass fallbacks are labeled in the example. Experimental water and
user-supplied fragment shaders are not added to this gallery.

## Extend an example

Use `DemoScaffold` for a screen and add metadata in
`lib/gallery/registry.dart`. Preserve the original `demoEntries` list and its
titles. Add new entries to `galleryEntries`, using a unique, stable slug and a
real source path. Keep controllers local, dispose listeners and timers, and
respect `NibMotionConfig` / reduced motion. Avoid starting animations on cards
in the overview. Add interaction, narrow-layout, and disposal coverage.

Source links currently point to the showcase review branch. Update that ref
only after integration, when the corresponding files exist on the new ref.

## Validate

```bash
flutter analyze --fatal-infos
flutter test
flutter build web -t lib/demos.dart
flutter build web --wasm -t lib/demos.dart
```

Tests cover the complete registry, all pages at mobile and desktop widths,
search, categories, routes, review import/export, repeated navigation, and
example interactions. README tests also check both published Dart snippets
against their runnable sources. Widget tests do not establish browser shader
support or frame rate; rehearse in the browser and renderer used for the talk.
