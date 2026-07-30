# shellcheck shell=bash
# Make zsh the login shell, and materialise the pinned zsh plugins.

step_default_shell() {
  local zsh_path
  zsh_path=$(command -v zsh) || { warn "zsh is not installed (run: bs.sh --only apt:base)"; return 1; }

  # Compare resolved paths: /bin is a symlink to /usr/bin on Ubuntu, so
  # /bin/zsh and /usr/bin/zsh are the same shell and neither needs changing.
  local current
  current=$(getent passwd "$(id -un)" | cut -d: -f7)
  if [ "$(readlink -f "$current" 2>/dev/null)" = "$(readlink -f "$zsh_path")" ]; then
    ok "login shell is already zsh ($current)"
    return 0
  fi
  info "changing the login shell from $current to $zsh_path"
  # sudo first when we have it: plain `chsh` asks for a password through PAM,
  # which fails noisily in any non-interactive run.
  if [ "${SUDO_OK:-0}" = 1 ]; then
    run_sudo chsh -s "$zsh_path" "$(id -un)"
  else
    run chsh -s "$zsh_path"
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

register zsh:plugins no  "clone zsh plugins at their pinned revisions" step_zsh_plugins
register shell       yes "make zsh the login shell"                   step_default_shell