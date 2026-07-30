# shellcheck shell=bash
# Point zsh at this repository.
#
# There is no symlink layer here: the repo *is* ~/.config, and zsh is told to
# read its startup files from ~/.config/zsh by setting ZDOTDIR system-wide.
# /etc/zsh/zshenv is the only file zsh reads before ZDOTDIR takes effect, which
# is why this needs root and cannot live in the repo.

ZSHENV_SYSTEM=/etc/zsh/zshenv

step_zdotdir() {
  if [ ! -e "$ZSHENV_SYSTEM" ]; then
    run_sudo mkdir -p "$(dirname "$ZSHENV_SYSTEM")"
    run_sudo touch "$ZSHENV_SYSTEM"
  fi
  if sudo_grep_zdotdir; then
    ok "ZDOTDIR already set in $ZSHENV_SYSTEM"
    return 0
  fi
  info "appending ZDOTDIR to $ZSHENV_SYSTEM"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    dry "echo 'export ZDOTDIR=\"\$HOME/.config/zsh\"' >> $ZSHENV_SYSTEM"
    return 0
  fi
  # Single quotes on purpose: $HOME must reach the file unexpanded so the line
  # works for whichever user's zsh reads it.
  # shellcheck disable=SC2016
  # ${VAR:+$VAR} rather than "${VAR:-}": when we are already root SUDO_CMD is
  # empty, and a quoted empty word would be an attempt to run the command "".
  printf 'export ZDOTDIR="$HOME/.config/zsh"\n' \
    | ${SUDO_CMD:+$SUDO_CMD} tee -a "$ZSHENV_SYSTEM" >/dev/null
}

# Reading /etc/zsh/zshenv needs no privilege in practice, but do not assume it.
sudo_grep_zdotdir() {
  grep -q 'ZDOTDIR' "$ZSHENV_SYSTEM" 2>/dev/null && return 0
  [ "${SUDO_OK:-0}" = 1 ] || return 1
  ${SUDO_CMD:+$SUDO_CMD} grep -q 'ZDOTDIR' "$ZSHENV_SYSTEM" 2>/dev/null
}

register zdotdir yes "point zsh at ~/.config/zsh via /etc/zsh/zshenv" step_zdotdir