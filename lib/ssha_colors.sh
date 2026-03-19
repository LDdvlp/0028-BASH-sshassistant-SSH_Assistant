#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Gestion des couleurs
# -----------------------------------------------------------------------------
# Désactive les couleurs si :
# - pas de TTY
# - variable NO_COLOR définie
# - SSHA_NO_COLOR=1
# -----------------------------------------------------------------------------

ssha::colors_enabled() {
  [[ -t 1 ]] || return 1
  [[ -z "${NO_COLOR:-}" ]] || return 1
  [[ "${SSHA_NO_COLOR:-0}" != "1" ]] || return 1
  return 0
}

# -----------------------------------------------------------------------------
# Couleurs de base (ANSI)
# -----------------------------------------------------------------------------

ssha::c_reset() {
  if ssha::colors_enabled; then
    printf '\033[0m'
  fi
}

ssha::c_orange() {
  if ssha::colors_enabled; then
    printf '\033[38;5;208m'
  fi
}

ssha::c_green() {
  if ssha::colors_enabled; then
    printf '\033[38;5;46m'
  fi
}

ssha::c_blue() {
  if ssha::colors_enabled; then
    printf '\033[38;5;39m'
  fi
}

ssha::c_yellow() {
  if ssha::colors_enabled; then
    printf '\033[38;5;226m'
  fi
}

ssha::c_red() {
  if ssha::colors_enabled; then
    printf '\033[38;5;196m'
  fi
}

# -----------------------------------------------------------------------------
# Helpers affichage
# -----------------------------------------------------------------------------

ssha::print_orange_file() {
  local filepath="$1"
  [[ -f "${filepath}" ]] || return 1

  ssha::c_orange
  cat "${filepath}"
  ssha::c_reset
}

ssha::print_green() {
  ssha::c_green
  printf '%s' "$*"
  ssha::c_reset
}

ssha::print_blue() {
  ssha::c_blue
  printf '%s' "$*"
  ssha::c_reset
}

ssha::print_yellow() {
  ssha::c_yellow
  printf '%s' "$*"
  ssha::c_reset
}

ssha::println_green() {
  ssha::c_green
  printf '%s\n' "$*"
  ssha::c_reset
}

ssha::println_blue() {
  ssha::c_blue
  printf '%s\n' "$*"
  ssha::c_reset
}

# -----------------------------------------------------------------------------
# Tags visuels
# -----------------------------------------------------------------------------

ssha::tag_ok() {
  ssha::c_green
  printf '[OK]'
  ssha::c_reset
}

ssha::tag_warn() {
  ssha::c_yellow
  printf '[WARN]'
  ssha::c_reset
}

ssha::tag_err() {
  ssha::c_red
  printf '[ERROR]'
  ssha::c_reset
}

# -----------------------------------------------------------------------------
# Logs standardisés
# -----------------------------------------------------------------------------

ssha::log_ok() {
  ssha::tag_ok
  printf ' %s\n' "$*"
}

ssha::log_warn() {
  ssha::tag_warn
  printf ' %s\n' "$*"
}

ssha::log_err() {
  ssha::tag_err
  printf ' %s\n' "$*"
}