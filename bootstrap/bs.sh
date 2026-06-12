#!/usr/bin/env bash

set -uo pipefail

# settings
DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:mbyamaguchi/dotconfig-stc.git}"

NVIM_VERSION="${NVIM_VERSION:-stable}"

LOCAL_BIN="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts"

# logging helper
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s \n' "$*" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

latest_asset_url() {
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | cut -d'"' -f4 \
    | grep -E "$pattern" \
    | head -n1
}


setup_prepare() {
  info "Setting directories and PATH"
  mkdir -p "$LOCAL_BIN" "FONT_DIR"
  export PATH="$LOCAL_BIN:$PATH"
  export DEBIAN_FRONTEND=noninteractive
  ok "Completed!!!"
}

install_base_packages() {
  info "install apt basic packages"
  if ! sudo apt-get update -y; then
    warn "failed to run apt update"; return 1
  fi
  if sudo apt-get install -y \\
    git wget curl zsh unzip tar xz-utils \
      build-essential ca-certificates gnupg fontconfig \
      bat fd-find; then
    ok "installed packages"
  else
    warn "failed to install packages"; return 1
  fi

}

install_gh() {
  if has gh; then ok "gh already installed"; return 0; fi
  info "install GitHub CLI (gh)"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  if sudo apt-get update -y && sudo apt-get install -y gh; then
    ok "installed gh"
  else
    warn "failed to install gh"; return 1
  fi
}

clone_dotfiles() {
  info "get ~/.config ($DOTFILES_REPO)"

  if [ -d "$HOME/.config/.git" ]; then
    if git -C "%HOME/.config" pull --ff-only; then
      ok "updated ~/.config"
    else
      warn "failed to update ~/.config"
    fi
    return 0
  fi

  local branch
  branch="$(git ls-remote --symref "$DOTFILES_REPO" HEAD 2>/dev/null \
    | awk '/^ref:/ { sub("refs/heads/","",$2); print $2; exit}')"
  [ -n "$branch" ] || branch="main"

  mkdir -p "$HOME/.config"
  git -C "$HOME/.config" init -q
  if git -C "$HOME/.config" remote get-url origin >/dev/null 2>&a; then
    git -C "$HOME/.config" remote set-url origin "$DOTFILES_REPO"
  else
    git -C "$HOME/.config" remote add origin "$DOTFILES_REPO"
  fi

  if ! git -C "$HOME/.config" fetch -q origin "$branch"; then
    warn "failed to get repository"
    return 1
  fi

  git -C "$HOME/.config" checkout -f -B "$branch" "origin/$branch"
  git -C "$HOME/.config" submodule update --init --recursive 2>/dev/null || true

  ok "get ~/.config (branch: $branch)"
}

setup_zdotdir() {
  local zshenv="/etc/zsh/zshenv"
  info "set ZDOTDIR to $zshenv"
  if [ ! -e "$zshenv" ]; then
    sudo mkdir -p /etc/zsh
    sudo touch "$zshenv"
  fi
  if sudo grep -q 'ZDOTDIR' "$zshenv"; then
    ok "ZDOTDIR already set"
  else
    echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a "$zshenv" >/dev/null
    ok "added ZDOTDIR"
  fi
}

install_cica_font() {
  if ls "$FONT_DIR"/Cica*.ttf >/dev/null 2>&1; then
    ok "Cica font already exists"; return 0
  fi
  info "Get Cica font"
  local url tmp
  url="$(latest_asset_url miiton/Cica '\.zip$' | grep -iv 'with_emoji' | head -n1)"
  [ -n "$url" ] || url="$(latest_asset_url miiton/Cica '\.zip$')"
  if [ -z "$url" ]; then
    warn "Failed to get url for Cica font"; return 1
  fi
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/cica.zip" && unzip -q -o "$tmp/cica.zip" -d "$tmp/cica"; then
    find "$tmp/cica" -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;
    fc-cache -f "$FONT_DIR" >/dev/null
    rm -rf "$tmp"
    ok "Got Cica font"
  else
    rm -rf "$tmp"
    warn "Failed to get Cica font"; return 1
  fi
}

install_bob_and_neovim() {
  local arch; arch="$(uname -m)"

  if has bob; then
    ok "bob already installed"
  else
    info "install bob"
    if [ "$arch" != "x86_64" ]; then
      warn "bob built binary is for x86_64 (current: $arch). consider 'cargo install bob-nvim'"
      return 1
    fi
    local url tmp
    url="$(latest_asset_url MordechaiHadad/bob 'bob-linux-x86_64\.zip$')"
    if [ -z "$url" ]; then
      warn "Failed to get url for bob"; return 1
    fi
    tmp="$(mktemp -d)"
    if curl -fsSL "$url" -o "$tmp/bob.zip" && unzip -q -o "$tmp/bob.zip" -d "$tmp"; then
      install -m 0755 "$(find "$tmp" -type f -name bob | head -n1)" "$LOCAL_BIN/bob"
      rm -rf "$tmp"
      ok "installed bob"
    else
      rm -rf "$tmp"
      warn "failed to install bob"; return 1
    fi
  fi

  info "install neovim ($NVIM_VERSION) with bob"
  if bob use "NVIM_VERSION"; then
    ok "installed Neovim (~/.local/share/bob/nvim-bin)"
  else
    warn "failed to install Neovim"; return 1
  fi
}

install_eza() {
  if has eza; then ok "eza already installed"; return 0; fi
  info "install eza"
  local arch; arch="$(uname -m)"
  if [ "$arch" != "x86_64" ]; then
    warn "installation of eza in this script is for x86_64 (currently: $arch)"; return 1
  fi
  local url tmp
  url="$(latest_asset_url eza-community/eza 'eza_x86_64-unknown-linux-gnu\.tar\.gz$')"
  if [ -z "$url" ]; then
    warn "failed to get url for eza"; return 1
  fi
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/eza.tar.gz" && tar -xzf "$tmp/eza.tar.gz" -C "$tmp"; then
    install -m 0755 "$(find "$tmp" -type f -name eza | head -n1)" "$LOCAL_BIN/eza"
    rm -rf "$tmp"
    ok "installed eza"
  else
    rm -rf "$tmp"
    warn "failed to install eza"; return 1
  fi
}

install_sheldon() {
  if has sheldon; then ok "sheldon already exists"; return 0; fi
  info "install sheldon (zsh plugin manager)"
  if curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to "$LOCAL_BIN"; then
    ok "installed sheldon"
  else
    warn "failed to install sheldon"; return 1
  fi
    
}

install starship() {
  if has starship; then ok "starship already exists"; return 0; fi
  info "install starship"
  if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"; then
    ok "installed starship"
  else
    warn "failed to install starship"; return 1
  fi
}

install_pixi() {
  if has pixi; then ok "pixi は導入済みです"; return 0; fi
  info "pixi を導入します"
  if curl -fsSL https://pixi.sh/install.sh | bash; then
    ok "pixi を導入しました（既定の導入先: ~/.pixi/bin）"
  else
    warn "pixi の導入に失敗しました"; return 1
  fi
}
 
install_uv() {
  if has uv; then ok "uv は導入済みです"; return 0; fi
  info "uv を導入します"
  if curl -LsSf https://astral.sh/uv/install.sh | sh; then
    ok "uv を導入しました（既定の導入先: ~/.local/bin）"
  else
    warn "uv の導入に失敗しました"; return 1
  fi
}

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  if [ -z "$zsh_path" ]; then
    warn "zsh not found"; return 1
  fi
  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "default shell is already zsh"; return 0
  fi
  info "switch default shell to zsh"
  if chsh -s "$zsh_path" 2>/dev/null || sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "default shell set to be zsh"
  else
    warn "failed"
    return 1
  fi

}


# execution

main() {
  if [ "$DOTFILES_REPO" = "https://github.com/USERNAME/REPO.git" ]; then
    warn "DOTFILES_REPO is still default. rewrite it."
    warn "You may use env var: DOTFILES_REPO=... ./bs.sh"
  fi

  setup_prepare

  local steps=(
    install_base_packages
    install_gh
    clone_dotfiles
    setup_zdotdir
    install_cica_font
    install_bob_and_neovim
    install_eza
    install_sheldon
    install_starship
    install_pixi
    install_uv
    set_default_shell
    )

    local failed=()
    local step
    for step in "${steps[@]}"; do
      if ! "$step"; then
        failed+=("$step")
      fi
    done

    echo "Completed setup"
    if [ "${#failed[@]}" -gt 0 ]; then
      warn "failed: ${failed[*]}"
    fi

    cat <<'EOF'

--- 次の手順をご確認ください -------------------------------------------
  * 一度ログインし直す（または `exec zsh` を実行）と各種設定が反映されます。
  * 以下が PATH に含まれているか、~/.config 側の設定でご確認ください:
      $HOME/.local/bin
      $HOME/.local/share/bob/nvim-bin   (bob 管理の Neovim)
      $HOME/.pixi/bin                   (pixi)
  * bat / fd-find の実行ファイル名は Ubuntu では batcat / fdfind です。
    必要に応じて ~/.config 側で alias（bat / fd）を設定してください。
  * private リポジトリの場合は事前に `gh auth login` で認証してください。
  * WSL では Cica を Windows 側にもインストールし、ターミナルのフォントに
    指定する必要があります（Linux 側のフォントは Windows ターミナルには
    反映されません）。
------------------------------------------------------------------------
EOF
}

main "$@"
