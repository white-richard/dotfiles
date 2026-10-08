"""Run with: python3 -m unittest discover -s tests -p test_gpuu.py"""

import contextlib
import importlib.util
import io
import json
import multiprocessing
import os
import pwd
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "fish/functions/__gpuu.py"
spec = importlib.util.spec_from_file_location("gpuu", SCRIPT)
gpuu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpuu)


def device(index=0, users=()):
    return dict(
        index=index,
        uuid="GPU-a",
        name="Test GPU",
        processes=[
            dict(pid=100 + i, user=user, start_ticks=10 + i, memory=1024, name="job")
            for i, user in enumerate(users)
        ],
    )


def run_collector(directory):
    class FakeNVML:
        def sample(self):
            value = json.loads((directory / "input.json").read_text())
            if isinstance(value, str):
                raise RuntimeError(value)
            return value

        def close(self):
            pass

    gpuu.collect(directory, factory=FakeNVML)


class CollectorTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="gpuu-test-")
        self.directory = Path(self.temporary.name)
        self.children = []

    def tearDown(self):
        for child in self.children:
            if child.is_alive():
                child.terminate()
            child.join(timeout=4)
            if child.is_alive():
                child.kill()
                child.join()
        self.temporary.cleanup()

    def input(self, value):
        target = self.directory / "next-input.json"
        target.write_text(json.dumps(value))
        target.replace(self.directory / "input.json")

    def start(self):
        child = multiprocessing.get_context("fork").Process(
            target=run_collector, args=(self.directory,)
        )
        child.start()
        self.children.append(child)
        return child

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            state = gpuu.read_state(self.directory)
            if predicate(state):
                return state
            time.sleep(0.03)
        self.fail("Collector state did not converge: %r" % state)

    def test_background_collection_records_jobs_without_report_calls(self):
        self.input([device(users=("alice", "bob"))])
        child = self.start()
        active = self.wait_for(lambda s: "GPU-a" in s["history"])
        self.assertEqual(active["history"]["GPU-a"]["users"], ["alice", "bob"])
        self.assertTrue(gpuu.collector_running(self.directory))

        self.input([device(index=3)])
        idle = self.wait_for(
            lambda s: s["devices"] and not s["devices"][0]["processes"]
        )
        self.assertEqual(idle["devices"][0]["index"], 3)
        self.assertEqual(idle["history"]["GPU-a"]["users"], ["alice", "bob"])
        self.assertGreaterEqual(
            idle["history"]["GPU-a"]["time"], active["history"]["GPU-a"]["time"]
        )

        with contextlib.redirect_stdout(io.StringIO()) as output:
            gpuu.show(self.directory)
        self.assertIn("idle", output.getvalue())
        self.assertIn("by alice, bob", output.getvalue())
        self.assertIn("GPU 3", output.getvalue())

        child.terminate()
        child.join(timeout=4)
        stopped = gpuu.read_state(self.directory)
        self.assertTrue(stopped["stopped"])
        self.assertFalse(gpuu.collector_running(self.directory))
        self.start()
        restarted = self.wait_for(lambda s: not s.get("stopped", True))
        self.assertEqual(restarted["history"], stopped["history"])
        self.assertEqual(restarted["collection_started"], stopped["collection_started"])

    def test_root_processes_are_ignored(self):
        self.input([device(users=("root",))])
        self.start()
        idle = self.wait_for(lambda s: s["devices"])
        self.assertEqual(idle["devices"][0]["processes"], [])
        self.assertNotIn("GPU-a", idle["history"])
        self.input([device(users=("root", "alice"))])
        active = self.wait_for(lambda s: "GPU-a" in s["history"])
        self.assertEqual(active["history"]["GPU-a"]["users"], ["alice"])
        self.assertEqual(
            [p["user"] for p in active["devices"][0]["processes"]], ["alice"]
        )

    def test_query_failure_does_not_erase_history_or_report_idle(self):
        self.input([device(users=("alice",))])
        self.start()
        self.wait_for(lambda s: "GPU-a" in s["history"])
        self.input("driver unavailable")
        failed = self.wait_for(lambda s: s.get("error") == "driver unavailable")
        self.assertEqual(failed["history"]["GPU-a"]["users"], ["alice"])
        with contextlib.redirect_stdout(io.StringIO()) as output:
            gpuu.show(self.directory)
        self.assertIn("current activity unknown", output.getvalue())
        self.assertNotIn("  idle", output.getvalue())
        self.input([device(users=("bob",))])
        recovered = self.wait_for(
            lambda s: (
                s.get("error") is None
                and s["history"].get("GPU-a", {}).get("users") == ["bob"]
            )
        )
        self.assertGreater(recovered["updated"], failed["updated"])

    def test_usage_seconds_are_split_and_flushed_on_stop(self):
        self.input([device(users=("alice", "bob"))])
        child = self.start()
        self.wait_for(lambda s: s.get("usage", {}).get("gpus", {}).get("GPU-a", {}).get("observed", 0) > 0.6)
        child.terminate()
        child.join(timeout=4)
        self.assertNotIn("usage", gpuu.read_state(self.directory))
        lines = (self.directory / "usage.jsonl").read_text().splitlines()
        entry = json.loads(lines[-1])
        self.assertEqual(entry["gpu"], "GPU-a")
        self.assertAlmostEqual(entry["users"]["alice"], entry["users"]["bob"])
        self.assertAlmostEqual(entry["users"]["alice"] * 2, entry["observed"], places=3)

    def test_duplicate_collectors_exit_without_replacing_running_one(self):
        self.input([device()])
        first = self.start()
        self.wait_for(lambda s: s.get("pid") == first.pid)
        duplicate = self.start()
        duplicate.join(timeout=2)
        self.assertEqual(duplicate.exitcode, 0)
        self.assertEqual(gpuu.read_state(self.directory)["pid"], first.pid)
        self.assertTrue(first.is_alive())

    def test_corrupt_history_is_not_silently_overwritten(self):
        (self.directory / "state.json").write_text("broken")
        with self.assertRaises(RuntimeError):
            gpuu.read_state(self.directory)
        self.assertEqual((self.directory / "state.json").read_text(), "broken")

    def test_live_and_exited_process_identity(self):
        identity = gpuu.process_identity(os.getpid())
        self.assertEqual(identity["user"], pwd.getpwuid(os.getuid()).pw_name)
        self.assertGreater(identity["start_ticks"], 0)
        self.assertEqual(gpuu.process_identity(999999999)["user"], "?")


if __name__ == "__main__":
    unittest.main()
