# shellcheck shell=bash
# The machine-local half of the git configuration.
#
# git/config is tracked and ends with `[include] path = ~/.config/git/config.local`.
# config.local holds whatever should not be in a public repository -- a real
# address, a signing key -- so it is untracked, and this step creates it from the
# tracked template. It never overwrites an existing one.

GIT_LOCAL="$CONFIG_DIR/git/config.local"
GIT_TEMPLATE="$CONFIG_DIR/git/config.local.template"

step_git_local() {
  if [ -f "$GIT_LOCAL" ]; then
    ok "git/config.local exists"
  elif [ ! -r "$GIT_TEMPLATE" ]; then
    warn "git/config.local.template is missing"
    return 1
  else
    info "creating git/config.local from the template"
    run cp "$GIT_TEMPLATE" "$GIT_LOCAL"
    warn "edit $GIT_LOCAL -- git/config sets user.useConfigOnly, so commits refuse to run until an identity is set"
  fi

  # ~/.gitconfig is read after the XDG file and wins. On this machine it is where
  # the signing key and gh credential helpers live, none of which are in the repo
  # and none of which a fresh machine gets -- so the two machines behave
  # differently in a way nothing in git status would show.
  if [ -f "$HOME/.gitconfig" ]; then
    # shellcheck disable=SC2088  # messages, not paths to expand
    warn "~/.gitconfig exists and overrides ~/.config/git/config"
    warn "  it has: $(git config --file "$HOME/.gitconfig" --list | cut -d= -f1 | paste -sd' ' -)"
    warn "  move the machine-local parts into git/config.local and delete it,"
    warn "  then re-create the credential helpers with: gh auth setup-git"
  fi
}

register git:local no "create git/config.local from the tracked template" step_git_local