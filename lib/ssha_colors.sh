#!/usr/bin/env bash
set -euo pipefail

# Disable colors if:
# - output is not a TTY
# - user explicitly disables (NO_COLOR is a common convention)
# - user forces off (SSHA_NO_COLOR=1)
ssha::colors_enabled() {
  [[ -t 1 ]] || return 1
  [[ -z "${NO_COLOR:-}" ]] || return 1
  [[ "${SSHA_NO_COLOR:-0}" != "1" ]] || return 1
  return 0
}

# ----- base color helpers -----
ssha::c_reset()  { ssha::colors_enabled && printf '\033[0m' || true; }

# 256-color "orange" (close to #ff8700)
ssha::c_orange() { ssha::colors_enabled && printf '\033[38;5;208m' || true; }
ssha::c_reset()  { ssha::colors_enabled && printf '\033[0m'          || true; }

ssha::print_orange_file() {
  local filepath="$1"
  [[ -f "${filepath}" ]] || return 1
  ssha::c_orange
  cat "${filepath}"
  ssha::c_reset
}

ssha::c_orange() { ssha::colors_enabled && printf '\033[38;5;208m' || true; }
ssha::c_green()  { ssha::colors_enabled && printf '\033[38;5;46m'  || true; }  # vivid green
ssha::c_blue()   { ssha::colors_enabled && printf '\033[38;5;39m'  || true; }  # bright blue
ssha::c_yellow() { ssha::colors_enabled && printf '\033[38;5;226m' || true; }  # bright yellow

# ----- themed print helpers -----
ssha::print_orange_file() { local f="$1"; [[ -f "$f" ]] || return 1; ssha::c_orange; cat "$f"; ssha::c_reset; }
ssha::print_green()       { ssha::c_green;  printf '%s' "$*"; ssha::c_reset; }
ssha::print_blue()        { ssha::c_blue;   printf '%s' "$*"; ssha::c_reset; }
ssha::print_yellow()      { ssha::c_yellow; printf '%s' "$*"; ssha::c_reset; }
ssha::println_green()     { ssha::c_green;  printf '%s\n' "$*"; ssha::c_reset; }
ssha::println_blue()      { ssha::c_blue;   printf '%s\n' "$*"; ssha::c_reset; }

# ----- status tags -----
ssha::c_red() { ssha::colors_enabled && printf '\033[38;5;196m' || true; }

ssha::tag_ok() {
  ssha::c_green;  printf '[OK]';    ssha::c_reset
}

ssha::tag_warn() {
  ssha::c_yellow; printf '[WARN]';  ssha::c_reset
}

ssha::tag_err() {
  ssha::c_red;    printf '[ERROR]'; ssha::c_reset
}
 
ssha::log_ok()   { ssha::tag_ok;   echo " $*"; }
ssha::log_warn() { ssha::tag_warn; echo " $*"; }
ssha::log_err()  { ssha::tag_err;  echo " $*"; }
