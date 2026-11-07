import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "codex_status_line", Path(__file__).resolve().parents[1] / "scripts/codex_status_line.py")
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class CodexStatusLineTests(unittest.TestCase):
    def test_create_config(self):
        self.assertEqual(status.update_config("", ["model"]),
                         '[tui]\nstatus_line = ["model"]\n')

    def test_replace_multiline_preserving_local_settings(self):
        prefix = 'model = "local-model"\n[projects."/machine/path"]\ntrust_level = "trusted"\n[tui]\nvim_mode_default = true\n'
        suffix = 'screen_reader_detection_done = true\n[tui.model_availability_nux]\nexample = 4\n'
        original = prefix + 'status_line = [\n  "reasoning",\n  "model",\n]\n' + suffix
        updated = status.update_config(original, ["model"])
        self.assertEqual(updated, prefix + 'status_line = ["model"]\n' + suffix)
        self.assertEqual(status.update_config(updated, ["model"]), updated)

    def test_add_missing_setting_before_nested_table(self):
        original = '[tui] # preferences\nvim_mode_default = true\n[tui.other]\nstatus_line = ["local"]\n'
        self.assertEqual(status.update_config(original, []), original.replace(
            '[tui] # preferences\n', '[tui] # preferences\nstatus_line = []\n'))

    def test_add_missing_table_and_final_newline(self):
        original = 'model = "local"'
        self.assertEqual(status.update_config(original, ["model"]),
                         original + '\n\n[tui]\nstatus_line = ["model"]\n')
        self.assertEqual(status.update_config('[tui]', []), '[tui]\nstatus_line = []\n')

    def test_inline_array_and_comment(self):
        self.assertEqual(status.update_config('[tui]\nstatus_line = ["old"] # fields\n', []),
                         '[tui]\nstatus_line = []\n')

    def test_unexpected_value_fails_without_duplicate_key(self):
        with self.assertRaises(ValueError):
            status.update_config('[tui]\nstatus_line = "unexpected"\n', [])


if __name__ == "__main__":
    unittest.main()
