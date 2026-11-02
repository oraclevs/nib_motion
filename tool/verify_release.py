"""Reject mismatched, duplicate, or stale releases before pub.dev publication."""

import json
from pathlib import Path
import re
import sys
import urllib.request


VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def local_version(pubspec, changelog, tag):
    # shortcut: release metadata uses plain top-level scalars; use YAML if that changes.
    names = re.findall(r"(?m)^name: ([a-z][a-z0-9_]*)\s*$", pubspec)
    versions = re.findall(r"(?m)^version: (\S+)\s*$", pubspec)
    if names != ["nib_motion"] or len(versions) != 1:
        raise ValueError("Expected one nib_motion name and version in pubspec.yaml")
    version = versions[0]
    if not re.fullmatch(VERSION, version) or tag != f"v{version}":
        raise ValueError("Tag must exactly match the stable pubspec version: vX.Y.Z")
    headings = re.findall(r"(?m)^## (.+)$", changelog)
    if not headings or headings[0] != version:
        raise ValueError("The first CHANGELOG.md release heading must match the version")
    return version


def check_published(version, package):
    if package.get("name") != "nib_motion":
        raise ValueError("Unexpected pub.dev package response")
    latest = package["latest"]["version"]
    versions = [entry["version"] for entry in package["versions"]]
    if (not re.fullmatch(VERSION, latest) or latest not in versions
            or any(not isinstance(v, str) or not v for v in versions)):
        raise ValueError("Invalid pub.dev version response")
    if version in versions:
        raise ValueError(f"nib_motion {version} is already published")
    if tuple(map(int, version.split("."))) <= tuple(map(int, latest.split("."))):
        raise ValueError(f"Release {version} must be newer than published {latest}")


def verify(tag, root):
    version = local_version(
        (root / "pubspec.yaml").read_text(),
        (root / "CHANGELOG.md").read_text(), tag,
    )
    with urllib.request.urlopen(
        "https://pub.dev/api/packages/nib_motion", timeout=30
    ) as response:
        check_published(version, json.load(response))
    return version


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: python3 tool/verify_release.py vX.Y.Z")
        version = verify(sys.argv[1], Path(__file__).resolve().parent.parent)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print(f"Release preflight failed: {error}", file=sys.stderr)
        return 1
    print(f"Release identity verified: nib_motion {version} is not published")
    return 0


if __name__ == "__main__":
    sys.exit(main())
