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

export BASH_SILENCE_DEPRECATION_WARNING=1

# Auto-launch fish
if [[ $- == *i* ]]; then
    if [ -z "$INSIDE_FISH" ]; then
        parent=$(ps -o comm= -p $PPID 2>/dev/null)
        if [[ "$parent" != *fish* ]]; then
            exec fish
        fi
    fi
fi

export PATH=/usr/local/cuda-12.8/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH
