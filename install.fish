#!/usr/bin/env fish

argparse 'd' -- $argv
or exit 1

set DOTFILES_DIR (cd (status dirname); and pwd)
set CONFIG_DIR "$HOME/.config"

# Remote command to pull and install
set -l remote_cmd "cd ~/.dotfiles && git pull && fish install.fish"

# --- Config ---

# Configs to be symlinked
set APPS fish nvim tmux zed

# Machines to distribute to in .env as: SSH_MACHINES="machine1 machine2"
if test -f .env
    set -l machines_string (grep SSH_MACHINES .env | string replace -r '^SSH_MACHINES=["\']?' '' | string replace -r '["\']?$' '')
    set SSH_MACHINES (string split " " $machines_string)
end
# --------------

echo "Starting..."
echo "------------------------------------"

for app in $APPS
    set -l source_path "$DOTFILES_DIR/$app"
    set -l target_path "$CONFIG_DIR/$app"

    if not test -d "$target_path"
        mkdir -p "$target_path"
        echo "Created directory: $target_path"
    end

    for item in $source_path/*
        set -l basename (basename "$item")
        set -l target_item "$target_path/$basename"

        # Check if it's already a link
        if test -L "$target_item"; and [ (readlink "$target_item") = "$item" ]
            continue
        end

        # Remove existing
        # Note: This removes both files and dirs
        rm -rf "$target_item"

        # Create the symlink
        ln -s "$item" "$target_item"
        echo "Linked: $app/$basename"
    end
end

if set -q _flag_d
    for machine in $SSH_MACHINES
        echo "Sending to $machine..."
        ssh -t "$machine" "$remote_cmd"
    end
end


echo "------------------------------------"
echo "Dotfile'd"
