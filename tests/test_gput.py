"""Run with: python3 -m unittest discover -s tests -p 'test_gpu*.py'"""

import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fish/functions"))
import __gput as gput  # noqa: E402


def entry(id, hour, users, observed=3600.0, gpu="GPU-a"):
    return dict(id=id, hour=hour, gpu=gpu, index=0, name="Test GPU", observed=observed, users=users)


class ReportTest(unittest.TestCase):
    def test_load_usage_sums_restarts_and_skips_reflushed_buckets(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            lines = [entry("a", 3600, {"alice": 100.0}, 600), entry("a", 3600, {"alice": 100.0}, 600),
                     entry("b", 3600, {"bob": 50.0}, 300)]
            (directory / "usage.jsonl").write_text("".join(json.dumps(x) + "\n" for x in lines) + '{"trunc')
            state = dict(usage=dict(id="c", hour=7200, gpus={"GPU-a": entry("", 0, {"alice": 5.0}, 10)}))
            records = gput.load_usage(directory, state)
        self.assertEqual(records[(3600, "GPU-a")]["observed"], 900)
        self.assertEqual(records[(3600, "GPU-a")]["users"], {"alice": 100.0, "bob": 50.0})
        self.assertEqual(records[(7200, "GPU-a")]["users"], {"alice": 5.0})

    def test_allocate_fills_width_exactly(self):
        cells = gput.allocate([("a", 1.0), ("b", 1.0), (None, 1.0)], 10)
        self.assertEqual(sum(count for _, count in cells), 10)
        self.assertEqual(gput.allocate([(None, 0.0)], 10), [])

    def test_weeks_start_on_monday_and_focus_groups_others(self):
        now = dt.datetime(2026, 10, 7, 12).timestamp()  # A Wednesday.
        periods = gput.week_periods(2, now)
        self.assertEqual([p[0] for p in periods], [dt.date(2026, 9, 28), dt.date(2026, 10, 5)])
        hour = dt.datetime(2026, 10, 6, 9).timestamp()
        records = {(hour, "GPU-a"): dict(index=0, name="x", observed=3600.0, users={"alice": 600.0, "bob": 300.0})}
        _, totals = gput.aggregate(records, periods, {"bob"})
        self.assertEqual(totals["GPU-a"][0]["observed"], 0)
        self.assertEqual(totals["GPU-a"][1]["users"], {gput.OTHERS: 600.0, "bob": 300.0})


if __name__ == "__main__":
    unittest.main()
