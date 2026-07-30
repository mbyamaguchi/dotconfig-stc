#!/usr/bin/env bash
# =============================================================================
# bootstrap/cleanup.sh
# Retire files that are no longer read, so what is left is what is actually in
# use. Nothing is deleted: everything is moved to a timestamped directory under
# ~/.local/share/dotconfig-legacy/ so it can be put back.
#
#   ./cleanup.sh          list what would move, change nothing (default)
#   ./cleanup.sh --yes    actually move it
#
# Separate from bs.sh on purpose. bs.sh is safe to run on any machine at any
# time; this is a one-off with a judgement call behind each entry.
# =============================================================================

set -uo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$BOOTSTRAP_DIR/lib.sh"

APPLY=0
case "${1:-}" in
  --yes|-y) APPLY=1 ;;
  ''|--dry-run) APPLY=0 ;;
  *) die "usage: cleanup.sh [--yes]" ;;
esac

ATTIC="$XDG_DATA_HOME/dotconfig-legacy/$(date +%Y%m%d-%H%M%S)"

# Each entry: <path> <tab> <why>
# The "why" is the point -- none of these are obviously dead until you know that
# ZDOTDIR redirects zsh away from $HOME.
read -r -d '' TARGETS <<'EOF'
~/.zshrc	never read: ZDOTDIR sends zsh to ~/.config/zsh, so this is leftover installer output (pnpm, nvm, pixi, SDKMAN, grok)
~/.zshrc.bak.1784106134	backup of the above, equally unread
~/.zsh_plugins.zsh	stale hand-written sheldon output; sheldon generates this itself now
~/.zprofile	never read: zsh looks for $ZDOTDIR/.zprofile. Its ~/.elan/bin PATH entry has moved into zsh/.zshenv
~/.config/nvim.bak	the pre-LazyVim neovim config, superseded by nvim/
~/.config/matplotlib	empty
~/.config/wslu	empty
~/.config/nautilus	empty
~/.config/environment.d	symlinks into a /nix/store path that no longer exists
~/.config/systemd/user	symlinks into a /nix/store path that no longer exists
~/.local/bin/mise	89MB and unused: bob and nvm already manage neovim and node
EOF

# Deliberately NOT listed, because each needs a decision first:
#   ~/.gitconfig   holds the signing key and gh credential helpers, and overrides
#                  ~/.config/git/config. Fold it into git/config.local, run
#                  `gh auth setup-git`, and only then remove it.
#   ~/dotfiles     an abandoned earlier dotfiles repo. Its apt list is superseded
#                  by bootstrap/apt.tsv, but config/, local/share/fonts/ and
#                  secrets.template/ should be looked at before it goes.
#   ~/bootstrap    install_cpp.sh is folded into apt.tsv's cpp group; the rest is
#                  yours to judge.

main() {
  local n=0 moved=0 path why expanded
  head_ "Files that are no longer read"

  while IFS=$'\t' read -r path why; do
    [ -n "$path" ] || continue
    expanded="${path/#\~/$HOME}"
    [ -e "$expanded" ] || [ -L "$expanded" ] || continue
    n=$((n + 1))
    printf '%s  %s%s\n' "$_C_INFO$_C_OFF" "$path" ""
    printf '     %s%s%s\n' "$_C_DIM" "$why" "$_C_OFF"
    if [ "$APPLY" = 1 ]; then
      mkdir -p "$ATTIC$(dirname "${expanded#"$HOME"}")"
      if mv "$expanded" "$ATTIC${expanded#"$HOME"}" 2>/dev/null; then
        moved=$((moved + 1))
      else
        warn "could not move $path"
      fi
    fi
  done <<<"$TARGETS"

  printf '\n'
  if [ "$n" = 0 ]; then
    ok "nothing left to clean up"
    return 0
  fi
  if [ "$APPLY" = 1 ]; then
    ok "moved $moved of $n to $ATTIC"
    info "put something back with: mv $ATTIC/<path> ~/<path>"
  else
    warn "$n item(s) found. Nothing was moved -- re-run with --yes"
  fi

  cat <<'EOF'

Left alone on purpose, because each needs a decision from you:
  ~/.gitconfig  overrides ~/.config/git/config and holds your signing key and
                gh credential helpers. Move those into git/config.local, run
                `gh auth setup-git`, then delete it -- see `bs.sh doctor`.
  ~/dotfiles    an abandoned earlier dotfiles repo. Check config/,
                local/share/fonts/ and secrets.template/ before removing it.
  ~/bootstrap   install_cpp.sh is now apt.tsv's cpp group.
EOF
}

main
