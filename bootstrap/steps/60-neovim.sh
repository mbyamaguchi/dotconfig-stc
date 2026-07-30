# shellcheck shell=bash
# Neovim, and its plugin state.
#
# bob manages the nvim binary; lazy.nvim manages plugins from a lockfile that is
# tracked in this repo. Together they are what makes the editor reproducible --
# `bob use` alone would still give you whatever plugin HEADs happened to exist.

step_neovim() {
  local ref; ref=$(rt_ref nvim)
  has bob || step_skip "bob is not installed (run: bs.sh --only tool:bob)"

  local cur=""
  has nvim && cur=$(version_of nvim)
  if [ "$cur" = "$(ref_version "$ref")" ]; then
    ok "neovim $cur already matches $ref"
    return 0
  fi

  info "bob use $ref"
  run bob use "$ref"
  if [ "${DRY_RUN:-0}" != 1 ]; then
    # bob creates $XDG_DATA_HOME/bob/nvim-bin on first use, so it was not on PATH
    # when the run started and `nvim` is not yet findable without this.
    path_refresh
    info "neovim is now $(version_of nvim) at $(command -v nvim)"
  fi
}

check_neovim() {
  local id="$1" ref cur; ref=$(rt_ref nvim)
  if ! has nvim; then say "$id" WARN "not installed (pinned $ref)"; return 0; fi
  cur=$(version_of nvim)
  if [ "$cur" = "$(ref_version "$ref")" ]; then
    say "$id" OK "$cur ($(command -v nvim))"
  else
    say "$id" WARN "pinned $(ref_version "$ref"), installed $cur"
  fi
}

# ----------------------------------------------------------------------------
# Plugins
# ----------------------------------------------------------------------------
# `Lazy! restore` moves the plugin tree *to* the tracked lockfile, which is the
# reproducible direction -- `sync` or `update` would move the lockfile instead.
# It also performs the initial clone, so there is no separate install step.
#
# Order matters: treesitter parsers are compiled from whatever nvim-treesitter
# commit is checked out, so restore has to run first.
step_nvim_plugins() {
  has nvim || step_skip "neovim is not installed"
  local lock="$CONFIG_DIR/nvim/lazy-lock.json"
  [ -r "$lock" ] || step_skip "nvim/lazy-lock.json is missing"

  if [ "${DRY_RUN:-0}" = 1 ]; then
    dry "nvim --headless '+Lazy! restore' +qa   # $(jq 'keys|length' "$lock" 2>/dev/null) plugins"
    dry "nvim --headless '+TSUpdateSync' +qa"
    return 0
  fi

  info "restoring plugins from lazy-lock.json (first run clones them; this is slow)"
  nvim --headless '+Lazy! restore' +qa 2>&1 | tail -3 || warn "Lazy restore reported problems"

  # nvim-treesitter's rewritten branch has no :TSUpdateSync, and its install() is
  # asynchronous -- a headless nvim exits while parsers are still downloading. So
  # call it directly and block. The language list lives in
  # nvim/lua/config/treesitter-parsers.lua, which lazy.lua reads too, so there is
  # only one copy of it.
  info "building treesitter parsers (blocking until done)"
  nvim --headless \
    "+lua require('nvim-treesitter').install(require('config.treesitter-parsers')):wait(900000)" \
    +qa 2>&1 | tail -3 || warn "treesitter install reported problems"

  # mason-lspconfig's ensure_installed runs on startup, so one more launch pulls
  # the LSP servers. Their versions are NOT pinned -- Mason has no lockfile; see
  # bootstrap/README.md.
  info "letting Mason install the LSP servers listed in lua/config/plugins/lsp.lua"
  nvim --headless +qa 2>&1 | tail -3 || true
}

check_nvim_plugins() {
  local id="$1" lock="$CONFIG_DIR/nvim/lazy-lock.json" want have
  [ -r "$lock" ] || { say "$id" WARN "lazy-lock.json missing"; return 0; }
  want=$(jq 'keys|length' "$lock" 2>/dev/null || echo '?')
  have=$(find "$XDG_DATA_HOME/nvim/lazy" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
  if [ "$have" = 0 ]; then
    say "$id" WARN "no plugins installed ($want in the lockfile)"
  elif [ "$want" != '?' ] && [ "$have" -lt "$want" ]; then
    say "$id" WARN "$have of $want plugins installed"
  else
    say "$id" OK "$have plugins"
  fi

  # Counting plugin directories is not enough: parsers are built by shelling out
  # to `tree-sitter build`, and when that binary is missing every build fails
  # while the plugin tree still looks complete. That is exactly how a container
  # run reported OK with zero syntax highlighting.
  local pdir="$XDG_DATA_HOME/nvim/site/parser" pwant phave
  pwant=$(grep -cE '^\s*"' "$CONFIG_DIR/nvim/lua/config/treesitter-parsers.lua" 2>/dev/null || echo 0)
  phave=$(find "$pdir" -maxdepth 1 -name '*.so' 2>/dev/null | wc -l)
  if [ "$phave" = 0 ]; then
    say nvim:parsers WARN "no treesitter parsers in $pdir (is tree-sitter on PATH?)"
  elif [ "$pwant" -gt 0 ] && [ "$phave" -lt "$pwant" ]; then
    say nvim:parsers WARN "$phave parsers built, $pwant requested"
  else
    say nvim:parsers OK "$phave parsers"
  fi

  # The tools conform.nvim and nvim-lint invoke by name. Mason may provide them,
  # apt may, cargo may -- what matters is that the editor can find them.
  local t missing=""
  for t in clangd clang-format stylua rustfmt; do has "$t" || missing+=" $t"; done
  if [ -n "$missing" ]; then
    say nvim:tools WARN "not on PATH:$missing"
  else
    say nvim:tools OK "clangd, clang-format, stylua, rustfmt"
  fi
}

register nvim         no "Neovim at the pinned version, via bob"          step_neovim      check_neovim
register nvim:plugins no "restore plugins from lazy-lock.json (slow)"     step_nvim_plugins check_nvim_plugins
