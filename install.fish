#!/usr/bin/env fish

argparse 'd' 'o' -- $argv
or exit 1

set DOTFILES_DIR (cd (status dirname); and pwd)
set CONFIG_DIR "$HOME/.config"

# Remote command to pull and install
set -l remote_cmd "cd ~/.dotfiles && git pull && fish install.fish"

# --- Config ---

# Configs to be symlinked
set APPS fish nvim tmux zed git ruff stylua ghostty Code lazygit

# Claude Code reads from ~/.claude rather than ~/.config
set CLAUDE_DIR "$HOME/.claude"

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

# Install automatic syncing with real files for iCloud.
function sync_obsidian
    python3 "$DOTFILES_DIR/scripts/obsidian_sync.py" --install
end

if set -q _flag_o
    if not set -q OBSIDIAN_VAULTS[1]
        echo "No OBSIDIAN_VAULTS in .env"
        exit 1
    end
    sync_obsidian; or exit 1
    exit
end

echo "Starting..."
echo "------------------------------------"

# Create bashrc symlink
rm "$HOME/.bashrc"
ln -s "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

# Symlink each item of a dotfiles dir into a target dir
# Extra args are item names to skip
function link_items --argument-names source_path target_path label
    if not test -d "$target_path"
        mkdir -p "$target_path"
        echo "Created directory: $target_path"
    end

    for item in $source_path/*
        set -l basename (basename "$item")
        set -l target_item "$target_path/$basename"

        if contains -- $basename $argv[4..]
            continue
        end

        # Check if it's already a link
        if test -L "$target_item"; and [ (readlink "$target_item") = "$item" ]
            continue
        end

        # Remove existing
        # Note: This removes both files and dirs
        rm -rf "$target_item"

        # Create the symlink
        ln -s "$item" "$target_item"
        echo "Linked: $label/$basename"
    end
end

for app in $APPS
    link_items "$DOTFILES_DIR/$app" "$CONFIG_DIR/$app" $app
end

# Link skills individually since Claude Code keeps its own dirs in ~/.claude/skills
link_items "$DOTFILES_DIR/claude" "$CLAUDE_DIR" claude skills
link_items "$DOTFILES_DIR/claude/skills" "$CLAUDE_DIR/skills" claude/skills

# Expose the formatter binaries that nvim and Zed share
set -l MASON_BIN "$HOME/.local/share/nvim/mason/bin"
set -l LOCAL_BIN "$HOME/.local/bin"
set -l SHARED_TOOLS shfmt stylua prettier ruff

if test -d "$MASON_BIN"
    mkdir -p "$LOCAL_BIN"

    for tool in $SHARED_TOOLS
        set -l src "$MASON_BIN/$tool"
        set -l dst "$LOCAL_BIN/$tool"

        if not test -x "$src"
            echo "Skipped: $tool (not installed by Mason)"
            continue
        end

        if test -L "$dst"; and [ (readlink "$dst") = "$src" ]
            continue
        end

        # Never clobber a real binary someone put here deliberately.
        if test -e "$dst"; and not test -L "$dst"
            echo "Skipped: $tool ($dst exists and is not a symlink)"
            continue
        end

        rm -f "$dst"
        ln -s "$src" "$dst"
        echo "Linked: $tool -> mason"
    end
else
    echo "Skipped: formatter links (no Mason install found)"
end

if test (uname) = Darwin # MacOS
    # Disable the press-and-hold popup for VS Code
    defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    echo "Set: VS Code ApplePressAndHoldEnabled = false"
end

if test (uname) = Darwin; and set -q OBSIDIAN_VAULTS[1]
    sync_obsidian
end

if set -q _flag_d
    for machine in $SSH_MACHINES
        echo "Sending to $machine..."
        ssh -t "$machine" "$remote_cmd"
    end
end


echo "------------------------------------"
echo "Dotfile'd"
