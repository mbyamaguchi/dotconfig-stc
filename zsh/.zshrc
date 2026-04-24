umask 022

limit coredumpsize 0

export PATH="$HOME/.local/bin:$PATH"
eval "$(sheldon source)"

export PATH="$HOME/.pixi/bin:$PATH"

alias v='bob run stable'

alias ls='eza'
alias ll='eza -l'
alias la='eza -A'
alias lla='eza -l -A'
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
