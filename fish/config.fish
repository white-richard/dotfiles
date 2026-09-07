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

# Status Chars
#set __fish_git_prompt_char_dirtystate '*'
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


# # begin gd completion
# gd --completion-fish | source
# # end gd completion

# ZVM
set -gx ZVM_INSTALL "$HOME/.zvm/self"
set -gx PATH $PATH "$HOME/.zvm/bin"
set -gx PATH $PATH "$ZVM_INSTALL/"

set -gx PATH /usr/local/cuda-12.8/bin $PATH
set -gx LD_LIBRARY_PATH /usr/local/cuda-12.8/lib64 $LD_LIBRARY_PATH

# Only load Go paths if the hostname is 'ankita'
if test (hostname) = "ankita"
    set -gx GOROOT $HOME/.local/go
    set -gx GOPATH $HOME/go
    fish_add_path $GOROOT/bin $GOPATH/bin
end
set -Ua fish_user_paths (go env GOPATH)/bin

if status is-interactive
    # Commands to run in interactive sessions can go here

    # Vim keybindings
    fish_vi_key_bindings

    # Bandaid fix for tailscale on mac
    if test (uname) = "Darwin"
        alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    end

    string match -q "$TERM_PROGRAM" "vscode"
    and . (code --locate-shell-integration-path fish)

end
set -gx CUDA_DEVICE_ORDER PCI_BUS_ID


# Added by Antigravity CLI installer
set -gx PATH "/home/richw/.local/bin" $PATH


# Added by Antigravity CLI installer
set -gx PATH "/Users/richiewhite/.local/bin" $PATH

# fnm as node manager in fishshell
fnm env --use-on-cd --shell fish | source

# Move tmux socket location so that it's not dependent on /tmp 
set -gx TMUX_TMPDIR "$HOME/.cache/tmux"

eval "$(/opt/homebrew/bin/brew shellenv fish)"
