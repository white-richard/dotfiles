# My dotfiles

A collection of configs I've found useful.

## Install

```fish
./install.fish
```

This symlinks each config directory into `~/.config/`.

## Obsidian

On macOS, a LaunchAgent syncs selected settings between `obsidian/` and each vault
listed in `.env` every 15 seconds. Vaults contain real files for iCloud:

```
OBSIDIAN_VAULTS="/path/to/vault1:/path/to/vault2"
```

Install or update the service:

```fish
./install.fish -o
```

Research supplies the initial shared settings. Later edits in any vault or the
repo propagate automatically. Conflicting edits stay untouched; deletions never
propagate. Remove a plugin from each vault explicitly when you want it gone.

`obsidian-sync.json` selects shared files and plugin settings. Workspaces,
bookmarks, template/daily-note paths, attachment paths, and unlisted plugin data
stay local. Add plugin distribution files to `shared_path` if a plugin needs
extra assets beyond `main.js`, `manifest.json`, and `styles.css`.

```sh
python3 scripts/obsidian_sync.py --dry-run
python3 scripts/obsidian_sync.py --status
```

Backups, conflict state, and `sync.log` live in
`~/Library/Application Support/dotfiles/obsidian-sync/`. To resolve a conflict,
make the shared file identical in all vaults and the repo. The Mac must be awake
for cross-vault syncing. Git commits remain manual.

## Update Remote Machines

To force remote machines to pull and install changes, create a `.env` and define a list of ssh names using the `SSH_MACHINES` variable, e.g.,

```
SSH_MACHINES="user@host1 user@host2"
```

Afterwards, distribute using the `-d` flag:

```fish
./install.fish -d
```
