#!/usr/bin/env python3
"""Keep selected Obsidian settings as real files in each vault."""

import argparse
import copy
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
STATE_DIR = Path.home() / "Library/Application Support/dotfiles/obsidian-sync"
LABEL = "com.dotfiles.obsidian-sync"


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(data)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def load_vaults(repo):
    for line in (repo / ".env").read_text().splitlines():
        if line.startswith("OBSIDIAN_VAULTS="):
            return [Path(p) / ".obsidian" for p in
                    line.split("=", 1)[1].strip().strip("\"'").split(":") if p]
    raise ValueError("No OBSIDIAN_VAULTS in .env")


def shared_path(relative, rules):
    parts = relative.parts
    if any(p.startswith(".") for p in parts) and relative.as_posix() != ".vimrc":
        return False
    if len(parts) == 1:
        return parts[0] in rules["shared_files"]
    if parts[0] in ("themes", "snippets"):
        return True
    if parts[0] == "plugins" and len(parts) >= 3:
        if parts[2:] == ("data.json",):
            return parts[1] in rules["shared_plugin_settings"]
        # Plugin distribution files; caches and other runtime data stay local.
        return len(parts) == 3 and parts[2] in (
            "main.js", "manifest.json", "styles.css", "default-misspellings.md",
            "pdfannots2json-darwin-arm64", "pdfannots2json-darwin-x64",
        )
    return False


def check_symlinks(root, path):
    current = path
    while True:
        if current.is_symlink():
            raise ValueError(f"Refusing symlink: {current}")
        if current == root:
            return
        current = current.parent


def read_shared(root, relative, rules):
    path = root / relative
    check_symlinks(root, path)
    before = path.stat()
    data = path.read_bytes()
    after = path.stat()
    if (before.st_mtime_ns, before.st_size) != (after.st_mtime_ns, after.st_size):
        raise ValueError(f"File is changing: {path}")
    if path.suffix == ".json":
        value = json.loads(data)
        for key in rules["local_keys"].get(relative, []):
            value.pop(key, None)
        data = json_bytes(value)
    return data


def inventory(root, rules):
    result = {}
    for path in root.rglob("*"):
        if path.is_file() and shared_path(path.relative_to(root), rules):
            relative = path.relative_to(root).as_posix()
            # An unreadable or incomplete file aborts this pass rather than
            # letting another replica overwrite an edit still being saved.
            result[relative] = read_shared(root, relative, rules)
    return result


def digest(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None


def write_shared(root, relative, data, rules, mode):
    path = root / relative
    check_symlinks(root, path)
    local_keys = rules["local_keys"].get(relative, [])
    if local_keys:
        value = json.loads(data)
        existing = json.loads(path.read_bytes()) if path.exists() else {}
        for key in local_keys:
            if key in existing:
                value[key] = existing[key]
        data = json_bytes(value)
    atomic_write(path, data)
    path.chmod(mode)


def reconcile(roots, snapshots, state, primary, rules, dry_run=False, backup_dir=None):
    previous = state.get("files", {})
    initializing = not state.get("initialized", False)
    updated = copy.deepcopy(state)
    updated.setdefault("files", {})
    updated.setdefault("conflicts", {})
    paths = sorted(set(previous).union(*(set(s) for s in snapshots)),
                   key=lambda p: (p == "community-plugins.json", p))
    for relative in paths:
        values = [s.get(relative) for s in snapshots]
        hashes = [digest(v) for v in values]
        old = previous.get(relative, {})
        if initializing:
            candidates = [i for i in [primary] + list(range(len(roots)))
                          if values[i] is not None]
            candidates = candidates[:1]
        else:
            candidates = [i for i, root in enumerate(roots)
                          if values[i] is not None and hashes[i] != old.get(str(root))]
        distinct = {hashes[i] for i in candidates}
        if len(distinct) > 1:
            signature = digest(json_bytes(hashes))
            if updated["conflicts"].get(relative) != signature:
                print(f"Conflict (left untouched): {relative}", flush=True)
            updated["conflicts"][relative] = signature
            continue
        updated["conflicts"].pop(relative, None)
        if candidates:
            source = candidates[0]
            if digest(read_shared(roots[source], relative, rules)) != hashes[source]:
                raise ValueError(f"Source changed during sync: {relative}")
            mode = (roots[source] / relative).stat().st_mode & 0o777
            for i, root in enumerate(roots):
                if hashes[i] == hashes[source]:
                    continue
                print(f"{'Would sync' if dry_run else 'Sync'}: {relative} -> {root}", flush=True)
                if not dry_run:
                    target = root / relative
                    current = read_shared(root, relative, rules) if target.exists() else None
                    if digest(current) != hashes[i]:
                        raise ValueError(f"Target changed during sync: {target}")
                    if target.exists() and backup_dir is not None:
                        backup = backup_dir / str(i) / relative
                        backup.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(target, backup)
                    write_shared(root, relative, values[source], rules, mode)
                hashes[i] = hashes[source]
        # Missing files never cause deletion in another replica.
        updated["files"][relative] = dict(zip(map(str, roots), hashes))
    updated["initialized"] = True
    return updated


def sync(repo, state_dir, dry_run=False):
    rules = json.loads((repo / "obsidian-sync.json").read_text())
    vaults = load_vaults(repo)
    roots = [repo / "obsidian"] + vaults
    # Wait for every vault rather than interpreting unavailable iCloud files
    # as removals or creating a replacement vault directory.
    for root in roots:
        if not root.is_dir():
            raise ValueError(f"Config unavailable; skipping pass: {root}")
    primary = next((i for i, p in enumerate(roots)
                    if p.parent.name == rules["primary_vault"]), None)
    if primary is None:
        raise ValueError("Primary vault is not configured")
    state_path = state_dir / "state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    snapshots = [inventory(root, rules) for root in roots]
    if not state.get("initialized") and not dry_run:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = state_dir / "backups" / stamp
        for i, root in enumerate(roots):
            shutil.copytree(root, backup / f"{i}-{root.parent.name}", symlinks=True)
        print(f"Initial backup: {backup}", flush=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_dir = state_dir / "backups" / stamp
    result = reconcile(roots, snapshots, state, primary, rules, dry_run, backup_dir)
    if not dry_run:
        atomic_write(state_path, json_bytes(result))


def install(repo, state_dir):
    state_dir.mkdir(parents=True, exist_ok=True)
    rules = json.loads((repo / "obsidian-sync.json").read_text())
    agent = Path.home() / "Library/LaunchAgents" / f"{LABEL}.plist"
    definition = {
        "Label": LABEL,
        "ProgramArguments": [sys.executable, str(repo / "scripts/obsidian_sync.py")],
        "StartInterval": rules["interval_seconds"],
        "RunAtLoad": True,
        "StandardOutPath": str(state_dir / "sync.log"),
        "StandardErrorPath": str(state_dir / "sync.log"),
        "ProcessType": "Background",
    }
    # Initialize successfully before enabling the automatic job.
    sync(repo, state_dir)
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", f"{domain}/{LABEL}"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    atomic_write(agent, plistlib.dumps(definition))
    subprocess.run(["launchctl", "bootstrap", domain, str(agent)], check=True)
    print(f"Installed: {agent}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()
    if args.dry_run and args.install:
        parser.error("--dry-run cannot be combined with --install")
    if args.status:
        path = STATE_DIR / "state.json"
        state = json.loads(path.read_text()) if path.exists() else {}
        print(f"Initialized: {state.get('initialized', False)}")
        print(f"Log: {STATE_DIR / 'sync.log'}")
        for relative in state.get("conflicts", {}):
            print(f"Conflict: {relative}")
        subprocess.run(["launchctl", "print", f"gui/{os.getuid()}/{LABEL}"],
                       stdout=subprocess.DEVNULL)
        return
    if args.dry_run:
        sync(REPO, STATE_DIR, dry_run=True)
        return
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        if args.install:
            install(REPO, STATE_DIR)
        else:
            sync(REPO, STATE_DIR)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Obsidian sync: {error}", file=sys.stderr)
        sys.exit(1)
