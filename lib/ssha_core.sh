#!/usr/bin/env bash
set -euo pipefail

ssha::banner() {
  echo "=============================================="
  echo " SSH Assistant (v0.1.0-dev)"
  echo " Plateforme: ${SSHA_PLATFORM:-unknown}"
  echo "=============================================="
  echo
}

ssha::detect_platform() {
  # minimal: gitbash/msys/cygwin/linux
  local u
  u="$(uname -s 2>/dev/null || true)"
  case "${u}" in
    MINGW*|MSYS*) SSHA_PLATFORM="gitbash" ;;
    CYGWIN*)      SSHA_PLATFORM="cygwin" ;;
    Linux*)       SSHA_PLATFORM="linux" ;;
    Darwin*)      SSHA_PLATFORM="mac" ;;
    *)            SSHA_PLATFORM="unknown" ;;
  esac
  export SSHA_PLATFORM
}

ssha::prompt() {
  local label="$1"
  local default="${2:-}"
  local out
  if [[ -n "${default}" ]]; then
    read -r -p "${label} [${default}]: " out
    echo "${out:-$default}"
  else
    read -r -p "${label}: " out
    echo "${out}"
  fi
}

ssha::choose_encoding() {
  echo
  echo "Encodage / type de clé :"
  echo "1) ed25519 (recommandé)"
  echo "2) rsa (fallback, 4096 bits)"
  echo "3) ecdsa (P-256)"
  echo
  local choice
  choice="$(ssha::prompt "Choix" "1")"
  case "${choice}" in
    1) echo "ed25519" ;;
    2) echo "rsa" ;;
    3) echo "ecdsa" ;;
    *) echo "ed25519" ;;
  esac
}

ssha::ensure_ssh_dir() {
  local dir="${1}"
  mkdir -p "${dir}"
  chmod 700 "${dir}" 2>/dev/null || true
}

ssha::config_path() {
  echo "${SSHA_SSH_DIR}/config"
}

ssha::key_paths() {
  local enc="$1"
  local name="$2"
  local base="${SSHA_SSH_DIR}/${enc}_${name}"
  echo "${base}"$'\n'"${base}.pub"
}

ssha::run_ssh_keygen() {
  local enc="$1"
  local keypath="$2"
  local comment="$3"

  case "${enc}" in
    ed25519)
      ssh-keygen -t ed25519 -a 64 -f "${keypath}" -C "${comment}" -N ""
      ;;
    rsa)
      ssh-keygen -t rsa -b 4096 -f "${keypath}" -C "${comment}" -N ""
      ;;
    ecdsa)
      ssh-keygen -t ecdsa -b 256 -f "${keypath}" -C "${comment}" -N ""
      ;;
    *)
      ssh-keygen -t ed25519 -a 64 -f "${keypath}" -C "${comment}" -N ""
      ;;
  esac
}

ssha::remove_host_block() {
  # Remove an existing Host block for alias from config (simple, robust enough for v0.1)
  local cfg="$1"
  local alias="$2"

  [[ -f "${cfg}" ]] || return 0

  # awk state machine:
  # when we hit "Host <alias>" -> skip until next "Host " line
  awk -v a="${alias}" '
    BEGIN{skip=0}
    /^[[:space:]]*Host[[:space:]]+/{
      # new block begins
      if ($2==a) {skip=1; next}
      else {skip=0}
    }
    { if (!skip) print }
  ' "${cfg}" > "${cfg}.tmp"
  mv "${cfg}.tmp" "${cfg}"
}

ssha::append_host_block() {
  local cfg="$1"
  local alias="$2"
  local hostname="$3"
  local user="$4"
  local port="$5"
  local identity="$6"

  {
    echo
    echo "Host ${alias}"
    echo "  HostName ${hostname}"
    echo "  User ${user}"
    echo "  Port ${port}"
    echo "  IdentityFile ${identity}"
    echo "  IdentitiesOnly yes"
  } >> "${cfg}"
}

ssha::print_public_key() {
  local pub="$1"
  echo
  echo "----- CLE PUBLIQUE (${pub}) -----"
  echo
  cat "${pub}"
  echo
  echo "---------------------------------"
  echo
}

ssha::option_create_key_and_config() {
  local host_alias hostname username port enc keyname comment
  local keypath pubpath cfg

  host_alias="$(ssha::prompt "Nom de l'hote (alias dans ~/.ssh/config) ex: planethoster")"
  hostname="$(ssha::prompt "Adresse du serveur (HostName) ex: node266-eu.n0c.com")"
  username="$(ssha::prompt "Nom utilisateur SSH (User) ex: dwmkyvke")"
  port="$(ssha::prompt "Port SSH (Port)" "22")"

  enc="$(ssha::choose_encoding)"
  keyname="$(ssha::prompt "Nom de la clé (ex: planethoster)")"
  comment="$(ssha::prompt "Commentaire (ssh-keygen -C)" "${username}@${host_alias}")"

  mapfile -t paths < <(ssha::key_paths "${enc}" "${keyname}")
  keypath="${paths[0]}"
  pubpath="${paths[1]}"

  ssha::ensure_ssh_dir "${SSHA_SSH_DIR}"

  if [[ -e "${keypath}" || -e "${pubpath}" ]]; then
    echo "[ERROR] La clé existe déjà: ${keypath} (ou .pub). Renomme la clé ou supprime l'existante."
    return 1
  fi

  echo
  echo "[INFO] Génération de la clé: ${enc} -> ${keypath}"
  ssha::run_ssh_keygen "${enc}" "${keypath}" "${comment}"

  cfg="$(ssha::config_path)"
  touch "${cfg}"
  chmod 600 "${cfg}" 2>/dev/null || true

  echo "[INFO] Mise à jour du config: ${cfg}"
  ssha::remove_host_block "${cfg}" "${host_alias}"
  ssha::append_host_block "${cfg}" "${host_alias}" "${hostname}" "${username}" "${port}" "${keypath}"

  ssha::print_public_key "${pubpath}"

  echo "[OK] Terminé."
  echo "     Test: ssh ${host_alias}"
}

ssha::menu() {
  echo "1) Création de la paire de clé + config host"
  echo "2) Agent: status / start / ensure"
  echo "0) Quit"
  echo
}


ssha::main() {
  ssha::detect_platform

  # Allow tests to override ssh dir
  SSHA_SSH_DIR="${SSHA_SSH_DIR:-$HOME/.ssh}"
  export SSHA_SSH_DIR

  while true; do
    ssha::banner
    ssha::menu
    local choice
    choice="$(ssha::prompt "Choix" "0")"
    case "${choice}" in
      1) ssha::option_create_key_and_config ;;
      2) ssha::option_agent_menu ;;
      0) exit 0 ;;
      *) echo "[WARN] Choix invalide." ;;
    esac
    echo
    read -r -p "Appuie sur Entrée pour revenir au menu..." _
  done
}

ssha::option_agent_menu() {
  echo
  echo "Agent:"
  echo "1) status"
  echo "2) start"
  echo "3) ensure"
  echo "0) retour"
  echo
  local c
  c="$(ssha::prompt "Choix" "1")"
  case "${c}" in
    1) ssha::agent_status ;;
    2) ssha::agent_start ;;
    3) ssha::agent_ensure ;;
    0) return 0 ;;
    *) echo "[WARN] Choix invalide." ;;
  esac
}
