"""Release guards must fail closed without publishing anything."""

import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

from verify_release import check_published, local_version, verify


PUBSPEC = "name: nib_motion\nversion: 0.3.6\n"
CHANGELOG = "## 0.3.6\n\nDocumentation update.\n\n## 0.3.5\n"
PUBLISHED = {
    "name": "nib_motion",
    "latest": {"version": "0.3.5"},
    "versions": [{"version": "0.3.0"}, {"version": "0.3.5"}],
}


class ReleaseGuardTest(unittest.TestCase):
    def test_matching_new_release(self):
        self.assertEqual(local_version(PUBSPEC, CHANGELOG, "v0.3.6"), "0.3.6")
        check_published("0.3.6", PUBLISHED)

    def test_invalid_release_identity(self):
        for tag in ("v0.3.5", "0.3.6", "v0.3.6-rc.1", "v0.3.6/extra"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                local_version(PUBSPEC, CHANGELOG, tag)
        for pubspec in (PUBSPEC.replace("nib_motion", "other"),
                        PUBSPEC + "version: 0.3.7\n",
                        PUBSPEC.replace("0.3.6", "00.3.6")):
            with self.subTest(pubspec=pubspec), self.assertRaises(ValueError):
                local_version(pubspec, CHANGELOG, "v0.3.6")
        with self.assertRaises(ValueError):
            local_version(PUBSPEC, "## 0.3.5\n", "v0.3.6")

    def test_duplicate_and_historical_releases(self):
        for version in ("0.3.5", "0.3.0", "0.3.4"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                check_published(version, PUBLISHED)

    def test_invalid_registry_response(self):
        for response in ({}, {"name": "other"},
                         {**PUBLISHED, "versions": []},
                         {**PUBLISHED, "latest": {"version": "garbage"}}):
            with self.subTest(response=response), self.assertRaises((ValueError, KeyError)):
                check_published("0.3.6", response)

    def test_network_and_parse_failures_do_not_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text(PUBSPEC)
            (root / "CHANGELOG.md").write_text(CHANGELOG)
            for error in (urllib.error.HTTPError("https://pub.dev", 404, "Not Found", {}, None),
                          urllib.error.URLError("network unavailable"),
                          TimeoutError("timed out")):
                with self.subTest(error=error), patch("urllib.request.urlopen", side_effect=error):
                    with self.assertRaises(OSError):
                        verify("v0.3.6", root)
            with patch("urllib.request.urlopen", return_value=io.BytesIO(b"invalid JSON")):
                with self.assertRaises(ValueError):
                    verify("v0.3.6", root)
            with patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps(PUBLISHED).encode())):
                self.assertEqual(verify("v0.3.6", root), "0.3.6")


if __name__ == "__main__":
    unittest.main()
