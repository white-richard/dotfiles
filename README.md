# My dotfiles

A collection of configs I've found useful.

## Install

```fish
./install.fish
```

This symlinks each config directory into `~/.config/`.

To also push to all SSH machines defined in `.env`:

```fish
./install.fish -d
```

## Remote machines

Add a `SSH_MACHINES` variable to `.env`:

```
SSH_MACHINES="user@host1 user@host2"
```
