#!/usr/bin/env bash
# =============================================================================
# bootstrap/bs.sh
# Bootstrap a fresh machine for this ~/.config (DotConfig feat. STC).
#
# Installs every tool referenced by the configs:
#   zsh / git / build tools / ripgrep / fd / bat / ffmpeg / xsel / tmux  (apt)
#   gh, rust(cargo), bob+neovim, eza, fzf, zoxide, yazi, go,
#   node(nvm)+pnpm, sheldon, starship, pixi, uv, yt-dlp, Cica font
#
# Usage:
#   ./bs.sh                 # run everything
#   ./bs.sh install_eza ... # run only the named step(s)
#
# Idempotent: every step skips work that is already done. Steps run
# independently; a failing step is reported at the end but does not abort
# the rest of the run.
# =============================================================================

set -uo pipefail

# ----------------------------------------------------------------------------
# Settings
# ----------------------------------------------------------------------------
NVIM_VERSION="${NVIM_VERSION:-stable}"
NODE_VERSION="${NODE_VERSION:---lts}"        # passed to `nvm install`

LOCAL_BIN="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts"
NVM_DIR="$HOME/.config/nvm"
GO_ROOT="$HOME/.local/go"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# Latest GitHub release asset URL matching a pattern.
latest_asset_url() {
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | cut -d'"' -f4 \
    | grep -E "$pattern" \
    | head -n1
}

# Download an archive, extract it into a temp dir, and run a callback that
# installs the wanted binaries. Usage: fetch_archive <url> <ext> <callback>
fetch_archive() {
  local url="$1" ext="$2" cb="$3" tmp rc=0
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/dl.$ext"; then
    case "$ext" in
      zip)            unzip -q -o "$tmp/dl.$ext" -d "$tmp" ;;
      tar.gz|tgz)     tar -xzf "$tmp/dl.$ext" -C "$tmp" ;;
      tar.xz|txz)     tar -xJf "$tmp/dl.$ext" -C "$tmp" ;;
      *)              warn "unknown archive ext: $ext"; rc=1 ;;
    esac
    if [ "$rc" -eq 0 ]; then "$cb" "$tmp" || rc=$?; fi
  else
    rc=1
  fi
  rm -rf "$tmp"
  return "$rc"
}

# ----------------------------------------------------------------------------
# Steps
# ----------------------------------------------------------------------------
setup_prepare() {
  info "Preparing directories and PATH"
  mkdir -p "$LOCAL_BIN" "$FONT_DIR"
  export PATH="$LOCAL_BIN:$PATH"
  export DEBIAN_FRONTEND=noninteractive
  ok "directories ready"
}

install_base_packages() {
  info "Installing base apt packages"
  if ! sudo apt-get update -y; then
    warn "apt update failed"; return 1
  fi
  if sudo apt-get install -y \
      git wget curl zsh unzip tar xz-utils \
      build-essential ca-certificates gnupg fontconfig \
      ripgrep fd-find bat ffmpeg xsel tmux; then
    ok "base packages installed"
  else
    warn "failed to install base packages"; return 1
  fi
}

# On Ubuntu the binaries are `fdfind` / `batcat`; the configs call `fd` / `bat`.
link_ubuntu_aliases() {
  info "Linking fd/bat shims"
  if has fdfind && ! has fd; then ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"; fi
  if has batcat && ! has bat; then ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"; fi
  ok "fd/bat available"
}

install_gh() {
  if has gh; then ok "gh already installed"; return 0; fi
  info "Installing GitHub CLI (gh)"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  if sudo apt-get update -y && sudo apt-get install -y gh; then
    ok "gh installed"
  else
    warn "failed to install gh"; return 1
  fi
}

setup_zdotdir() {
  local zshenv="/etc/zsh/zshenv"
  info "Setting ZDOTDIR in $zshenv"
  if [ ! -e "$zshenv" ]; then
    sudo mkdir -p /etc/zsh
    sudo touch "$zshenv"
  fi
  if sudo grep -q 'ZDOTDIR' "$zshenv"; then
    ok "ZDOTDIR already set"
  else
    echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a "$zshenv" >/dev/null
    ok "ZDOTDIR added"
  fi
}

install_rust() {
  if has cargo; then ok "rust already installed"; return 0; fi
  info "Installing Rust (rustup)"
  if curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
    ok "rust installed (~/.cargo)"
  else
    warn "failed to install rust"; return 1
  fi
}

install_bob_and_neovim() {
  local arch; arch="$(uname -m)"

  if has bob; then
    ok "bob already installed"
  else
    info "Installing bob (neovim version manager)"
    if [ "$arch" = "x86_64" ]; then
      local url
      url="$(latest_asset_url MordechaiHadad/bob 'bob-linux-x86_64\.zip$')"
      if [ -z "$url" ]; then warn "could not find bob release"; return 1; fi
      fetch_archive "$url" zip _install_bob || { warn "failed to install bob"; return 1; }
    elif has cargo; then
      cargo install bob-nvim || { warn "failed to cargo install bob-nvim"; return 1; }
    else
      warn "bob prebuilt is x86_64 only and cargo is missing (arch: $arch)"; return 1
    fi
    ok "bob installed"
  fi

  info "Installing Neovim ($NVIM_VERSION) via bob"
  if bob use "$NVIM_VERSION"; then
    ok "Neovim ready (~/.local/share/bob/nvim-bin)"
  else
    warn "failed to install Neovim"; return 1
  fi
}
_install_bob() { install -m 0755 "$(find "$1" -type f -name bob | head -n1)" "$LOCAL_BIN/bob"; }

install_eza() {
  if has eza; then ok "eza already installed"; return 0; fi
  info "Installing eza"
  local url
  url="$(latest_asset_url eza-community/eza 'eza_x86_64-unknown-linux-gnu\.tar\.gz$')"
  if [ -z "$url" ]; then warn "could not find eza release"; return 1; fi
  fetch_archive "$url" tar.gz _install_eza && ok "eza installed" || { warn "failed to install eza"; return 1; }
}
_install_eza() { install -m 0755 "$(find "$1" -type f -name eza | head -n1)" "$LOCAL_BIN/eza"; }

install_fzf() {
  # zshrc uses `fzf --zsh`, which needs fzf >= 0.48 (newer than apt's).
  if has fzf && fzf --zsh >/dev/null 2>&1; then ok "fzf already installed"; return 0; fi
  info "Installing fzf"
  local url
  url="$(latest_asset_url junegunn/fzf 'fzf-[0-9.]+-linux_amd64\.tar\.gz$')"
  if [ -z "$url" ]; then warn "could not find fzf release"; return 1; fi
  fetch_archive "$url" tar.gz _install_fzf && ok "fzf installed" || { warn "failed to install fzf"; return 1; }
}
_install_fzf() { install -m 0755 "$(find "$1" -type f -name fzf | head -n1)" "$LOCAL_BIN/fzf"; }

install_zoxide() {
  if has zoxide; then ok "zoxide already installed"; return 0; fi
  info "Installing zoxide"
  if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
      | sh -s -- --bin-dir "$LOCAL_BIN"; then
    ok "zoxide installed"
  else
    warn "failed to install zoxide"; return 1
  fi
}

install_yazi() {
  if has yazi; then ok "yazi already installed"; return 0; fi
  info "Installing yazi"
  local url
  url="$(latest_asset_url sxyazi/yazi 'yazi-x86_64-unknown-linux-gnu\.zip$')"
  if [ -z "$url" ]; then warn "could not find yazi release"; return 1; fi
  fetch_archive "$url" zip _install_yazi && ok "yazi installed" || { warn "failed to install yazi"; return 1; }
}
_install_yazi() {
  install -m 0755 "$(find "$1" -type f -name yazi | head -n1)" "$LOCAL_BIN/yazi"
  local ya; ya="$(find "$1" -type f -name ya | head -n1)"
  [ -n "$ya" ] && install -m 0755 "$ya" "$LOCAL_BIN/ya" || true
}

install_go() {
  # zshrc runs `go env GOPATH`, so `go` must be on PATH ($LOCAL_BIN is).
  if has go; then ok "go already installed ($(go version | awk '{print $3}'))"; return 0; fi
  info "Installing Go"
  local ver url
  ver="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"
  [ -n "$ver" ] || { warn "could not resolve latest go version"; return 1; }
  url="https://go.dev/dl/${ver}.linux-amd64.tar.gz"
  rm -rf "$GO_ROOT"
  mkdir -p "$(dirname "$GO_ROOT")"
  if fetch_archive "$url" tar.gz _install_go; then
    ln -sf "$GO_ROOT/bin/go" "$LOCAL_BIN/go"
    ln -sf "$GO_ROOT/bin/gofmt" "$LOCAL_BIN/gofmt"
    ok "go installed ($ver)"
  else
    warn "failed to install go"; return 1
  fi
}
_install_go() { mv "$1/go" "$GO_ROOT"; }

install_node() {
  info "Installing nvm + Node.js"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    if [ -d "$NVM_DIR/.git" ]; then
      git -C "$NVM_DIR" fetch --tags -q origin || true
    else
      git clone -q https://github.com/nvm-sh/nvm.git "$NVM_DIR" || { warn "failed to clone nvm"; return 1; }
    fi
    local tag
    tag="$(git -C "$NVM_DIR" describe --abbrev=0 --tags 2>/dev/null)"
    [ -n "$tag" ] && git -C "$NVM_DIR" checkout -q "$tag"
  fi
  # shellcheck disable=SC1091
  export NVM_DIR; . "$NVM_DIR/nvm.sh"
  if nvm install "$NODE_VERSION" && nvm alias default "$NODE_VERSION" >/dev/null 2>&1; then
    ok "node installed ($(node -v 2>/dev/null))"
  else
    warn "failed to install node"; return 1
  fi
}

install_pnpm() {
  if has pnpm; then ok "pnpm already installed"; return 0; fi
  info "Installing pnpm"
  if curl -fsSL https://get.pnpm.io/install.sh | env SHELL="$(command -v bash)" sh -; then
    ok "pnpm installed (~/.local/share/pnpm)"
  else
    warn "failed to install pnpm"; return 1
  fi
}

install_sheldon() {
  if has sheldon; then ok "sheldon already installed"; return 0; fi
  info "Installing sheldon (zsh plugin manager)"
  if curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
      | bash -s -- --repo rossmacarthur/sheldon --to "$LOCAL_BIN"; then
    ok "sheldon installed"
  else
    warn "failed to install sheldon"; return 1
  fi
}

install_starship() {
  if has starship; then ok "starship already installed"; return 0; fi
  info "Installing starship"
  if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"; then
    ok "starship installed"
  else
    warn "failed to install starship"; return 1
  fi
}

install_pixi() {
  if has pixi; then ok "pixi already installed"; return 0; fi
  info "Installing pixi"
  if curl -fsSL https://pixi.sh/install.sh | bash; then
    ok "pixi installed (~/.pixi/bin)"
  else
    warn "failed to install pixi"; return 1
  fi
}

install_uv() {
  if has uv; then ok "uv already installed"; return 0; fi
  info "Installing uv"
  if curl -LsSf https://astral.sh/uv/install.sh | sh; then
    ok "uv installed (~/.local/bin)"
  else
    warn "failed to install uv"; return 1
  fi
}

install_ytdlp() {
  if has yt-dlp; then ok "yt-dlp already installed"; return 0; fi
  info "Installing yt-dlp"
  if curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
      -o "$LOCAL_BIN/yt-dlp"; then
    chmod a+rx "$LOCAL_BIN/yt-dlp"
    ok "yt-dlp installed (ffmpeg from base packages)"
  else
    warn "failed to install yt-dlp"; return 1
  fi
}

install_cica_font() {
  if ls "$FONT_DIR"/Cica*.ttf >/dev/null 2>&1; then
    ok "Cica font already installed"; return 0
  fi
  info "Installing Cica font"
  local url
  url="$(latest_asset_url miiton/Cica '\.zip$' | grep -iv 'with_emoji' | head -n1)"
  [ -n "$url" ] || url="$(latest_asset_url miiton/Cica '\.zip$')"
  [ -n "$url" ] || { warn "could not find Cica release"; return 1; }
  fetch_archive "$url" zip _install_cica && ok "Cica font installed" || { warn "failed to install Cica"; return 1; }
}
_install_cica() {
  find "$1" -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
}

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || { warn "zsh not found"; return 1; }
  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "default shell is already zsh"; return 0
  fi
  info "Setting default shell to zsh"
  if chsh -s "$zsh_path" 2>/dev/null || sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "default shell set to zsh"
  else
    warn "failed to change default shell (run: chsh -s $zsh_path)"; return 1
  fi
}

# ----------------------------------------------------------------------------
# Run
# ----------------------------------------------------------------------------
ALL_STEPS=(
  setup_prepare
  install_base_packages
  link_ubuntu_aliases
  install_gh
  setup_zdotdir
  install_rust
  install_bob_and_neovim
  install_eza
  install_fzf
  install_zoxide
  install_yazi
  install_go
  install_node
  install_pnpm
  install_sheldon
  install_starship
  install_pixi
  install_uv
  install_ytdlp
  install_cica_font
  set_default_shell
)

main() {
  local steps=()
  if [ "$#" -gt 0 ]; then
    steps=("$@")
  else
    steps=("${ALL_STEPS[@]}")
  fi

  setup_prepare  # always prepare PATH/dirs first

  local failed=() step
  for step in "${steps[@]}"; do
    [ "$step" = "setup_prepare" ] && continue
    if ! "$step"; then
      failed+=("$step")
    fi
  done

  echo
  info "Bootstrap complete"
  if [ "${#failed[@]}" -gt 0 ]; then
    warn "failed steps: ${failed[*]}"
  fi

  cat <<'EOF'

--- Next steps ----------------------------------------------------------
  * Log in again, or run `exec zsh`, to load the new configuration.
  * Ensure these are on PATH (handled by ~/.config/zsh):
      $HOME/.local/bin
      $HOME/.local/share/bob/nvim-bin   (Neovim managed by bob)
      $HOME/.pixi/bin                   (pixi)
      $HOME/.cargo/bin                  (rust)
  * Open `nvim` once: lazy.nvim, Mason LSPs/formatters and Treesitter
    parsers install on first launch (node is required and now installed).
  * For private repos, authenticate first with `gh auth login`.
  * WSL: also install Cica on the Windows side and select it as the
    terminal font (Linux-side fonts are not used by Windows terminals).
------------------------------------------------------------------------
EOF
}

main "$@"
