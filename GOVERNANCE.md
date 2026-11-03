# Maintaining NibMotion

O.C.C. (`@oraclevs`) maintains NibMotion. Changes enter `main` through pull
requests with passing checks and resolved review conversations. The repository
does not require a second reviewer while it has one maintainer.

The maintainer reviews compatibility, reproduction evidence, documentation and
release readiness. Contributors should discuss API changes in an issue before
implementing them. See [Contributing](CONTRIBUTING.md) and
[Support](SUPPORT.md) for the appropriate channel.

The canonical website guides live in [doc/guides](doc/guides). Their declared
package version is independent of an unreleased `pubspec.yaml` version.
Documentation-only corrections can describe the supported published API while
the repository prepares its next release.

Version tags cannot be rewritten or deleted. Publication requires the release
identity checks, CI and approval of the `pub.dev` environment. A merged pull
request is not permission to publish a package. See the
[release checklist](doc/maintainers/release.md).
