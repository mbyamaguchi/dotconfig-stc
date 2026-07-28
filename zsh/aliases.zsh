# Optional tools are guarded with has() (defined in .zshrc) so a machine
# missing one falls back instead of shadowing a working command.

# editor
has nvim && alias v='nvim'

# ls
if has eza; then
    alias ls='eza'
    alias ll='eza -l'
    alias la='eza -A'
    alias lla='eza -lA'
else
    alias ll='ls -l'
    alias la='ls -A'
    alias lla='ls -lA'
fi

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

# docker
if has docker; then
    alias d='docker'
    alias dc='docker compose'
fi

# cargo
has cargo && alias cgo='cargo'
