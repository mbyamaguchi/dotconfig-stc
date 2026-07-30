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

  # Check the builder before using it. `tree-sitter build` failing leaves nvim
  # exiting 0, so the only evidence was a Node stack trace inside the output the
  # `tail -3` below discards -- the run reported OK and the editor had no
  # highlighting at all.
  runs tree-sitter || warn "tree-sitter does not run; parsers will not build (fix: bs.sh --only pnpm)"

  # nvim-treesitter's rewritten branch has no :TSUpdateSync, and its install() is
  # asynchronous -- a headless nvim exits while parsers are still downloading. So
  # call it directly and block. The language list lives in
  # nvim/lua/config/treesitter-parsers.lua, which lazy.lua reads too, so there is
  # only one copy of it.
  info "building treesitter parsers (blocking until done)"
  nvim --headless \
    "+lua require('nvim-treesitter').install(require('config.treesitter-parsers')):wait(900000)" \
    +qa 2>&1 | tail -3 || warn "treesitter install reported problems"

  # Count the result rather than trust the exit status, for the same reason.
  local built
  built=$(find "$XDG_DATA_HOME/nvim/site/parser" -name '*.so' 2>/dev/null | wc -l)
  if [ "$built" -eq 0 ]; then
    warn "no treesitter parsers were built -- run bs.sh doctor"
  else
    info "$built treesitter parsers built"
  fi

  # mason-lspconfig's ensure_installed runs on startup, so one more launch pulls
  # the LSP servers. Their versions are NOT pinned -- Mason has no lockfile; see
  # bootstrap/README.md.
  info "letting Mason install the LSP servers listed in lua/config/plugins/lsp.lua"
  nvim --headless +qa 2>&1 | tail -3 || true
}

register nvim         no "Neovim at the pinned version, via bob"          step_neovim
register nvim:plugins no "restore plugins from lazy-lock.json (slow)"     step_nvim_plugins