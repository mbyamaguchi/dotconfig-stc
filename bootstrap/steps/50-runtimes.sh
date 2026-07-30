# shellcheck shell=bash
# Language runtimes, each through its own version manager, pinned by runtimes.tsv.
# Unlike tools.tsv these are not "download one binary", which is why they are
# hand-written steps rather than manifest-driven.

rt_ref() { manifest_field runtimes.tsv "$1" 2; }
rt_min() { manifest_field runtimes.tsv "$1" 3; }

# ----------------------------------------------------------------------------
# Rust
# ----------------------------------------------------------------------------
# Tracks stable on purpose (see the note in runtimes.tsv): nothing here depends
# on a rustc version, and re-downloading a ~200MB toolchain per bump is not worth
# it. --no-modify-path because zsh/.zshenv already has ~/.cargo/bin.
_rustup_install() {
  curl "${CURL_OPTS[@]}" https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile default
}

step_rust() {
  local min; min=$(rt_min rust)
  if has cargo; then
    local cur; cur=$(version_of cargo)
    if ver_ge "$cur" "$min"; then
      ok "rust $cur (>= $min)"
      return 0
    fi
    info "rust $cur is older than $min; updating"
    run rustup update stable
    return
  fi
  info "installing rustup"
  run _rustup_install
  # shellcheck disable=SC1091
  [ "${DRY_RUN:-0}" = 1 ] || . "$HOME/.cargo/env"

  # rustfmt and clippy back conform.nvim and rust_analyzer's checkOnSave.
  run rustup component add rustfmt clippy
}

check_rust() {
  local id="$1" min; min=$(rt_min rust)
  if ! has cargo; then say "$id" WARN "not installed"; return 0; fi
  local cur; cur=$(version_of cargo)
  if ver_ge "$cur" "$min"; then say "$id" OK "$cur (tracks stable, min $min)"
  else say "$id" WARN "$cur is below the required $min"; fi
}

# ----------------------------------------------------------------------------
# Go
# ----------------------------------------------------------------------------
# Ubuntu's `golang` on noble is 1.22.2, which upstream no longer supports, so the
# pinned tarball goes to ~/.local/go and is shimmed into ~/.local/bin (which
# precedes /usr/bin, so an apt copy is shadowed rather than fought with).
step_go() {
  local ref; ref=$(rt_ref go)
  arch_require

  if [ -x "$GO_ROOT/bin/go" ] && [ "$("$GO_ROOT/bin/go" version | awk '{print $3}')" = "go$ref" ]; then
    ok "go $ref already in $GO_ROOT"
    run ln -sf "$GO_ROOT/bin/go" "$LOCAL_BIN/go"
    run ln -sf "$GO_ROOT/bin/gofmt" "$LOCAL_BIN/gofmt"
    return 0
  fi

  has go && info "go $(version_of go) at $(command -v go); installing the pinned $ref"

  local url tmp
  url="https://go.dev/dl/go${ref}.linux-${GOARCH}.tar.gz"
  info "$url"
  tmp=$(mktmp)
  download "$url" "$tmp/go.tar.gz"
  extract "$tmp/go.tar.gz" "$tmp"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    dry "mv $tmp/go -> $GO_ROOT; symlink go and gofmt into $LOCAL_BIN"
    return 0
  fi
  rm -rf "$GO_ROOT"
  mkdir -p "$(dirname "$GO_ROOT")"
  mv "$tmp/go" "$GO_ROOT"
  ln -sf "$GO_ROOT/bin/go" "$LOCAL_BIN/go"
  ln -sf "$GO_ROOT/bin/gofmt" "$LOCAL_BIN/gofmt"
  hash -r 2>/dev/null || true
  info "go is now $(version_of go)"
}

check_go() {
  local id="$1" ref cur where
  ref=$(rt_ref go)
  if ! has go; then say "$id" WARN "not installed (pinned $ref)"; return 0; fi
  cur=$(version_of go); where=$(command -v go)
  case "$where" in
    "$LOCAL_BIN"/*|"$GO_ROOT"/*) ;;
    *) say "$id" WARN "$cur from $where (apt golang is EOL); pinned $ref"; return 0 ;;
  esac
  if [ "$cur" = "$ref" ]; then say "$id" OK "$cur"
  else say "$id" WARN "pinned $ref, installed $cur"; fi
}

# ----------------------------------------------------------------------------
# Node, via nvm
# ----------------------------------------------------------------------------
# nvm rather than a plain tarball because zsh/.zshenv deliberately does not
# source nvm.sh (~620ms per shell): it globs $NVM_DIR/versions/node/*/bin and
# reads $NVM_DIR/alias/default instead. So the alias has to be set, or that glob
# silently picks a different version than the pin.
step_node() {
  local ref; ref=$(rt_ref node)

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "cloning nvm into $NVM_DIR"
    if [ -d "$NVM_DIR/.git" ]; then
      run git -C "$NVM_DIR" fetch --tags -q origin
    else
      run git clone -q https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    fi
    if [ "${DRY_RUN:-0}" != 1 ]; then
      local tag; tag=$(git -C "$NVM_DIR" describe --abbrev=0 --tags 2>/dev/null)
      [ -n "$tag" ] && git -C "$NVM_DIR" checkout -q "$tag"
    fi
  fi

  if [ "${DRY_RUN:-0}" = 1 ]; then
    dry "nvm install $ref && nvm alias default $ref"
    return 0
  fi

  if [ -x "$NVM_DIR/versions/node/v$ref/bin/node" ] \
     && [ "$(cat "$NVM_DIR/alias/default" 2>/dev/null)" = "$ref" ]; then
    ok "node v$ref installed and set as default"
    return 0
  fi

  export NVM_DIR
  # nvm.sh is not shellcheck-clean and is not ours.
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install "$ref" || return 1
  # The alias must be the exact version, not "lts/*": .zshenv reads this file
  # literally and globs versions/node/v<it>*.
  nvm alias default "$ref" >/dev/null || return 1
  info "node $(node -v), default alias -> $(cat "$NVM_DIR/alias/default")"
}

check_node() {
  local id="$1" ref cur alias_
  ref=$(rt_ref node)
  if ! has node; then say "$id" WARN "not installed (pinned $ref)"; return 0; fi
  cur=$(version_of node)
  alias_=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
  if [ "$cur" != "$ref" ]; then
    say "$id" WARN "pinned $ref, active $cur"
  elif [ "$alias_" != "$ref" ]; then
    # This is the failure mode that breaks silently: .zshenv globs for the alias,
    # so a stale alias means new shells get a different node than this one.
    say "$id" WARN "$cur active, but nvm default alias is '$alias_' -- new shells may differ"
  else
    say "$id" OK "$cur (nvm default)"
  fi
}

# ----------------------------------------------------------------------------
# pnpm, and the editor's node tools
# ----------------------------------------------------------------------------
_pnpm_install() {
  curl "${CURL_OPTS[@]}" https://get.pnpm.io/install.sh \
    | env SHELL="$(command -v bash)" PNPM_HOME="$PNPM_HOME" sh -
}

step_pnpm() {
  local ref min; ref=$(rt_ref pnpm); min=$(rt_min pnpm)
  if has pnpm && ! needs_install pnpm "$ref" "$min"; then
    ok "pnpm $(version_of pnpm)"
  elif has corepack; then
    # corepack ships with node and installs an exact version without a network
    # install script.
    info "installing pnpm@$ref via corepack"
    run corepack install --global "pnpm@$ref"
  else
    info "installing pnpm"
    run _pnpm_install
  fi

  # prettier, stylua and eslint_d are what conform.nvim and nvim-lint shell out
  # to. On this machine they were installed with `npm -g`, which puts them inside
  # a single node version's directory -- so bumping node made them vanish.
  # $PNPM_HOME is version-independent and already on PATH via zsh/.zshenv.
  step_node_globals
}

NODE_GLOBALS=(prettier eslint_d)

step_node_globals() {
  has pnpm || { warn "pnpm missing; skipping the editor's node tools"; return 0; }
  local want=() g where
  for g in "${NODE_GLOBALS[@]}"; do
    if ! has "$g"; then
      want+=("$g")
      continue
    fi
    # Present but installed inside one node version's directory: it works today
    # and disappears the next time node is bumped, so move it.
    where=$(command -v "$g")
    case "$where" in
      "$NVM_DIR"/*) info "$g lives in $where; reinstalling it version-independently"; want+=("$g") ;;
    esac
  done
  if [ ${#want[@]} -eq 0 ]; then
    ok "editor node tools present: ${NODE_GLOBALS[*]}"
    return 0
  fi
  info "installing ${want[*]} into \$PNPM_HOME"
  run pnpm add -g "${want[@]}"
}

check_pnpm() {
  local id="$1" ref; ref=$(rt_ref pnpm)
  if has pnpm; then
    local cur; cur=$(version_of pnpm)
    if [ "$cur" = "$ref" ]; then say "$id" OK "$cur"; else say "$id" WARN "pinned $ref, installed $cur"; fi
  else
    say "$id" WARN "not installed"
  fi
  local g where missing=""
  for g in "${NODE_GLOBALS[@]}"; do
    if ! has "$g"; then missing+=" $g"; continue; fi
    where=$(command -v "$g")
    case "$where" in
      "$NVM_DIR"/*) say "node:$g" WARN "installed under a single node version ($where); bumping node loses it" ;;
      *) say "node:$g" OK "$where" ;;
    esac
  done
  [ -n "$missing" ] && say node:tools WARN "missing:$missing (conform.nvim / nvim-lint need these)"
  return 0
}

register rust  no "Rust toolchain via rustup (tracks stable)"        step_rust  check_rust
register go    no "Go from the pinned upstream tarball"              step_go    check_go
register node  no "Node via nvm, with the default alias pinned"      step_node  check_node
register pnpm  no "pnpm, plus prettier/eslint_d for the editor"      step_pnpm  check_pnpm
