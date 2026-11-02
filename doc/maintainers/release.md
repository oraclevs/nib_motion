# Releasing NibMotion

## Candidate and published state

Checked on November 2, 2026:

- pub.dev latest: **0.3.5**, published October 30, 2026.
- Default branch: `main`, commit `166891c762f2579e470b6bb25c564b0ac95ad407`.
- Latest GitHub release and only remote version tag: **v0.3.0**, commit
  `c7efc3bee47c4378842d001decea553fbb822e1e`.
- [The baseline CI run](https://github.com/oraclevs/nib_motion/actions/runs/41074281796)
  passed on `main`.
- Proposed next release: **0.3.6**, for documentation, package presentation, and
  contributor/release tooling. It is a candidate, not a published release.

Recheck these facts before approving a release. A README change on GitHub does
not update an existing pub.dev version. Do not backfill the missing historical
tags: tag pushes can trigger publication, and pub.dev versions are immutable.

## One-time owner setup

These settings are separate from the files in this pull request:

1. In [pub.dev package administration](https://pub.dev/packages/nib_motion/admin),
   enable GitHub Actions publishing for `oraclevs/nib_motion`, with tag pattern
   `v{{version}}`. Require the GitHub environment **pub.dev**. These private
   settings must be verified by a package uploader; public metadata cannot prove
   that they are configured.
2. In GitHub **Settings > Environments**, create **pub.dev**. Add a release
   reviewer, restrict deployments to version tags, and disable administrator
   bypass if appropriate. If the owner is the only reviewer, do not enable
   prevention of self-review without adding another reviewer first. The workflow
   names this environment, but its name alone does not create an approval gate.
3. In **Settings > Rules > Rulesets**, protect `main`: require pull requests,
   successful CI, resolved conversations, and no force pushes or deletion.
   Require the check names shown by this pull request, including both Flutter
   matrix jobs, Wasm build, shader renderer tests, and release guard tests.
   Choose the review count to fit the available maintainers.
4. Create a tag ruleset for `v*`. Restrict creation to release maintainers;
   prohibit updates and deletion. Ensure the intended release owner can create
   an approved tag through the ruleset's bypass list.

At audit time there were no repository rulesets, no protection on `main`, and no
deployment environments. These remain owner setup tasks unless separately
confirmed. Private vulnerability reporting was enabled and verified during this
work; the [security page](https://github.com/oraclevs/nib_motion/security) now
offers **Report a vulnerability**. The owner should enable security-report
notifications in their GitHub watch preferences.

Issues are enabled and Discussions are disabled. Keep usage questions in issues
unless someone will maintain a discussion area. Repository topics and social
preview can be edited independently of publication.

## Validate the candidate

Use a clean checkout of the reviewed candidate. Record the commit SHA, Flutter
version, check results, and the exact release version in the pull request.
The first changelog release heading must be `## X.Y.Z` and match `pubspec.yaml`.

```bash
git fetch origin --tags
git status --short
git rev-parse HEAD
gh release list --repo oraclevs/nib_motion
python3 tool/verify_release.py v0.3.6
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
python3 -m unittest discover -s tool -p 'test_*.py'
flutter test --enable-impeller test/shaders
dart pub publish --dry-run
```

Check the dry-run file list and warnings. It must retain all library and shader
files, the license, README, and declared screenshots. Internal notes, generated
platform projects, build output, and large unused media should stay out.
Follow the current CI matrix for minimum-SDK validation.

Validate the example separately:

```bash
cd example
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter create --empty --platforms=web --project-name nib_motion_example .
flutter build web --wasm
flutter build web --wasm -t lib/demos.dart
```

Check README examples, links, image rendering, and the presentation demos. Record
any hardware or browser coverage that was not exercised. A Wasm build and shader
unit tests do not establish rendering parity across devices.

## Approval, merge, and tag

**Stop before merge, tag creation, or publication until the owner approves the
exact reviewed commit, version, and planned actions.** Publication is permanent.

The approval should name the candidate SHA, `0.3.6`, the intended merge method,
the `v0.3.6` tag, the tag-triggered pub.dev workflow, and the GitHub Release.
If merging changes the commit SHA, record the resulting release SHA and verify
that its tree matches the reviewed candidate. If conflict resolution changes the
tree, rerun affected checks and obtain approval for that updated candidate.

After approval:

1. Merge the reviewed pull request. Fetch `main` and inspect its final release
   commit and successful CI. Use that exact commit, not an unreviewed branch head.
2. Recheck pub.dev and remote tags immediately before tagging. If `0.3.6` now
   exists, stop and choose a new version through review.
3. Create an annotated `v0.3.6` tag at the approved release commit and push only
   that tag. Do not run a separate manual `dart pub publish`.
4. Watch **Publish to pub.dev**. It checks the tag, changelog, main ancestry, and
   registry version, then reruns the CI workflow. The publish job uses the
   `pub.dev` environment, checks registry state again, performs a dry run, and
   publishes once.
5. Approve the environment deployment after checking the SHA and preflight.
   Investigate any failure before retrying. If publication may have succeeded,
   check pub.dev before rerunning anything.

The workflow uses the official `dart-lang/setup-dart` action for temporary OIDC
credentials, then puts **Flutter 3.47.8** on PATH for both the final dry run and
publication. This custom sequence keeps the publishing SDK aligned with the
tested SDK. The official reusable publisher currently selects Flutter itself
without a version input. Only the publishing job receives `id-token: write`.
See [Dart's automated publishing guide](https://dart.dev/tools/pub/automated-publishing)
and [the official reusable workflow](https://github.com/dart-lang/setup-dart/blob/v1/.github/workflows/publish.yml).

## Verify publication

1. Confirm the new version at
   [pub.dev](https://pub.dev/packages/nib_motion/versions), including its archive
   and publication audit entry. Record the workflow URL and archive SHA-256.
2. Download the published archive into a temporary directory. Compare its
   package files with the approved tagged tree, including `pubspec.yaml`,
   README, license, every library file, shaders, and screenshot assets. Inspect
   differences before declaring success.
3. Create a fresh Flutter app outside the repository. Add the **hosted**
   `nib_motion: 0.3.6` dependency, without `path`, Git, or overrides. Run the
   README example, analyze it, and build it on the presentation target.
4. Inspect the README and media on both GitHub and pub.dev. Check the docs,
   install, examples, migration, and community links.
5. Create the GitHub Release using the existing `v0.3.6` tag only after publication
   is verified. Use the release notes below, updating them to match the final
   diff and checks. Confirm tag, release, pub.dev version, and source SHA agree.

## Draft release notes for 0.3.6

NibMotion's introduction now connects its declarative API with runnable examples
and guides for springs, gestures, layout, presence, scroll, and visual effects.
The README keeps compatibility and experimental features easy to find.

- Updated package description, topics, and presentation assets.
- Added contributor guidance, issue forms, a code of conduct, and private
  vulnerability reporting instructions.
- Improved documentation navigation and corrected outdated guidance.
- Added release identity checks and a full CI gate before publication.

This release does not change the animation engine or public Dart APIs. Flutter
3.29 or newer is required. Water rendering remains experimental; automated
checks do not establish browser parity or sustained GPU performance. Existing
applications need no API migration for this update.

Read the [documentation](../README.md), try the
[example app](../../example/README.md), and see the
[changelog](../../CHANGELOG.md) for the final release contents.
