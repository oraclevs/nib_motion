# Apple compatibility checks for NibMotion 0.3.7

Run these commands from a clean checkout of the candidate commit. Flutter
3.50.0 or newer and current Xcode must be installed on the MacBook. The package
minimum remains Flutter 3.29.0; CI tests that floor separately.

## Prepare the MacBook

Install Xcode from the App Store, open it once, accept its license, and install
its components. Install Flutter 3.50.0 from the [Flutter SDK archive](https://docs.flutter.dev/install/archive)
and add its `bin` directory to `PATH`. Then run:

```bash
xcode-select -p
xcodebuild -version
flutter --version
flutter doctor -v
flutter config --enable-macos-desktop
flutter devices
git status --short
```

Fix errors shown by `flutter doctor -v` before testing. The runner rejects a
dirty source checkout. It creates ignored native example scaffolds when absent.

## Run macOS checks

From the `nib_motion` repository root:

```bash
python3 qa/apple_runner.py macos
```

The runner checks tools and the selected Mac device, compiles every bundled
shader to generated Metal source, builds the macOS gallery, runs the shared
integration suite, and saves raw output and structured outcomes. A GitHub
hosted Mac run is CI evidence, not physical MacBook evidence.

## Prepare and run the physical iPhone

Unlock the iPhone, connect it with a cable, accept **Trust This Computer**, and
enable Developer Mode if prompted. Pair it in Xcode's **Window > Devices and
Simulators**. Run:

```bash
xcrun devicectl list devices
flutter devices
flutter create --empty --platforms=ios --project-name nib_motion_example example
open example/ios/Runner.xcworkspace
```

In Xcode, select the **Runner** target, open **Signing & Capabilities**, choose
your development team, and enable automatic signing. A valid Apple Development
signing identity must exist. This local iOS scaffold is ignored by Git.
Copy the physical iPhone ID from `flutter devices`, then run:

```bash
python3 qa/apple_runner.py ios --device YOUR_IPHONE_DEVICE_ID
```

The runner refuses a simulator for this command. It records signing and device
preflight, then runs the same integration suite on the phone. iPhone screenshot
export is manual because the test app's sandbox is not a host filesystem.

## Review and return evidence

Each run writes `qa/results/<run-id>/environment.json`, `results.json`,
`summary.md`, `raw/`, and `screenshots/`. macOS widget screenshots are saved
automatically. Keep the raw logs; `results.json` highlights consequential
Flutter and Impeller errors. A failed, blocked, or missing test is never passed.

Complete the manual checks in [apple_release_checklist.md](apple_release_checklist.md)
on the physical displays. In particular, inspect water refraction and repeated
taps, glass orientation and transparency at Retina scale, dissolve edges,
gallery shader effects, actual background and resume, system Reduce Motion,
and memory and frame pacing in Xcode Instruments. The integration test simulates
pause and resume; it cannot press the iPhone Home button or change system
settings.

To package a selected run, replace `RUN_ID` with its directory name:

```bash
tar -czf nib-apple-RUN_ID.tar.gz -C qa/results RUN_ID
```

Send both MacBook and iPhone archives, the completed checklist, the GitHub CI
run link, and the candidate commit SHA. Do not merge, tag, or publish until
the owner approves that exact SHA after all gates pass.
