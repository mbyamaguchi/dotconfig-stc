# shellcheck shell=bash
# Make zsh the login shell, and materialise the pinned zsh plugins.

step_default_shell() {
  local zsh_path
  zsh_path=$(command -v zsh) || { warn "zsh is not installed (run: bs.sh --only apt:base)"; return 1; }

  # Compare resolved paths: /bin is a symlink to /usr/bin on Ubuntu, so
  # /bin/zsh and /usr/bin/zsh are the same shell and neither needs changing.
  local current
  current=$(getent passwd "$USER" | cut -d: -f7)
  if [ "$(readlink -f "$current" 2>/dev/null)" = "$(readlink -f "$zsh_path")" ]; then
    ok "login shell is already zsh ($current)"
    return 0
  fi
  info "changing the login shell from $current to $zsh_path"
  run chsh -s "$zsh_path" || run_sudo chsh -s "$zsh_path" "$USER"
}

check_default_shell() {
  local id="$1" current zsh_path
  current=$(getent passwd "$USER" | cut -d: -f7)
  zsh_path=$(command -v zsh 2>/dev/null || echo /bin/zsh)
  if [ "$(readlink -f "$current" 2>/dev/null)" = "$(readlink -f "$zsh_path")" ]; then
    say "$id" OK "$current"
  else
    say "$id" WARN "login shell is $current, not $zsh_path"
  fi
}

# ----------------------------------------------------------------------------
# zsh plugins
# ----------------------------------------------------------------------------
# sheldon/plugins.toml pins every plugin by commit. `sheldon lock` clones and
# checks out those revisions; without it the first interactive shell does the
# work instead, which makes a fresh login look broken for several seconds.
step_zsh_plugins() {
  has sheldon || step_skip "sheldon is not installed (run: bs.sh --only tool:sheldon)"
  info "locking zsh plugins at the pinned revisions"
  run sheldon lock
}

check_zsh_plugins() {
  local id="$1" toml="$CONFIG_DIR/sheldon/plugins.toml" repo rev dir mismatch="" missing=""
  [ -r "$toml" ] || { say "$id" WARN "sheldon/plugins.toml missing"; return 0; }

  while read -r repo; do
    rev=$(awk -v r="$repo" '
      $0 ~ "github = ." r "." { found = 1; next }
      found && /^rev = / { gsub(/[",]/, "", $3); print $3; exit }
      found && /^\[/ { exit }' "$toml")
    if [ -z "$rev" ]; then missing+=" ${repo##*/}"; continue; fi
    dir="$XDG_DATA_HOME/sheldon/repos/github.com/$repo"
    [ -d "$dir" ] || { missing+=" ${repo##*/}"; continue; }
    [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$rev" ] || mismatch+=" ${repo##*/}"
  done < <(grep -oE "^github = ['\"][^'\"]+" "$toml" | sed "s/.*['\"]//")

  if [ -n "$missing" ]; then
    say "$id" WARN "not cloned or unpinned:$missing"
  elif [ -n "$mismatch" ]; then
    say "$id" WARN "checked out at a different revision:$mismatch (run: sheldon lock)"
  else
    say "$id" OK "all plugins at their pinned revisions"
  fi
}

register zsh:plugins no  "clone zsh plugins at their pinned revisions" step_zsh_plugins   check_zsh_plugins
register shell       yes "make zsh the login shell"                   step_default_shell check_default_shell
