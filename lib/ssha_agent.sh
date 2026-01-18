#!/usr/bin/env bash
set -euo pipefail

ssha::agent_status() {
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "${SSH_AUTH_SOCK}" ]]; then
    echo "[OK] ssh-agent: running (SSH_AUTH_SOCK=${SSH_AUTH_SOCK})"
    return 0
  fi
  echo "[WARN] ssh-agent: NOT running (or not visible in this shell)."
  return 1
}

ssha::agent_start() {
  # Start agent and export vars into current shell context via eval
  # shellcheck disable=SC1090
  eval "$(ssh-agent -s)" >/dev/null
  if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo "[OK] ssh-agent started (SSH_AUTH_SOCK=${SSH_AUTH_SOCK})"
    return 0
  fi
  echo "[ERROR] ssh-agent failed to start"
  return 1
}

ssha::agent_ensure() {
  if ssha::agent_status >/dev/null 2>&1; then
    echo "[OK] ssh-agent already available."
    return 0
  fi
  ssha::agent_start
}

ssha::agent_add_key() {
  local keypath="$1"
  if [[ ! -f "${keypath}" ]]; then
    echo "[ERROR] Key not found: ${keypath}"
    return 1
  fi
  ssh-add "${keypath}" >/dev/null
  echo "[OK] Key added to agent: ${keypath}"
}
