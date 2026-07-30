#!/usr/bin/env bash
# =============================================================================
# bootstrap/bs.sh
# Reproduce this ~/.config on an Ubuntu machine, and keep its pins current.
#
#   bs.sh                 install everything (idempotent; safe to re-run)
#   bs.sh update          bump every pinned version, then review the git diff
#   bs.sh doctor          report where the machine differs from the manifests
#   bs.sh list            list the steps
#
# What goes where:
#   tools.tsv     prebuilt binaries from GitHub releases -> ~/.local/bin
#   apt.tsv       apt package set, by group
#   runtimes.tsv  nvim / node / pnpm / go / rust, each via its own manager
#   steps/*.sh    one file per concern, registering steps in numeric order
#
# Adding a tool is one line in tools.tsv. Nothing else.
# =============================================================================

# Not -e: a failing step is collected and reported at the end rather than
# aborting the run, so one broken download does not cost you the whole install.
# Each step body does run under -e, inside its own subshell (see dispatch).
set -uo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$BOOTSTRAP_DIR/lib.sh"

# ----------------------------------------------------------------------------
# Step registry
# ----------------------------------------------------------------------------
declare -a STEP_IDS=()
declare -A STEP_DESC=() STEP_ROOT=() STEP_RUN=() STEP_CHECK=()

# register <id> <needs_root: yes|no> <description> <run_fn> [check_fn]
register() {
  STEP_IDS+=("$1")
  STEP_ROOT["$1"]="$2"
  STEP_DESC["$1"]="$3"
  STEP_RUN["$1"]="$4"
  STEP_CHECK["$1"]="${5:-}"
}

load_steps() {
  local f
  for f in "$BOOTSTRAP_DIR"/steps/*.sh; do
    [ -r "$f" ] || continue
    # shellcheck source=/dev/null
    . "$f"
  done
}

# ----------------------------------------------------------------------------
# Selection
# ----------------------------------------------------------------------------
ONLY="" SKIP_LIST="" DRY_RUN=0 NO_SUDO=0 ARCH_OVERRIDE="" UPDATE_CHECK=0

# --only/--skip match on a prefix, so `--only tool:` selects every tool and
# `--only tool:eza` selects one.
_matches() {
  local id="$1" list="$2" p
  local -a pat=()
  IFS=, read -r -a pat <<<"$list"
  for p in "${pat[@]}"; do
    [ -n "$p" ] || continue
    case "$id" in "$p"*) return 0 ;; esac
  done
  return 1
}

selected() {
  local id="$1"
  [ -n "$SKIP_LIST" ] && _matches "$id" "$SKIP_LIST" && return 1
  [ -z "$ONLY" ] && return 0
  _matches "$id" "$ONLY"
}

# ----------------------------------------------------------------------------
# Root access
# ----------------------------------------------------------------------------
SUDO_OK=0 SUDO_CMD=""
_SUDO_KEEPALIVE_PID=""

sudo_init() {
  # Running the whole script through sudo would install into /root/.local and
  # chown half of $HOME to root. Refuse instead of producing a broken machine.
  if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ]; then
    die "do not run this with sudo -- run it as your own user; individual commands elevate themselves"
  fi

  if [ "$NO_SUDO" = 1 ]; then
    SUDO_OK=0
    return 0
  fi
  if [ "$(id -u)" = 0 ]; then
    SUDO_OK=1 SUDO_CMD=""
    return 0
  fi
  has sudo || { SUDO_OK=0; return 0; }

  # A dry run changes nothing, so do not make the user authenticate just to see
  # the plan -- and do show them the root steps rather than skipping them.
  if [ "$DRY_RUN" = 1 ]; then
    SUDO_OK=1 SUDO_CMD="sudo"
    return 0
  fi

  # One prompt for the whole run, then keep the timestamp warm so a long apt
  # step cannot be interrupted by a second password prompt.
  if sudo -n true 2>/dev/null || { [ -t 0 ] && sudo -v; }; then
    SUDO_OK=1 SUDO_CMD="sudo"
    while true; do sudo -n true 2>/dev/null || break; sleep 50; done &
    _SUDO_KEEPALIVE_PID=$!
  else
    SUDO_OK=0
  fi
}

on_exit() {
  [ -n "$_SUDO_KEEPALIVE_PID" ] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null
  tmp_cleanup
}
trap on_exit EXIT

# ----------------------------------------------------------------------------
# install
# ----------------------------------------------------------------------------
cmd_install() {
  local id rc
  local -a failed=() skipped=() rootless=()

  mkdir -p "$LOCAL_BIN" "$FONT_DIR"

  for id in "${STEP_IDS[@]}"; do
    selected "$id" || continue
    if [ "${STEP_ROOT[$id]}" = yes ] && [ "$SUDO_OK" != 1 ]; then
      rootless+=("$id")
      skip "$id: needs root"
      continue
    fi

    head_ "$id  ${_C_DIM}${STEP_DESC[$id]}${_C_OFF}"
    # Subshell so the step body can use `set -e` (a failure inside it stops that
    # step immediately) without ending the whole run.
    # Unquoted on purpose: a registered command may carry arguments, as in
    # "tool_install eza", and must be word-split.
    # shellcheck disable=SC2086
    ( set -euo pipefail; ${STEP_RUN[$id]} )
    rc=$?
    case "$rc" in
      0)           ok "$id" ;;
      "$SKIP_RC")  skipped+=("$id") ;;
      *)           err "$id failed (exit $rc)"; failed+=("$id") ;;
    esac
  done

  printf '\n'
  head_ "Summary"
  if [ ${#skipped[@]} -gt 0 ]; then skip "skipped: ${skipped[*]}"; fi
  if [ ${#rootless[@]} -gt 0 ]; then
    local list; list=$(IFS=,; printf '%s' "${rootless[*]}")
    warn "skipped ${#rootless[@]} step(s) needing root. When you have sudo:"
    warn "    $BOOTSTRAP_DIR/bs.sh --only $list"
  fi
  if [ ${#failed[@]} -gt 0 ]; then
    err "failed: ${failed[*]}"
    err "re-run just those with: bs.sh --only $(IFS=,; printf '%s' "${failed[*]}")"
    return 1
  fi
  ok "no failures"
  next_steps
}

next_steps() {
  cat <<EOF

--- Next steps --------------------------------------------------------------
  * Start a new shell: exec zsh
  * Check the result:  $BOOTSTRAP_DIR/bs.sh doctor
EOF
  if is_wsl; then
    cat <<'EOF'
  * WSL: Windows terminals do not read Linux-side fonts. Install Cica on the
    Windows side too and select it as the terminal font.
EOF
    if has wslpath && has wslvar; then
      local up
      up=$(wslpath "$(wslvar USERPROFILE 2>/dev/null)" 2>/dev/null) || up=""
      [ -n "$up" ] && printf '      TTFs are in %s -- copy them to %s/Downloads and double-click.\n' \
        "$FONT_DIR" "$up"
    fi
  fi
  printf -- '-----------------------------------------------------------------------------\n'
}

# ----------------------------------------------------------------------------
# list
# ----------------------------------------------------------------------------
cmd_list() {
  printf '%-22s %-6s %s\n' ID ROOT DESCRIPTION
  printf '%-22s %-6s %s\n' '---' '----' '-----------'
  local id
  for id in "${STEP_IDS[@]}"; do
    printf '%-22s %-6s %s\n' "$id" "${STEP_ROOT[$id]}" "${STEP_DESC[$id]}"
  done
}

# ----------------------------------------------------------------------------
# doctor
# ----------------------------------------------------------------------------
DOCTOR_BAD=0

cmd_doctor() {
  printf '%-22s %-5s %s\n' ID STATUS DETAIL
  printf '%-22s %-5s %s\n' '---' '-----' '------'
  local id fn
  for id in "${STEP_IDS[@]}"; do
    selected "$id" || continue
    fn="${STEP_CHECK[$id]}"
    [ -n "$fn" ] || continue
    "$fn" "$id"
  done
  doctor_extra
  printf '\n'
  if [ "$DOCTOR_BAD" = 1 ]; then
    warn "differences found -- run bs.sh to reconcile"
    return 1
  fi
  ok "machine matches the manifests"
}

# say <id> <OK|WARN|FAIL|INFO> <detail...>
say() {
  local id="$1" status="$2"; shift 2
  local c
  case "$status" in
    OK)   c=$_C_OK ;;
    WARN) c=$_C_WARN; DOCTOR_BAD=1 ;;
    FAIL) c=$_C_ERR;  DOCTOR_BAD=1 ;;
    *)    c=$_C_DIM ;;
  esac
  printf '%-22s %s%-5s%s %s\n' "$id" "$c" "$status" "$_C_OFF" "$*"
}

# Checks that belong to no single step.
doctor_extra() {
  # lib.sh's path_init() is a hand-kept copy of the `path=(...)` list in
  # zsh/.zshenv, and the two can rot apart. What actually breaks when they do is
  # bootstrap installing a tool into a directory the shell never looks at, so
  # assert exactly that: every directory bootstrap uses must be on zsh's $path.
  # (Not set equality -- zsh's $path legitimately has more, inherited from
  # /etc/profile and friends.)
  if has zsh; then
    local zpath d missing=""
    zpath=$(zsh -c 'print -rl -- $path' 2>/dev/null)
    for d in "${PATH_WANT[@]}"; do
      [ -d "$d" ] || continue
      printf '%s\n' "$zpath" | grep -qxF "$d" || missing+=" $d"
    done
    if [ -z "$missing" ]; then
      say path OK "all ${#PATH_WANT[@]} bootstrap dirs are on zsh \$path"
    else
      say path WARN "missing from zsh \$path (add to zsh/.zshenv):$missing"
    fi
  fi

  # A lockfile with uncommitted changes means the machine has drifted ahead of
  # what a fresh install would get.
  if [ -f "$CONFIG_DIR/nvim/lazy-lock.json" ]; then
    if git -C "$CONFIG_DIR" diff --quiet -- nvim/lazy-lock.json 2>/dev/null; then
      say nvim:lock OK "committed"
    else
      say nvim:lock WARN "uncommitted plugin updates -- commit nvim/lazy-lock.json"
    fi
  fi

  # ~/.gitconfig is read after ~/.config/git/config and wins, so anything in it
  # is invisible to this repo and absent on a fresh machine.
  if [ -f "$HOME/.gitconfig" ]; then
    say git:home WARN "~/.gitconfig shadows git/config -- fold it into git/config.local"
  else
    say git:home OK "no ~/.gitconfig shadowing the XDG config"
  fi

  if is_wsl; then
    local n
    n=$(zsh -c 'print -rl -- $path' 2>/dev/null | grep -c '^/mnt/' || true)
    say wsl INFO "$n Windows PATH entries kept (pruned in zsh/.zshenv)"
  fi
}

# ----------------------------------------------------------------------------
# update -- bump the pins
# ----------------------------------------------------------------------------
# Rewrite one field of one row, by column number. awk into a temp file and move
# it, never sed -i: a stray substitution in a TSV silently corrupts a column.
tsv_set() {
  local file="$BOOTSTRAP_DIR/$1" key="$2" col="$3" val="$4" tmp
  tmp="$(mktemp)"
  awk -F'\t' -v OFS='\t' -v k="$key" -v c="$col" -v v="$val" \
    '!/^#/ && NF && $1 == k { $c = v } { print }' "$file" >"$tmp" \
    && mv "$tmp" "$file"
}

UPDATE_CHANGES=0

# bump <label> <file> <key> <col> <current> <latest>
bump() {
  local label="$1" file="$2" key="$3" col="$4" cur="$5" new="$6"
  if [ -z "$new" ]; then
    warn "$label: could not resolve the latest version"
    return 0
  fi
  if [ "$cur" = "$new" ]; then
    skip "$label $cur"
    return 0
  fi
  UPDATE_CHANGES=1
  printf '%s  ->%s %-12s %s -> %s\n' "$_C_INFO" "$_C_OFF" "$label" "$cur" "$new"
  [ "$UPDATE_CHECK" = 1 ] && return 0
  tsv_set "$file" "$key" "$col" "$new"
}

update_tools() {
  local name ref min repo asset install new
  while IFS=$'\t' read -r name ref min repo asset install; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -n "$ONLY" ] && ! _matches "$name" "$ONLY" && continue
    [ "$ref" = latest ] && { skip "$name latest (floats by design)"; continue; }
    new=$(latest_tag "$repo")
    bump "$name" tools.tsv "$name" 2 "$ref" "$new"
  done < <(grep -v '^#' "$BOOTSTRAP_DIR/tools.tsv" | grep -v '^$')
}

update_runtimes() {
  local cur new

  if [ -z "$ONLY" ] || _matches nvim "$ONLY"; then
    cur=$(manifest_field runtimes.tsv nvim 2)
    bump nvim runtimes.tsv nvim 2 "$cur" "$(latest_tag neovim/neovim)"
  fi

  if [ -z "$ONLY" ] || _matches node "$ONLY"; then
    cur=$(manifest_field runtimes.tsv node 2)
    # Highest LTS from the official index; jq keeps this to one request.
    new=$(curl "${CURL_OPTS[@]}" https://nodejs.org/dist/index.json 2>/dev/null \
          | jq -r '[.[] | select(.lts != false)] | .[0].version' 2>/dev/null)
    bump node runtimes.tsv node 2 "$cur" "${new#v}"
  fi

  if [ -z "$ONLY" ] || _matches pnpm "$ONLY"; then
    cur=$(manifest_field runtimes.tsv pnpm 2)
    new=$(curl "${CURL_OPTS[@]}" https://registry.npmjs.org/pnpm 2>/dev/null \
          | jq -r '.["dist-tags"].latest' 2>/dev/null)
    bump pnpm runtimes.tsv pnpm 2 "$cur" "$new"
  fi

  if [ -z "$ONLY" ] || _matches go "$ONLY"; then
    cur=$(manifest_field runtimes.tsv go 2)
    new=$(curl "${CURL_OPTS[@]}" 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n1)
    bump go runtimes.tsv go 2 "$cur" "${new#go}"
  fi

  # rust is `stable` on purpose (see runtimes.tsv), so there is nothing to bump.
}

# sheldon has no lockfile that records revisions, so the pins live in
# plugins.toml and this is the only way to refresh them.
update_sheldon() {
  local toml="$CONFIG_DIR/sheldon/plugins.toml" repo cur new tmp
  [ -r "$toml" ] || return 0
  [ -z "$ONLY" ] || _matches sheldon "$ONLY" || return 0

  while read -r repo; do
    cur=$(awk -v r="$repo" '
      $0 ~ "github = ." r "." { found = 1; next }
      found && /^rev = / { gsub(/[",]/, "", $3); print $3; exit }
      found && /^\[/ { exit }' "$toml")
    new=$(git ls-remote "https://github.com/$repo" HEAD 2>/dev/null | awk '{print $1}')
    if [ -z "$new" ]; then warn "sheldon/$repo: could not reach the remote"; continue; fi
    if [ "$cur" = "$new" ]; then skip "sheldon/${repo##*/} ${cur:0:8}"; continue; fi
    UPDATE_CHANGES=1
    printf '%s  ->%s %-12s %s -> %s\n' "$_C_INFO" "$_C_OFF" "${repo##*/}" "${cur:0:8}" "${new:0:8}"
    [ "$UPDATE_CHECK" = 1 ] && continue
    tmp="$(mktemp)"
    awk -v old="$cur" -v new="$new" '{ gsub(old, new); print }' "$toml" >"$tmp" && mv "$tmp" "$toml"
  done < <(grep -oE "github = ['\"][^'\"]+" "$toml" | sed "s/.*['\"]//")
}

# lazy.nvim owns its own lockfile; ask it to update and let the diff show up in
# nvim/lazy-lock.json.
update_nvim_plugins() {
  [ -z "$ONLY" ] || _matches plugins "$ONLY" || return 0
  has nvim || { skip "nvim not installed; skipping plugin update"; return 0; }
  if [ "$UPDATE_CHECK" = 1 ]; then
    skip "nvim plugins (run without --check to update lazy-lock.json)"
    return 0
  fi
  info "updating nvim plugins (lazy-lock.json)"
  nvim --headless '+Lazy! update' +qa 2>/dev/null || warn "nvim plugin update failed"
  git -C "$CONFIG_DIR" diff --quiet -- nvim/lazy-lock.json 2>/dev/null \
    && skip "lazy-lock.json unchanged" \
    || { UPDATE_CHANGES=1; info "lazy-lock.json updated"; }
}

cmd_update() {
  has jq || warn "jq is missing; some lookups will be skipped (bs.sh --only apt installs it)"
  head_ "Resolving latest versions"
  update_tools
  update_runtimes
  update_sheldon
  update_nvim_plugins

  printf '\n'
  if [ "$UPDATE_CHANGES" = 0 ]; then
    ok "everything is already at the latest version"
    return 0
  fi
  if [ "$UPDATE_CHECK" = 1 ]; then
    warn "updates are available (run without --check to write them)"
    return 1
  fi
  head_ "Updated"
  cat <<EOF
  Review and commit, then apply:

      git -C $CONFIG_DIR diff
      git -C $CONFIG_DIR commit -am 'Bump pins'
      $BOOTSTRAP_DIR/bs.sh
EOF
}

# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bs.sh [COMMAND] [OPTIONS]

Commands
  install        (default) run every step, in order. Idempotent.
  update        bump every pinned version in the manifests
  doctor        report where this machine differs from the manifests
  list          list the steps

Options
  --only ID,…    run only these steps (prefix match: --only tool:)
  --skip ID,…    skip these steps
  --dry-run      print what would change, change nothing
  --no-sudo      skip the steps that need root
  --check        update only: report what is behind, write nothing
  --arch ARCH    override architecture detection (testing)
  -h, --help     this text

Examples
  bs.sh                       set up or repair the machine
  bs.sh --only tool:          reinstall the pinned binaries
  bs.sh update --check        is anything behind upstream?
  bs.sh doctor
EOF
}

main() {
  local cmd=install
  case "${1:-}" in
    install|update|doctor|list) cmd=$1; shift ;;
    -h|--help) usage; exit 0 ;;
  esac

  while [ $# -gt 0 ]; do
    case "$1" in
      --only)     ONLY="${2:?--only needs a value}"; shift 2 ;;
      --only=*)   ONLY="${1#*=}"; shift ;;
      --skip)     SKIP_LIST="${2:?--skip needs a value}"; shift 2 ;;
      --skip=*)   SKIP_LIST="${1#*=}"; shift ;;
      --arch)     ARCH_OVERRIDE="${2:?--arch needs a value}"; shift 2 ;;
      --arch=*)   ARCH_OVERRIDE="${1#*=}"; shift ;;
      --dry-run)  DRY_RUN=1; shift ;;
      --no-sudo)  NO_SUDO=1; shift ;;
      --check)    UPDATE_CHECK=1; shift ;;
      -h|--help)  usage; exit 0 ;;
      # A bare word is the old `bs.sh install_eza` calling convention.
      -*)         err "unknown option: $1"; usage; exit 2 ;;
      *)          err "unexpected argument: $1 (did you mean --only $1 ?)"; exit 2 ;;
    esac
  done

  export ARCH_OVERRIDE DRY_RUN
  arch_init
  arch_ok || warn "unrecognised architecture $ARCH_RAW: steps needing prebuilt binaries will skip"
  path_init
  load_steps

  case "$cmd" in
    install) sudo_init; cmd_install ;;
    update)  cmd_update ;;
    doctor)  cmd_doctor ;;
    list)    cmd_list ;;
  esac
}

main "$@"
