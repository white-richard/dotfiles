#!/usr/bin/env fish

argparse 'd' -- $argv
or exit 1

set DOTFILES_DIR (cd (status dirname); and pwd)
set CONFIG_DIR "$HOME/.config"

# Remote command to pull and install
set -l remote_cmd "cd ~/.dotfiles && git pull && fish install.fish"

# --- Config ---

# Configs to be symlinked
set APPS fish nvim tmux zed git ruff ghostty Code

# Obsidian vaults (mac only) to link customization files into.
if test -f .env
    set -l machines_string (grep SSH_MACHINES .env | string replace -r '^SSH_MACHINES=["\']?' '' | string replace -r '["\']?$' '')
    set SSH_MACHINES (string split " " $machines_string)

    set -l vaults_string (grep OBSIDIAN_VAULTS .env | string replace -r '^OBSIDIAN_VAULTS=["\']?' '' | string replace -r '["\']?$' '')
    if test -n "$vaults_string"
        set OBSIDIAN_VAULTS (string split ":" $vaults_string)
    end
end
# --------------

echo "Starting..."
echo "------------------------------------"

# Create bashrc symlink
rm "$HOME/.bashrc"
ln -s "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

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

if test (uname) = Darwin; and set -q OBSIDIAN_VAULTS[1]
    set -l obsidian_source "$DOTFILES_DIR/obsidian"

    for vault in $OBSIDIAN_VAULTS
        if not test -d "$vault"
            echo "Skipping missing vault: $vault"
            continue
        end

        set -l vault_config "$vault/.obsidian"
        if not test -d "$vault_config"
            mkdir -p "$vault_config"
            echo "Created directory: $vault_config"
        end

        for item in $obsidian_source/* $obsidian_source/.vimrc
            set -l basename (basename "$item")
            set -l target_item "$vault_config/$basename"

            if test -L "$target_item"; and [ (readlink "$target_item") = "$item" ]
                continue
            end

            # Remove existing (file or dir) and relink
            rm -rf "$target_item"
            ln -s "$item" "$target_item"
            echo "Linked: obsidian/$basename -> $vault"
        end
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
