import json
import tempfile
import unittest
from pathlib import Path

from apple_runner import collect_screenshots, parse_event


class EventTests(unittest.TestCase):
    def test_missing_and_failed_outcomes_are_not_success(self):
        names, outcomes = {}, {}
        parse_event('{"type":"testStart","test":{"id":4,"name":"QA-WATER-01 sample"}}', names, outcomes)
        self.assertEqual(outcomes, {})
        parse_event('{"type":"testDone","testID":4,"result":"failure"}', names, outcomes)
        self.assertEqual(outcomes["QA-WATER-01"], "failed")
        parse_event('not json', names, outcomes)
        self.assertEqual(len(outcomes), 1)

    def test_screenshot_copied_from_app_temp(self):
        with tempfile.TemporaryDirectory(prefix="nib qa ") as tmp:
            root = Path(tmp)
            source = root / "nib-qa-water-123.png"
            source.write_bytes(b"png")
            shots = root / "shots"
            shots.mkdir()
            line = json.dumps({"type": "print", "message": f"QA-SCREENSHOT water {source}"})
            collect_screenshots(line, shots)
            self.assertEqual((shots / "water.png").read_bytes(), b"png")
            self.assertFalse(source.exists())


if __name__ == "__main__":
    unittest.main()
