import unittest

from showcase_media import GIF, MASTER, validate_cuts


class CutValidationTest(unittest.TestCase):
    def test_reviewed_cuts_fit_real_capture(self):
        validate_cuts(MASTER, 88.8)
        validate_cuts(GIF, 88.8)
        self.assertTrue(30 <= sum(b - a for a, b in MASTER) <= 60)
        self.assertTrue(8 <= sum(b - a for a, b in GIF) <= 15)

    def test_rejects_short_capture_and_invalid_intervals(self):
        for cuts, duration in [(MASTER, 30), ([(2, 1)], 10),
                               ([(-1, 2)], 10), ([(0, 3), (2, 4)], 10)]:
            with self.assertRaises(ValueError):
                validate_cuts(cuts, duration)
