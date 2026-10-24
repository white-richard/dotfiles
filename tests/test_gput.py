"""Run with: python3 -m unittest discover -s tests -p 'test_gpu*.py'"""

import datetime as dt
import contextlib
import io
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

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

    def test_hourly_periods_include_current_partial_hour(self):
        now = dt.datetime(2026, 10, 7, 12, 30).timestamp()
        periods = gput.hour_periods(dt.date(2026, 10, 7), now)
        self.assertEqual(len(periods), 13)
        self.assertEqual(periods[0][0].hour, 0)
        self.assertEqual(periods[-1][0].hour, 12)
        self.assertEqual(periods[-1][2] - periods[-1][1], 1800)

    def test_hourly_chart_preserves_missing_hours_and_user_filter(self):
        day = dt.date(2026, 10, 6)
        periods = gput.hour_periods(day, dt.datetime(2026, 10, 7, 12).timestamp())
        hour = dt.datetime(2026, 10, 6, 9).timestamp()
        records = {(hour, "GPU-a"): dict(index=0, name="x", observed=3600.0,
                                        users={"alice": 1800.0, "bob": 900.0})}
        gpus, totals = gput.aggregate(records, periods, {"bob"})
        self.assertEqual(len(totals["GPU-a"]), 24)
        self.assertEqual(totals["GPU-a"][9]["users"], {gput.OTHERS: 1800.0, "bob": 900.0})
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            gput.render_hourly(gput.Painter({"bob", gput.OTHERS}, False),
                               gpus, totals, periods, 10, day)
        lines = output.getvalue().splitlines()
        self.assertIn("2026-10-06", lines[0])
        self.assertIn("no data", next(line for line in lines if "08:00" in line))
        self.assertIn("75% used", next(line for line in lines if "09:00" in line))

    @unittest.skipUnless(hasattr(time, "tzset"), "requires tzset")
    def test_hourly_periods_follow_daylight_saving_transitions(self):
        try:
            with mock.patch.dict(os.environ, TZ="America/Los_Angeles"):
                time.tzset()
                now = dt.datetime(2026, 11, 3).timestamp()
                spring = gput.hour_periods(dt.date(2026, 3, 8), now)
                fall = gput.hour_periods(dt.date(2026, 11, 1), now)
                self.assertEqual(len(spring), 23)
                self.assertNotIn(2, [local.hour for local, _, _ in spring])
                self.assertEqual(len(fall), 25)
                labels = [local.astimezone().strftime("%H:%M %z") for local, _, _ in fall]
                self.assertIn("01:00 -0700", labels)
                self.assertIn("01:00 -0800", labels)
        finally:
            time.tzset()


if __name__ == "__main__":
    unittest.main()
