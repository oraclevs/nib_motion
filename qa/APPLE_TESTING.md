# Run the NibMotion 0.3.7 Apple checks on a new Mac

You need a MacBook, internet access, Xcode, Python 3, and a cable for the
iPhone. No separate task runner is needed. The checked-in `qa/apple_runner.py`
runs the tests and writes the reports. Use the exact
candidate SHA supplied with the handoff; a branch name alone can move.

## 1. Set up Xcode and Flutter once

Install Xcode from the App Store and open it once. Run this single command in
Terminal and wait for it to finish:

```sh
sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch'
```

Then read and accept the Xcode license interactively:

```sh
sudo xcodebuild -license
```

Check the available tools:

```sh
python3 --version
xcodebuild -version
```

If Python 3 is missing, install it before continuing. Flutter's
[macOS setup](https://docs.flutter.dev/platform-integration/macos/setup)
and [iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) cover
Xcode problems.

Install the same Flutter version used by CI, then keep this Terminal window
open. If you already have Flutter 3.50.0, skip the clone and set `PATH` to that
SDK instead.

```sh
mkdir -p "$HOME/develop"
git clone --depth 1 --branch 3.50.0 https://github.com/flutter/flutter.git "$HOME/develop/flutter-3.50.0"
export PATH="$HOME/develop/flutter-3.50.0/bin:$PATH"
flutter --version
dart --version
flutter doctor -v
flutter config --enable-macos-desktop
```

`flutter --version` must show 3.50.0 and Dart 3.14.0. If you open a new
Terminal window later, run the `export PATH=...` line again. Resolve Flutter
or Xcode errors in `flutter doctor -v`; unrelated Android or browser warnings
do not block these Apple checks.

## 2. Clone and pin the candidate

Replace `PASTE_CANDIDATE_SHA_HERE` with the full SHA from the handoff. Run:

```sh
mkdir -p "$HOME/Projects"
cd "$HOME/Projects"
git clone --branch fix/metal-compat-0.3.7 --single-branch https://github.com/oraclevs/nib_motion.git nib_motion-0.3.7
cd nib_motion-0.3.7
git switch --detach PASTE_CANDIDATE_SHA_HERE
git rev-parse HEAD
git status --short
flutter devices
```

`git rev-parse HEAD` must print the supplied SHA exactly. `git status --short`
must print nothing. `flutter devices` must list `macOS`. Keep this checkout for
both runs; the native `example/macos` and `example/ios` projects are generated
locally and ignored by Git.

## 3. Run the MacBook test

From the repository root (`nib_motion-0.3.7`):

```sh
python3 qa/apple_runner.py macos
cat "$(find qa/results -name summary.md | sort | tail -n 1)"
```

The first command builds the macOS example, checks generated Metal shader
bindings, runs eight integration cases, and prints the path to its report. It
can take several minutes on a new Mac. `Exit: 0` means the automated checks
passed. The `Overall` column stays `not_run` for cases requiring manual review;
record those results on the separate checklist. Raw logs, `environment.json`,
and `results.json` are beside `summary.md` in that run's
`qa/results/<run-id>/` folder. A successful Mac run also contains three PNGs.

Before preparing the iPhone project, restore any tracked example files that
Flutter's scaffold generator updated. This is safe in the clean candidate
checkout and leaves the ignored native projects and reports in place:

```sh
git restore -- example
git status --short
```

The status command must again print nothing.

## 4. Run the physical iPhone test

Connect and unlock the iPhone with a cable. Tap **Trust This Computer**. On the
phone, enable **Settings > Privacy & Security > Developer Mode** and restart if
prompted. Download Xcode's iOS platform support; this can take a while:

```sh
xcodebuild -downloadPlatform iOS
```

Then, in Terminal at the repository root, run:

```sh
xcrun devicectl list devices
flutter devices
flutter create --no-pub --empty --platforms=ios --project-name nib_motion_example example
git restore -- example
open example/ios/Runner.xcworkspace
```

In Xcode, add your Apple ID under **Xcode > Settings > Accounts** if needed.
Select the **Runner** target, open **Signing & Capabilities**, enable automatic
signing, choose your development team, and let Xcode create an Apple Development
certificate. Use a unique bundle identifier if Xcode asks. A free personal
developer account works for device testing. Save the project, then copy the
physical iPhone ID shown by `flutter devices` and run:

```sh
python3 qa/apple_runner.py ios --device YOUR_IPHONE_DEVICE_ID
cat "$(find qa/results -name summary.md | sort | tail -n 1)"
```

The runner refuses a simulator and reports missing signing or device setup as
`blocked`. If iOS reports `Exit: 0`, all eight automated cases passed on that
phone. The iPhone's sandbox does not export the three PNGs automatically.

## 5. Review and send the evidence

Read [apple_release_checklist.md](apple_release_checklist.md) and inspect the
effects on the actual MacBook and iPhone displays. The automated lifecycle test
simulates pause/resume; manually background and reopen the app as well. To open
the gallery for visual checks on the phone, run this from the repository root,
replacing the device ID:

```sh
cd example
flutter run -d YOUR_IPHONE_DEVICE_ID -t lib/demos.dart
```

Press `Ctrl+C` after the visual review, then `cd ..` to return to the
repository root. Save iPhone screenshots manually. Review water refraction and
repeated taps, glass orientation and transparency, dissolve edges, reduced
motion, and frame pacing. The checklist has the remaining items.

Each run has its own folder under `qa/results/`. To archive one, replace
`RUN_ID` with that folder's name:

```sh
tar -czf "$HOME/Desktop/nib-apple-RUN_ID.tar.gz" -C qa/results RUN_ID
```

Send both the MacBook and iPhone archives, the completed checklist, and the
candidate SHA. The reports preserve raw errors and mark missing or failed
tests explicitly. Keep the PR unmerged; tagging and publishing require owner
approval of that exact SHA after the physical review.
