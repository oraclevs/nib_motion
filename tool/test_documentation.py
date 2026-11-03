import json
from pathlib import Path
import shutil
import tempfile
import unittest

from check_documentation import ROOT, validate


class DocumentationTest(unittest.TestCase):
    def test_all_guides(self):
        self.assertEqual(validate(), 35)

    def test_missing_guide_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / 'doc', root / 'doc')
            (root / 'doc/guides/water.md').unlink()
            with self.assertRaises(FileNotFoundError):
                validate(root)

    def test_unknown_source_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT / 'doc', root / 'doc')
            path = root / 'doc/website.json'
            data = json.loads(path.read_text())
            data['guides'].pop()
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(AssertionError, 'Unmapped'):
                validate(root)
