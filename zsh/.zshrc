umask 022
limit coredumpsize 0

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.pixi/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"
export PATH="$HOME/.local/share/zig:$PATH"
export PATH="$PATH:$(go env GOPATH)/bin"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
autoload -Uz compinit && compinit

# ---------------------------------------------------------------------------
# Plugins (sheldon)
# ---------------------------------------------------------------------------
eval "$(sheldon source)"

# ---------------------------------------------------------------------------
# Locale
# ---------------------------------------------------------------------------
export LANG=ja_JP.UTF-8

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
# nvm
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# fzf
source <(fzf --zsh)

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias v='bob run stable'

# ls (eza)
alias ls='eza'
alias ll='eza -l'
alias la='eza -A'
alias lla='eza -l -A'

# zoxide
alias z='zoxide'

# git
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

# cargo
alias cgo='cargo'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
# yazi: cd into the directory yazi exits in
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
