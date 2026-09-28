# My dotfiles

A collection of configs I've found useful.

## Install

```fish
./install.fish
```

This symlinks each config directory into `~/.config/`.

## Obsidian

On macOS, `obsidian/` is copied (not symlinked, since iCloud can't sync symlinks) into each vault listed in `.env`, separated by `:`:

```
OBSIDIAN_VAULTS="/path/to/vault1:/path/to/vault2"
```

After editing `obsidian/`, re-sync just the vaults with:

```fish
./install.fish -o
```

## Update Remote Machines

To force remote machines to pull and install changes, create a `.env` and define a list of ssh names using the `SSH_MACHINES` variable, e.g.,

```
SSH_MACHINES="user@host1 user@host2"
```

Afterwards, distribute using the `-d` flag:

```fish
./install.fish -d
```
