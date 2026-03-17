#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"

# Cargo
. "$HOME/.cargo/env"

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# Auto-launch fish
if [[ $- == *i* ]] && [[ $- != *c* ]]; then
    if [ -z "$INSIDE_FISH" ]; then
        exec fish
    fi
fi
