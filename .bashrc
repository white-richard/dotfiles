# ~/.bashrc

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

. "$HOME/.local/bin/env"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export CUDA_DEVICE_ORDER="PCI_BUS_ID"

# Load Go paths; only if the hostname is 'ankita'
if [ "$(hostname)" = "ankita" ]; then
    export GOROOT=$HOME/.local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
fi
export PATH=$PATH:$(go env GOPATH)/bin

# Antigravity CLI
export PATH="/home/richw/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/Users/richiewhite/.local/bin:$PATH"
