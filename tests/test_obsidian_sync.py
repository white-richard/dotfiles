import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "obsidian_sync", Path(__file__).resolve().parents[1] / "scripts/obsidian_sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class ObsidianSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.roots = [Path(self.temp.name) / name for name in ("repo", "Research", "other")]
        for root in self.roots:
            root.mkdir()
        self.rules = {"shared_files": ["hotkeys.json", "app.json", "community-plugins.json"],
                      "local_keys": {"app.json": ["attachmentFolderPath"]},
                      "shared_plugin_settings": ["example"]}
        self.state = {}

    def put(self, index, relative, value):
        path = self.roots[index] / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def run_sync(self, dry_run=False):
        snapshots = [sync.inventory(root, self.rules) for root in self.roots]
        result = sync.reconcile(self.roots, snapshots, self.state, 1, self.rules, dry_run)
        if not dry_run:
            self.state = result

    def test_research_bootstrap_then_edits_from_any_vault(self):
        self.put(0, "hotkeys.json", {"old": []})
        self.put(1, "hotkeys.json", {"new": []})
        self.run_sync()
        self.put(2, "hotkeys.json", {"from_other": []})
        self.run_sync()
        for root in self.roots:
            self.assertEqual(json.loads((root / "hotkeys.json").read_text()), {"from_other": []})
        self.run_sync()
        self.assertFalse(self.state["conflicts"])

    def test_conflicts_preserved_until_files_agree(self):
        self.put(1, "hotkeys.json", {})
        self.run_sync()
        self.put(0, "hotkeys.json", {"a": []})
        self.put(2, "hotkeys.json", {"b": []})
        self.run_sync()
        self.assertIn("hotkeys.json", self.state["conflicts"])
        self.assertEqual(json.loads((self.roots[1] / "hotkeys.json").read_text()), {})
        for i in range(3):
            self.put(i, "hotkeys.json", {"resolved": []})
        self.run_sync()
        self.assertFalse(self.state["conflicts"])

    def test_plugin_additions_and_no_deletion_propagation(self):
        self.run_sync()
        self.put(2, "plugins/example/manifest.json", {"id": "example"})
        self.put(2, "community-plugins.json", ["example"])
        self.run_sync()
        (self.roots[2] / "plugins/example/manifest.json").unlink()
        self.run_sync()
        self.assertTrue((self.roots[0] / "plugins/example/manifest.json").exists())
        self.assertFalse((self.roots[2] / "plugins/example/manifest.json").exists())

    def test_local_paths_and_workspaces_preserved(self):
        for i in range(3):
            self.put(i, "app.json", {"attachmentFolderPath": str(i), "vimMode": False})
            self.put(i, "workspace.json", {"local": i})
        self.run_sync()
        self.put(2, "app.json", {"attachmentFolderPath": "2", "vimMode": True})
        self.run_sync()
        for i, root in enumerate(self.roots):
            value = json.loads((root / "app.json").read_text())
            self.assertEqual(value, {"attachmentFolderPath": str(i), "vimMode": True})
            self.assertEqual(json.loads((root / "workspace.json").read_text()), {"local": i})

    def test_dry_run_does_not_write(self):
        self.put(1, "hotkeys.json", {})
        self.run_sync(dry_run=True)
        self.assertFalse((self.roots[0] / "hotkeys.json").exists())
        self.assertEqual(self.state, {})

    def test_invalid_json_aborts_pass(self):
        (self.roots[1] / "hotkeys.json").write_text("{")
        with self.assertRaises(ValueError):
            self.run_sync()
        self.assertFalse((self.roots[0] / "hotkeys.json").exists())

    def test_symlink_is_never_written_through(self):
        self.put(1, "hotkeys.json", {})
        (self.roots[0] / "hotkeys.json").symlink_to(self.roots[1] / "hotkeys.json")
        with self.assertRaises(ValueError):
            self.run_sync()

    def test_concurrent_target_edit_is_preserved(self):
        self.put(1, "hotkeys.json", {})
        self.run_sync()
        self.put(1, "hotkeys.json", {"source": []})
        snapshots = [sync.inventory(root, self.rules) for root in self.roots]
        self.put(0, "hotkeys.json", {"concurrent": []})
        with self.assertRaises(ValueError):
            sync.reconcile(self.roots, snapshots, self.state, 1, self.rules)
        self.assertEqual(json.loads((self.roots[0] / "hotkeys.json").read_text()),
                         {"concurrent": []})


if __name__ == "__main__":
    unittest.main()
