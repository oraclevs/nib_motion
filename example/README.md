# nib_motion example

Two entry points:

* `lib/main.dart` — the original showcase app.
* `lib/demos.dart` — a menu of 21 small screens, one per `nib_motion` feature
  (interruption, drag/inertia/snap, presence, layout FLIP, routes, sliver
  header, timeline scrubbing, spring tuner, velocity read, size modes,
  `NibValueBuilder`, page/tab/viewport progress, directional transitions,
  simulation driver, …). Each screen says what to try at the top.

## Run the demos

```bash
cd example
flutter pub get

# Linux desktop
flutter run -d linux -t lib/demos.dart

# Android / iOS (device or emulator)
flutter run -t lib/demos.dart

# Web (Chrome, hot reload)
flutter run -d chrome -t lib/demos.dart

# Web without Chrome: serve on a port and open the URL in any browser
flutter run -d web-server --web-port 8080 -t lib/demos.dart
# http://localhost:8080
```

Platform folders (`android/`, `linux/`, `web/`) are generated; if one is
missing run `flutter create --platforms=<name> --project-name nib_motion_example .`.

## Tests

```bash
flutter test          # smoke test for every screen at phone and desktop size
```

`API_FEEDBACK.md` lists the awkward spots found while building these screens.
