# shellcheck shell=bash
# Generate the locales zsh/.zshenv exports.
#
# .zshenv sets LANG=ja_JP.UTF-8. If that locale does not exist, every subprocess
# warns "Cannot set LC_CTYPE to default locale" and manpath prints an error on
# each shell start.
#
# Two routes, in order of preference:
#   1. system-wide locale-gen, which needs root
#   2. localedef into $XDG_DATA_HOME/locale, which does not
#
# Route 2 pairs with the LOCPATH guard in .zshenv, and that guard is why this
# step removes the per-user copy once a system locale exists: glibc searches
# LOCPATH exclusively and stops consulting /usr/lib/locale, so a stale per-user
# directory would mask the system locales rather than supplement them.

LOCALES=(ja_JP.UTF-8 en_US.UTF-8)
USER_LOCALE_DIR="$XDG_DATA_HOME/locale"

locale_present() {
  # locale -a prints them normalised, e.g. ja_JP.utf8.
  local want="${1%.UTF-8}"
  locale -a 2>/dev/null | grep -qiE "^${want}\.(utf8|UTF-8)$"
}

all_locales_present() {
  local l
  for l in "${LOCALES[@]}"; do locale_present "$l" || return 1; done
}

step_locale() {
  if all_locales_present; then
    ok "${LOCALES[*]} already available"
    # Nothing to generate, but a leftover per-user directory would still shadow
    # the system ones through LOCPATH.
    if [ -d "$USER_LOCALE_DIR" ] && locale -a 2>/dev/null | grep -qi '^ja_JP'; then
      info "removing the redundant per-user locale directory"
      run rm -rf "$USER_LOCALE_DIR"
    fi
    return 0
  fi

  if [ "${SUDO_OK:-0}" = 1 ]; then
    info "generating locales system-wide"
    if apt_group_locales && run_sudo locale-gen "${LOCALES[@]}" && run_sudo update-locale; then
      run rm -rf "$USER_LOCALE_DIR"
      return 0
    fi
    warn "system locale-gen failed; falling back to a per-user locale"
  fi

  has localedef || { warn "localedef not found (apt: locales)"; return 1; }
  info "compiling locales into $USER_LOCALE_DIR (no root required)"
  run mkdir -p "$USER_LOCALE_DIR"
  local l rc=0
  for l in "${LOCALES[@]}"; do
    run localedef -i "${l%.UTF-8}" -f UTF-8 "$USER_LOCALE_DIR/$l" || { warn "localedef failed for $l"; rc=1; }
  done
  [ "$rc" = 0 ] && info "zsh/.zshenv picks this up via LOCPATH"
  return "$rc"
}

apt_group_locales() {
  dpkg-query -W -f='${Status}' locales 2>/dev/null | grep -q 'ok installed' && return 0
  apt_refresh && DEBIAN_FRONTEND=noninteractive run_sudo apt-get install -y locales
}

check_locale() {
  local id="$1" l missing=""
  for l in "${LOCALES[@]}"; do locale_present "$l" || missing+=" $l"; done
  if [ -n "$missing" ] && [ ! -d "$USER_LOCALE_DIR" ]; then
    say "$id" FAIL "missing:$missing -- every subprocess will warn about LC_CTYPE"
  elif [ -n "$missing" ]; then
    say "$id" OK "via LOCPATH=$USER_LOCALE_DIR"
  elif [ -d "$USER_LOCALE_DIR" ]; then
    say "$id" WARN "system locales exist but $USER_LOCALE_DIR also does; LOCPATH will mask them"
  else
    say "$id" OK "${LOCALES[*]} system-wide"
  fi
}

register locale yes "generate the ja_JP/en_US locales zsh/.zshenv expects" step_locale check_locale
