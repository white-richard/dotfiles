#!/usr/bin/env fish

set DOTFILES_DIR (cd (status dirname); and pwd)
set CONFIG_DIR "$HOME/.config"

# Define the configs
set APPS fish nvim tmux zed

echo "Starting..."
echo "------------------------------------"

for app in $APPS
    set source_dir "$DOTFILES_DIR/$app"
    set target_dir "$CONFIG_DIR/$app"

    if not test -d "$source_dir"
        echo "Warning: Directory $source_dir does not exist. Skipping."
        continue
    end

    mkdir -p "$target_dir"

    for item in $source_dir/*
        set basename (basename "$item")
        set target_item "$target_dir/$basename"

        # If the target already exists remove it
        if test -e "$target_item" -o -L "$target_item"
            rm -rf "$target_item"
        end

        # Create new symlink
        ln -s "$item" "$target_item"
        echo "Symlinked: $basename -> $target_dir/"
    end
end

echo "------------------------------------"
echo "Dotfile'd"