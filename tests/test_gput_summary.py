import contextlib
import datetime as dt
import io
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'fish/functions'))
import __gput as gput


class SummaryTest(unittest.TestCase):
    def test_recent_days_are_calendar_days_and_end_now(self):
        now = dt.datetime(2026, 11, 11, 12, 30).timestamp()
        periods = gput.recent_day_periods(3, now)
        self.assertEqual([p[0].day for p in periods], [9, 10, 11])
        self.assertEqual(periods[-1][2], now)

    def report(self, arguments):
        now = dt.datetime(2026, 11, 11, 12, 30).timestamp()
        hour = dt.datetime(2026, 11, 11, 9).timestamp()
        records = {
            (hour, 'a'): dict(index=0, name='Test GPU', observed=3600., users={'alice': 1800.}),
            (hour + 3600, 'a'): dict(index=0, name='Test GPU', observed=3600., users={'alice': 900., 'bob': 900.}),
            (hour + 7200, 'a'): dict(index=0, name='Test GPU', observed=3600., users={}),
            (hour - 86400, 'a'): dict(index=0, name='Test GPU', observed=3600., users={'bob': 3600.}),
        }
        output = io.StringIO()
        with (mock.patch.object(sys, 'argv', [',gput', *arguments]),
              mock.patch.object(gput.time, 'time', return_value=now),
              mock.patch.object(gput.gpuu, 'cache_directory'),
              mock.patch.object(gput.gpuu, 'ensure_running'),
              mock.patch.object(gput.gpuu, 'read_state', return_value={}),
              mock.patch.object(gput.gpuu, 'collector_running', return_value=False),
              mock.patch.object(gput, 'load_usage', return_value=records),
              contextlib.redirect_stdout(output)):
            self.assertEqual(gput.main(), 0)
        return output.getvalue()

    def test_default_today_has_totals_users_and_hour_windows(self):
        output = self.report([])
        self.assertIn('2026-11-11', output)
        self.assertNotIn('2026-11-10', output)
        self.assertIn('1.0 GPU-h  33% used  24% recorded', output)
        self.assertIn('alice', output)
        self.assertIn('0.8h', output)
        self.assertIn('bob', output)
        self.assertIn('0.2h', output)
        self.assertIn('00', output)
        self.assertIn('12', output)
        self.assertIn('░', output)
        self.assertIn('·', output)
        self.assertIn('?', output)
        self.assertNotIn('Used hours:', output)
        self.assertLessEqual(len(output.splitlines()), 10)

    def test_days_and_filter_keep_overall_totals(self):
        output = self.report(['2', '--user', 'alice'])
        self.assertIn('2026-11-10', output)
        self.assertIn('2.0 GPU-h  50% used', output)
        self.assertIn('alice', output)
        self.assertIn('0.8h', output)
        self.assertNotIn('bob', output)

    def test_timeline_distinguishes_unknown_idle_active_and_future(self):
        slots = [(None, h * 3600, (h + 1) * 3600) for h in range(5)]
        rows = [dict(observed=0, users={}), dict(observed=3600, users={}),
                dict(observed=3600, users={'alice': 3600}),
                dict(observed=1800, users={'alice': 450}), dict(observed=0, users={})]
        painter = gput.Painter({'alice'}, False)
        self.assertEqual(gput.timeline(painter, rows, slots, 4 * 3600, 'alice', 1), '?·█▒ ')
        self.assertEqual(gput.timeline(painter, rows, slots, 4 * 3600, None, 2), '??··██▒▒  ')

    def test_only_people_have_timelines_and_idle_gpus_are_hidden(self):
        hour = dt.datetime(2026, 11, 11, 9).timestamp()
        records = {
            (hour, 'active'): dict(index=4, name='GPU', observed=3600., users={'alice': 1800.}),
            (hour, 'idle'): dict(index=5, name='GPU', observed=3600., users={}),
        }
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            gput.render_report(records, gput.recent_day_periods(1, hour + 3600), set(), [], True)
        lines = output.getvalue().splitlines()
        heading = next(line for line in lines if line.startswith('GPU 4'))
        self.assertNotIn('│', heading)
        self.assertIn('0.5h', heading)
        self.assertIn('50%', heading)
        self.assertNotIn('GPU 5', output.getvalue())
        timelines = [line for line in lines if '│' in line]
        self.assertEqual(len(timelines), 1)
        self.assertIn('alice', timelines[0])
        # Hidden idle GPUs must still count toward overall observed capacity.
        self.assertIn('0.5 GPU-h  25% used', output.getvalue())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            gput.render_report(records, gput.recent_day_periods(1, hour + 3600), {'bob'}, [], True)
        self.assertNotIn('GPU 4', output.getvalue())

    def test_every_hour_is_labeled_and_aligned_at_different_widths(self):
        for width, cells in [(60, 1), (80, 2), (120, 3)]:
            with mock.patch.object(gput.shutil, 'get_terminal_size', return_value=os.terminal_size((width, 24))):
                output = self.report([])
            axes = [line for line in output.splitlines()
                    if line.startswith(' ' * 11) and line.strip().replace(' ', '').isdigit()]
            self.assertTrue(axes)
            for hour in range(24):
                column = 11 + hour * cells
                self.assertTrue(any(line[column:column + 2] == '%02d' % hour for line in axes),
                                (width, hour, axes))

    def test_invalid_days_fail_before_collector_access(self):
        for arguments in [['0'], ['-2'], ['2', '--days', '3'], ['2', '--avg']]:
            with (mock.patch.object(sys, 'argv', [',gput', *arguments]),
                  mock.patch.object(gput.gpuu, 'cache_directory') as cache,
                  contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit)):
                gput.main()
            cache.assert_not_called()

    def test_days_alias(self):
        self.assertEqual(self.report(['--days', '2']), self.report(['2']))

    def test_no_observations_in_window(self):
        with mock.patch.object(gput, 'load_usage', return_value={}):
            # Exercise the renderer directly; historical GPU metadata is not evidence of coverage.
            output = io.StringIO()
            now = dt.datetime(2026, 11, 12, 12).timestamp()
            records = {(0, 'a'): dict(index=0, name='GPU', observed=3600., users={'alice': 1.})}
            with contextlib.redirect_stdout(output):
                gput.render_report(records, gput.recent_day_periods(1, now), set(), [])
            self.assertIn('No usage recorded', output.getvalue())


if __name__ == '__main__':
    unittest.main()
