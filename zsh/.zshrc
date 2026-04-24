umask 022

limit coredumpsize 0

export PATH="$HOME/.local/bin:$PATH"
eval "$(sheldon source)"

alias v='bob run stable'
alias cz='$HOME/bin/chezmoi'
alias czall='$HOME/scripts/czall $HOME/scripts/czlist.txt'

alias  ll='ls -l'
alias  la='ls -A'
alias  lla='ls -l -A'
alias  g='git'
alias  gst='git status'
alias  gsw='git switch'
alias  gbr='git branch'
alias  gfe='git fetch'
alias  gpl='git pull'
alias  gad='git add'
alias  gcm='git commit'
alias  gmg='git merge'
alias  gpsh='git push'
