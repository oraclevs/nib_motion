---
{
  "id": "installation",
  "evidence": "MotionNib/motion/pubspec.yaml; MotionNib/motion/lib/nib_motion.dart; MotionNib/motion/CHANGELOG.md"
}
---

# Installation

Install the hosted package and inspect the version your app uses.

<!-- section: prerequisites -->
## Start from a working Flutter app

Run flutter doctor and make sure your app already builds on the platform you care about. Open the app’s pubspec.yaml at its project root; that is the directory where flutter pub add belongs. The command updates the dependency declaration and lockfile for that app. It does not change another Flutter project in the workspace.

If you only want animation, add nib_motion. nib_components is a separate package that depends on motion, but it is not required for the first tutorial. A direct motion dependency makes the API you use explicit in your app’s manifest.

<!-- section: add -->
## Add the package

Run the package manager from your Flutter app, then import the public barrel. These Motion guides were checked against 0.3.5. Version 0.3.6 is published; check pubspec.lock for the version your app resolved.

```dart
flutter pub add nib_motion
flutter pub get
flutter pub deps --style=compact
```

<!-- section: import -->
## Use public exports

Import package:nib_motion/nib_motion.dart for NibMotion, NibAnim, transitions, values, gestures, layout, presence, and the other exported widgets. Application code should not import lib/src files: that bypasses the package’s public surface.

```dart
import 'package:nib_motion/nib_motion.dart';
```

<!-- section: first-build -->
## Prove the import in a small screen

After the package resolves, put the public import at the top of a Dart file with a Flutter widget. Wrap a visible child in NibMotion, give it initial opacity zero and animate opacity one, and run the app. The child should appear when the entrance starts. If it appears immediately, check the system’s reduced-motion setting before assuming the import failed.

Use flutter analyze and your app’s test or run command after adding the widget. Compilation verifies the API available in your resolved archive. Then use flutter pub deps --style=compact and pubspec.lock to record the actual nib_motion version. These guides are checked against 0.3.5; compare your lockfile when following an older tutorial.

```dart
import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

// Inside a build method:
NibMotion(
  initial: const NibAnim(opacity: 0),
  animate: const NibAnim(opacity: 1),
  child: const Text('Installed and moving'),
)
```

<!-- section: compatibility -->
## Check the resolved graph

The published 0.3.5 package requires Flutter 3.29 or newer and Dart 3.0 or newer. Check the constraints in the exact version you resolve, then compile a copied example against your own SDK. A web build or widget test does not establish physical-device rendering behavior.

Read the changelog when updating to 0.3.6. The live examples on the website still use the 0.3.5 implementation; compile copied code against the version resolved in your app.

<!-- section: resolution-problems -->
## If installation or compilation fails

First read the solver error instead of changing version ranges blindly. It names the package or SDK constraint that could not be satisfied. Compare that requirement with flutter --version, your pubspec.yaml, and pubspec.lock. The 0.3.5 archive declares a Flutter 3.29 floor; inspect the archive you actually resolved.

If an import is red after a successful pub get, check its spelling and make sure the Dart file belongs to the app whose pubspec was changed. Use the package barrel, not a lib/src path. If a copied recipe mentions an unavailable constructor parameter, compare it with the version in your lockfile; these guides target 0.3.5.

<!-- section: after-installation -->
## Move to a stateful example

The opacity entrance confirms package resolution, but it does not teach retargeting. Continue to Start with motion for a staged entrance, then Your first animation for a responsive state change. A package can compile on one target while shader rendering or touch behavior still needs device testing, so keep those later checks separate from installation.
