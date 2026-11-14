import unittest

from apple_runner import parse_event


class EventTests(unittest.TestCase):
    def test_missing_and_failed_outcomes_are_not_success(self):
        names, outcomes = {}, {}
        parse_event('{"type":"testStart","test":{"id":4,"name":"QA-WATER-01 sample"}}', names, outcomes)
        self.assertEqual(outcomes, {})
        parse_event('{"type":"testDone","testID":4,"result":"failure"}', names, outcomes)
        self.assertEqual(outcomes["QA-WATER-01"], "failed")
        parse_event('not json', names, outcomes)
        self.assertEqual(len(outcomes), 1)


if __name__ == "__main__":
    unittest.main()
