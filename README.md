# My dotfiles

A collection of configs I've found useful.

## Install

```fish
./install.fish
```

This symlinks each config directory into `~/.config/`.

## Update Remote Machines

To force remote machines to pull and install changes, create a `.env` and define a list of ssh names using the `SSH_MACHINES` variable, e.g.,

```
SSH_MACHINES="user@host1 user@host2"
```

Afterwards, distribute using the `-d` flag:

```fish
./install.fish -d
```
