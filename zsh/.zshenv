# XDG
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state

# PATH
export PATH=$HOME/.local/bin:/usr/local/sbin:$PATH

# locale
export LANGUAGE=en_US.UTF-8
export LANG=ja_JP.UTF-8

# editor
export EDITOR=nvim
export CVSEDITOR=$EDITOR
export SVN_EDITOR=$EDITOR
export GIT_EDITOR=$EDITOR

# history
export HISTFILE=$HOME/.config/zsh/.zsh_history
export HISTSIZE=1000
export SAVEHIST=100000

# dotnet
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$DOTNET_ROOT:$PATH

. "$HOME/.cargo/env"
. "$HOME/.local/share/bob/env/env.sh"
