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
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Local bin
export PATH="$HOME/.local/bin:$PATH"

export BASH_SILENCE_DEPRECATION_WARNING=1

# Auto-launch fish
if [[ $- == *i* ]] && [ -t 0 ] && [ -t 1 ]; then
    if [ -z "$INSIDE_FISH" ]; then
        parent=$(ps -o comm= -p $PPID 2>/dev/null)
        if [[ "$parent" != *fish* ]]; then
            exec fish
        fi
    fi
fi

export PATH=/usr/local/cuda-12.8/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

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

    export GPU_0_1=MIG-e1ff7c6c-30f0-5e19-a37c-6832cce8b050
    export GPU_0_2=MIG-904c8af2-f525-5638-9571-bcc6be654ee6
    export GPU_5_1=MIG-43688515-87d9-5bf1-97d7-a0c6c2471e19
    export GPU_5_2=MIG-8672e368-8ce8-5ade-8824-5c315cfb7fa7
fi
if [ "$(hostname)" = "wpeb-436-19l" ]; then
    export PATH=$PATH:/usr/local/go/bin
fi

# Antigravity CLI
export PATH="/home/richw/.local/bin:$PATH"

# Added by Antigravity CLI installer
export PATH="/Users/richiewhite/.local/bin:$PATH"

# Move tmux socket location so that it's not dependent on /tmp
export TMUX_TMPDIR="$HOME/.cache/tmux"
mkdir -p "$TMUX_TMPDIR"
chmod 700 "$TMUX_TMPDIR"

# FNM for node
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi
