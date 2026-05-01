autoload -Uz compinit

ZCOMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"

if [[ -n "$ZCOMPDUMP(#qN.mh+24)" ]];then
    compinit -d "$ZCOMPDUMP"
else
    compinit -C -d "$ZCOMPDUMP"
fi

{
    if [[ ! "$ZCOMPDUMP.zwc" -nt "$ZCOMPDUMP" ]];then
        zcompile "$ZCOMPDUMP"
    fi
} &!

umask 022

limit coredumpsize 0

# rustup
source "$HOME/.cargo/env"

export PATH="$HOME/.local/bin:$PATH"

# sheldon up
if [[ ! $HOME/.zsh_plugins.zsh -nt $HOME/.config/sheldon/plugins.toml ]]; then
    sheldon source > $HOME/.zsh_plugins.zsh
fi
source $HOME/.zsh_plugins.zsh


autoload -Uz compinit

export PATH="$HOME/.pixi/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"

alias v='bob run stable'

# ls
alias ls='eza'
alias ll='eza -l'
alias la='eza -A'
alias lla='eza -l -A'

# zoxide
alias z='zoxide'


alias g='git'
alias gst='git status'
alias gsw='git switch'
alias gbr='git branch'
alias gfe='git fetch'
alias gpl='git pull'
alias gad='git add'
alias gada='git add .'
alias gcm='git commit'
alias gmg='git merge'
alias gpsh='git push'


# locale
export LANG=ja_JP.UTF-8

# term
export TERM=alacritty
