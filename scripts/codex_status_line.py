#!/usr/bin/env python3
"""Apply the shared status bar without replacing machine-local Codex settings."""

import json
import os
from pathlib import Path
import re


REPO = Path(__file__).resolve().parents[1]


def update_config(text, items):
    # JSON string arrays are also valid TOML arrays.
    setting = "status_line = " + json.dumps(items) + "\n"
    tui = re.search(r"(?m)^[ \t]*\[tui\][ \t]*(?:#[^\n]*)?\n?", text)
    if tui is None:
        separator = ("\n" if text.endswith("\n") else "\n\n") if text else ""
        return text + separator + "[tui]\n" + setting

    start = tui.end()
    # Array entries can also start with '['; stop only at a table header.
    next_table = re.search(r"(?m)^[ \t]*\[\[?[^\n]+\][ \t]*(?:#[^\n]*)?$", text[start:])
    end = start + next_table.start() if next_table else len(text)
    body = text[start:end]
    array = re.compile(r"(?m)^[ \t]*status_line[ \t]*=[ \t]*\[[^\]]*\][ \t]*(?:#[^\n]*)?(?:\n|$)")
    if array.search(body):
        body = array.sub(lambda match: setting, body, count=1)
    elif re.search(r"(?m)^[ \t]*status_line[ \t]*=", body):
        raise ValueError("Expected tui.status_line to be an array; config left untouched")
    else:
        body = setting + body
    prefix = text[:start]
    if not prefix.endswith("\n"):
        prefix += "\n"
    return prefix + body + text[end:]


def main():
    items = json.loads((REPO / "codex/status-line.json").read_text())
    if not isinstance(items, list) or not all(isinstance(item, str) for item in items):
        raise ValueError("codex/status-line.json must contain an array of strings")
    config = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "config.toml"
    original = config.read_text() if config.exists() else ""
    updated = update_config(original, items)
    if updated != original:
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(updated)
        print("Updated: codex/status_line")


if __name__ == "__main__":
    main()
