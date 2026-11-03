# Documentation delivery

Write the website's NibMotion technical guides in `doc/guides/*.md`.
`doc/website.json` lists every guide and the supported package version. The
website at https://github.com/oraclevs/nib_website owns route bindings,
playgrounds, rendering, search and deployment.

The importer accepts an immutable Git commit, reads Markdown as data, and
records every source hash. Generated Dart is checked into the website for
review, but it is never an independent authored guide. The website's source
lock and built `motion-docs-source.json` identify the exact commit and version.

## Authoring format

Each guide starts with JSON-compatible frontmatter containing `id` and
`evidence`, followed by a Markdown title and summary. Each section has a stable
`<!-- section: anchor -->` marker followed by its heading. Preserve anchors when
editing. Supported blocks are paragraphs, one fenced code block per section,
notes using `>`, lists, tables and standalone Markdown links. An API table uses
`<!-- api -->` and the Name, Type, Default and Description columns. Arbitrary
HTML, JSX and MDX execution are not supported; the importer fails on unsupported
block syntax instead of evaluating it.

Within a section, use this order: paragraphs, lists/tables/links, API table,
code, then note. This matches the Flutter and static renderers. Split a section
when an explanation needs to follow a code example; the importer rejects
out-of-order blocks instead of silently moving them.

Use relative Markdown links between canonical guides. The importer maps those
links to the existing website routes. Use HTTPS for external resources. The
website retains its existing route inventory and redirects; adding a guide
requires updating its route manifest as part of the same reviewed change.

Run `python3 tool/check_documentation.py` and the Python test suite. Website
validation additionally checks generated drift, API names, Dart examples,
search/navigation coverage, links, assets and the published implementation.

## Version policy

The guides currently describe the published 0.3.5 API even though the candidate
pubspec is 0.3.6. Documentation corrections applicable to 0.3.5 may retain that
stable target. Do not mark a new API as published because it exists on a branch.
Unreleased guides require the `next` channel and an explicitly reviewed consumer
contract; the stable deployment rejects a next-channel source or version
mismatch. Changing the stable target requires verifying the pub.dev archive,
updating the website dependency/source contract and running consumer checks.

## Automation and release boundaries

The website's single documentation-delivery workflow imports a pinned source,
builds and verifies Flutter output, and uploads the prebuilt artifact to the
existing `nib-website` project. Pull-request validation has no deployment secrets.
Only trusted workflow runs can access private build dependencies or deployment
credentials. Scheduled source checks compare content hashes before rebuilding;
no generated-content commits or cross-repository write token are required.

The website repository documents setup, preview verification and rollback.
Installing this workflow does not merge the package candidate, publish to
pub.dev or authorize a new production deployment. Those final actions remain
owner decisions.
