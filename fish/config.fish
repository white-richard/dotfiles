# Hides fish greeting
function fish_greeting
end

# Readline colors
set -g fish_color_autosuggestion 555 yellow
set -g fish_color_command 5f87d7
set -g fish_color_comment 808080
set -g fish_color_cwd 87af5f
set -g fish_color_cwd_root 5f0000
set -g fish_color_error 870000 --bold
set -g fish_color_escape af5f5f
set -g fish_color_history_current 87afd7
set -g fish_color_host 5f87af
set -g fish_color_match d7d7d7 --background=303030
set -g fish_color_normal normal
set -g fish_color_operator d7d7d7
set -g fish_color_param 5f87af
set -g fish_color_quote d7af5f
set -g fish_color_redirection normal
set -g fish_color_search_match --background=purple
set -g fish_color_status 5f0000
set -g fish_color_user 5f875f
set -g fish_color_valid_path --underline

set -g fish_color_dimmed 555
set -g fish_color_separator 999

# Git prompt status
set -g __fish_git_prompt_showdirtystate 'yes'
set -g __fish_git_prompt_showupstream auto
set -g pure_git_untracked_dirty false

# prompt (lucid)
set -g lucid_prompt_symbol_error_color red

# Status chars
set __fish_git_prompt_char_upstream_equal ''
set __fish_git_prompt_char_upstream_ahead '↑'
set __fish_git_prompt_char_upstream_behind '↓'
set __fish_git_prompt_color_branch yellow
set __fish_git_prompt_color_dirtystate 'red'
set __fish_git_prompt_color_upstream_ahead ffb90f
set __fish_git_prompt_color_upstream_behind blue

# Pager colors
set -g fish_pager_color_completion normal
set -g fish_pager_color_description 555 yellow
set -g fish_pager_color_prefix cyan
set -g fish_pager_color_progress cyan


fish_add_path "$HOME/.local/bin"

# ZVM
set -gx ZVM_INSTALL "$HOME/.zvm/self"

if test -d "$HOME/.zvm/bin"
    fish_add_path "$HOME/.zvm/bin"
end

if test -d "$ZVM_INSTALL"
    fish_add_path "$ZVM_INSTALL"
end


switch (uname)

    case Darwin
        # Homebrew
        if test -x /opt/homebrew/bin/brew
            eval (/opt/homebrew/bin/brew shellenv)
        end

        # Tailscale GUI app CLI
        if test -x /Applications/Tailscale.app/Contents/MacOS/Tailscale
            alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        end


    case Linux
        # CUDA 12.8
        if test -d /usr/local/cuda-12.8/bin
            fish_add_path /usr/local/cuda-12.8/bin
        end

        if test -d /usr/local/cuda-12.8/lib64
            set -gx LD_LIBRARY_PATH /usr/local/cuda-12.8/lib64 $LD_LIBRARY_PATH
        end
end

if test (hostname) = "ankita"
    set -gx GOROOT "$HOME/.local/go"
    set -gx GOPATH "$HOME/go"

    if test -d "$GOROOT/bin"
        fish_add_path "$GOROOT/bin"
    end

    if test -d "$GOPATH/bin"
        fish_add_path "$GOPATH/bin"
    end
end

# Go binaries
if command -q go
    set -l go_path (go env GOPATH 2>/dev/null)
    if test -n "$go_path"
        fish_add_path "$go_path/bin"
    end
end


# Node / fnm
if command -q fnm
    fnm env --use-on-cd --shell fish | source
end


# Move tmux socket location so that it's not dependent on /tmp
set -gx TMUX_TMPDIR "$HOME/.cache/tmux"
mkdir -p "$TMUX_TMPDIR"
chmod 700 "$TMUX_TMPDIR"

set -gx CUDA_DEVICE_ORDER PCI_BUS_ID

if status is-interactive
    # Vim
    fish_vi_key_bindings

    # VS Code shell integration
    if test "$TERM_PROGRAM" = "vscode"; and command -q code
        set -l vscode_shell_integration (code --locate-shell-integration-path fish 2>/dev/null)

        if test -n "$vscode_shell_integration"; and test -f "$vscode_shell_integration"
            source "$vscode_shell_integration"
        end
    end
end
