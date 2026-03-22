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
  [[ -z "${NO_COLOR:-}" ]] || return 1
  [[ "${SSHA_NO_COLOR:-0}" != "1" ]] || return 1
  return 0
}

# -----------------------------------------------------------------------------
# Couleurs de base (ANSI)
# -----------------------------------------------------------------------------

ssha::c_reset() { printf '\033[0m'; }
ssha::c_orange() { printf '\033[38;5;208m'; }
ssha::c_green() { printf '\033[38;5;46m'; }
ssha::c_blue() { printf '\033[38;5;39m'; }
ssha::c_yellow() { printf '\033[38;5;226m'; }
ssha::c_red() { printf '\033[38;5;196m'; }

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
ssha::tag_info() {
  ssha::c_blue
  printf '[INFO]'
  ssha::c_reset
}

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
  printf '[KO]'
  ssha::c_reset
}

# -----------------------------------------------------------------------------
# Logs standardisés
# -----------------------------------------------------------------------------

ssha::log_ok() {
  ssha::c_green
  printf '[OK] %s\n' "$*" >&2
  ssha::c_reset
}

ssha::log_warn() {
  ssha::c_yellow
  printf '[WARN] %s\n' "$*" >&2
  ssha::c_reset
}

ssha::log_err() {
  ssha::c_red
  printf '[KO] %s\n' "$*" >&2
  ssha::c_reset
}

ssha::log_info() {
  ssha::c_blue
  printf '[INFO] %s\n' "$*" >&2
  ssha::c_reset
}