# shellcheck shell=bash
# Prebuilt binaries from GitHub releases, driven entirely by tools.tsv.
#
# One step is registered per manifest row, so `--only tool:eza` works, `list`
# shows every tool, and adding a tool means adding a line to tools.tsv and
# nothing else. This file replaced six copies of the same download-extract-
# install code in the old bs.sh.

# Install one row. Called as `tool_install <name>`; the row is re-read here
# rather than closed over, so a manifest edit takes effect without touching this.
tool_install() {
  local name="$1" row ref min repo asset install
  row=$(manifest_row tools.tsv "$name") || true
  [ -n "$row" ] || die "tools.tsv: no row named $name"
  IFS=$'\t' read -r name ref min repo asset install <<<"$row"

  arch_require

  # `font` rows are checked by presence, not by --version.
  if [ "$install" = font ]; then
    tool_install_font "$name" "$ref" "$repo" "$asset"
    return
  fi

  local -a bins=()
  IFS=, read -r -a bins <<<"${install#bin:}"
  local probe="${bins[0]}"

  # Two conditions, not one. The version has to match, *and* the binary has to
  # be the copy we own in ~/.local/bin -- otherwise a distro package of the same
  # version satisfies the check forever and the machine never actually converges
  # on the manifest. (On this machine eza, fzf, yazi and zoxide all came from a
  # third-party apt repo that a fresh install would not have, at versions that
  # happened to match, so nothing was ever installed here.)
  if [ -x "$LOCAL_BIN/$probe" ] && ! needs_install "$probe" "$ref" "$min"; then
    ok "$probe $(version_of "$probe") already matches $ref"
    return 0
  fi
  if ! [ -x "$LOCAL_BIN/$probe" ] && has "$probe"; then
    info "$probe exists at $(command -v "$probe"); installing the pinned copy to shadow it"
  fi

  local url tmp
  url=$(release_url "$repo" "$ref" "$(expand_asset "$asset" "$ref")")
  info "$url"
  tmp=$(mktmp)

  # A bare binary (no archive) is served as-is; yt-dlp ships one.
  case "$url" in
    *.tar.gz|*.tgz|*.tar.xz|*.txz|*.zip)
      local file="$tmp/${url##*/}"
      download "$url" "$file"
      verify_sha256 "$file" "$url"
      extract "$file" "$tmp"
      install_bins "$tmp" "${bins[@]}"
      ;;
    *)
      download "$url" "$tmp/$probe"
      verify_sha256 "$tmp/$probe" "$url"
      run install -m 0755 "$tmp/$probe" "$LOCAL_BIN/$probe"
      info "$LOCAL_BIN/$probe"
      ;;
  esac

  # Report what we actually got. hash -r because the shell may have cached an
  # older copy from a different directory earlier in this same run.
  if [ "${DRY_RUN:-0}" != 1 ]; then
    hash -r 2>/dev/null || true
    info "$probe is now $(version_of "$probe")"
  fi
}

tool_install_font() {
  local name="$1" ref="$2" repo="$3" asset="$4"
  # Fonts have no --version; a matching family already present is good enough.
  # (The old code tried to prefer the no-emoji build with
  # `grep -iv with_emoji`, which matches nothing -- "without_emoji" does not
  # contain "with_emoji" -- so it silently took whichever came first. The build
  # is named explicitly in tools.tsv now.)
  local pattern
  pattern=$(printf '%s' "$name" | sed 's/^./\U&/')
  if compgen -G "$FONT_DIR/$pattern*.ttf" >/dev/null 2>&1; then
    ok "$pattern font already installed"
    return 0
  fi
  local url tmp file
  url=$(release_url "$repo" "$ref" "$(expand_asset "$asset" "$ref")")
  info "$url"
  tmp=$(mktmp)
  file="$tmp/${url##*/}"
  download "$url" "$file"
  extract "$file" "$tmp"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    dry "cp *.ttf -> $FONT_DIR && fc-cache -f"
    return 0
  fi
  find "$tmp" -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || warn "fc-cache failed; fonts may not be visible yet"
  info "$(find "$FONT_DIR" -name "$pattern*.ttf" | wc -l) $pattern faces in $FONT_DIR"
}

tool_check() {
  local id="$1" name="${1#tool:}" row ref min install probe cur where
  row=$(manifest_row tools.tsv "$name")
  IFS=$'\t' read -r name ref min _repo _asset install <<<"$row"

  if [ "$install" = font ]; then
    local pattern
    pattern=$(printf '%s' "$name" | sed 's/^./\U&/')
    if compgen -G "$FONT_DIR/$pattern*.ttf" >/dev/null 2>&1; then
      say "$id" OK "$pattern installed ($ref pinned)"
    else
      say "$id" WARN "$pattern font missing"
    fi
    return 0
  fi

  probe="${install#bin:}"; probe="${probe%%,*}"
  if ! has "$probe"; then
    say "$id" WARN "not installed (pinned $ref)"
    return 0
  fi
  cur=$(version_of "$probe")
  where=$(command -v "$probe")

  # Naming the directory matters: a copy outside ~/.local/bin means something
  # else -- usually an apt package -- is standing in for the pinned one, which is
  # how this machine drifted from what a fresh install would produce.
  case "$where" in
    "$LOCAL_BIN"/*) ;;
    *) say "$id" WARN "$cur from $where, not the pinned copy in ~/.local/bin"; return 0 ;;
  esac

  if [ "$ref" = latest ]; then
    if [ "$min" = - ] || ver_ge "$cur" "$min"; then
      say "$id" OK "$cur (floats; min $min)"
    else
      say "$id" WARN "$cur is below the required $min"
    fi
  elif [ "$cur" = "$(ref_version "$ref")" ]; then
    say "$id" OK "$cur"
  else
    say "$id" WARN "pinned $(ref_version "$ref"), installed $cur"
  fi
}

# Register one step per row.
_register_tool() {
  local name="$1" ref="$2"
  register "tool:$name" no "install $name $ref" "tool_install $name" "tool_check"
}
manifest_each tools.tsv _register_tool
