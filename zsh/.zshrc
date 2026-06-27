umask 022
limit coredumpsize 0

# options
setopt EXTENDED_HISTORY share_history
setopt hist_ignore_dups hist_ignore_all_dups hist_ignore_space hist_verify
setopt hist_reduce_blanks hist_save_no_dups hist_no_store hist_expand
setopt list_packed no_beep
unsetopt bg_nice list_types
export LISTMAX=50

# PATH
export PNPM_HOME=$HOME/.local/share/pnpm
typeset -U path
path=(
    $HOME/.pixi/bin
    $HOME/.nimble/bin
    $HOME/.local/share/zig
    $(go env GOPATH)/bin
    $PNPM_HOME
    $path
)

# completion
autoload -Uz compinit && compinit

# plugins
eval "$(sheldon source)"

# nvm
export NVM_DIR=$HOME/.config/nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# fzf
source <(fzf --zsh)

# zoxide
eval "$(zoxide init zsh)"

# aliases
source $ZDOTDIR/aliases.zsh

# functions
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
