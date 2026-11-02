# Contributing to NibMotion

Bug reports, documentation fixes, examples, and code contributions are welcome.
For a new feature or a public API change, open an issue first so we can discuss
the use case and compatibility before you spend time on an implementation.

## Set up

Use Flutter 3.29.0 or newer with its bundled Dart SDK. CI checks Flutter 3.29.0
and 3.47.8; use 3.47.8 for web and shader checks. The package has no runtime
dependencies outside Flutter.

```bash
git clone https://github.com/oraclevs/nib_motion.git
cd nib_motion
flutter pub get
git switch -c fix/describe-the-change
```

The example app keeps generated platform folders out of the published archive.
To run it in Chrome:

```bash
cd example
flutter create --empty --platforms=web --project-name nib_motion_example .
flutter run -d chrome -t lib/demos.dart
```

Use `flutter create --empty --platforms=android,ios,linux,macos,windows .` only for the
targets you need and can build on your host. Do not commit generated platform
projects as part of an unrelated change.

## Before opening a pull request

Run from the package root:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
python3 -m unittest discover -s tool -p 'test_*.py'
dart pub publish --dry-run
```

For shader or rendering changes, also run:

```bash
flutter test --enable-impeller test/shaders
cd example
flutter create --empty --platforms=web --project-name nib_motion_example .
flutter build web --wasm
flutter build web --wasm -t lib/demos.dart
```

The root analyzer excludes `example/`. Run `flutter analyze --fatal-infos`
inside `example/` when you change its source. A successful Wasm build checks
compilation, not visual fidelity on every browser or device.

## How the package fits together

- `lib/nib_motion.dart` defines the public exports.
- `lib/src/core/` connects declarative targets, transitions, and rendering.
- `lib/src/values/` contains reactive motion values; `lib/src/physics/` drives
  them with springs, inertia, and custom simulations.
- `lib/src/layout/`, `presence/`, `gestures/`, and `scroll/` handle interaction
  and widget lifecycle. Visual effects live in `shaders/`, `text/`, and `water/`.
- `test/` contains unit and widget regression tests. `example/` contains the
  interactive gallery. `benchmark/` contains reproducible measurement harnesses.
- [The documentation index](doc/README.md) links to guides and known limits.

Keep changes focused and preserve existing public behavior. Export new public
types through `lib/nib_motion.dart`, document their members, and add a small
example. Keep implementation details private. Do not add a dependency for code
that the package or Flutter already provides.

## Animation and rendering changes

Add a regression test that fails without the fix. Check interruption, disposal,
reduced motion, and `TickerMode` when the change affects drivers or lifecycle.
Coordinate or layout changes need coverage under transformed ancestors, not
only an untransformed screen. Preserve semantics, keyboard access, and hit tests.

For shaders, capture the renderer, device, Flutter version, and fallback behavior.
Check a real device when making a visual or performance claim. Follow
[the performance guide](doc/performance.md) for benchmarks and their limits;
unit-test timings do not establish GPU performance.

## Submit the change

Open a pull request against `main`. Describe the problem, the resulting behavior,
and the checks you ran. Include a recording for a visible change when useful.
Update the relevant guide and changelog for public behavior changes. Use commit
subjects such as `fix(presence): retain exit bounds` or `docs: clarify spring
interruption`. Do not include unrelated formatting or generated files.

Maintainers review changes before merging. Version bumps and publication follow
[the release checklist](doc/maintainers/release.md); contributors do not need to
create release tags.

Please follow the [code of conduct](CODE_OF_CONDUCT.md). Report vulnerabilities
privately using [the security policy](SECURITY.md).
