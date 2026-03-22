#!/usr/bin/env bash
# IMPORTANT: pas de "set -e" (le programme ne doit jamais quitter sur erreur)
set -u
set -o pipefail

# SSH Assistant - ssha_core.sh (refactor: regroupé par thèmes + commentaires)
# -----------------------------------------------------------------------------
# Conventions (IMPORTANT):
# - Tout ce qui est "UI / prompt" s'affiche sur STDERR (>&2) pour fonctionner avec $(...)
# - Les fonctions qui renvoient une valeur l'écrivent sur STDOUT
# - Les actions destructrices doivent passer par ssha::maybe_run (DRY-RUN)
# - Ce fichier dépend de lib/ssha_colors.sh (ssha::c_* / ssha::colors_enabled) et de tes logs
#   (ssha::log_ok / ssha::log_warn / ssha::log_err) qui existent déjà dans ton projet.
# -----------------------------------------------------------------------------


# --- ssha::detect_platform
# Détecte la plateforme (gitbash/cygwin/linux/mac) et exporte SSHA_PLATFORM.

ssha::detect_platform() {
  # minimal: gitbash/msys/cygwin/linux
  local u
  u="$(uname -s 2>/dev/null || true)"
  case "${u}" in
    MINGW*|MSYS*) SSHA_PLATFORM="GitBash" ;;
    CYGWIN*)      SSHA_PLATFORM="Cygwin" ;;
    Linux*)       SSHA_PLATFORM="Linux" ;;
    Darwin*)      SSHA_PLATFORM="macOS" ;;
    *)            SSHA_PLATFORM="Unknown" ;;
  esac
  export SSHA_PLATFORM
}


# --- ssha::history_file
# Retourne le chemin du journal d'actions (history.log).

ssha::history_file() {
  echo "${HOME}/.ssh_assistant/history.log"
}


# --- ssha::history_log
# Ajoute une ligne horodatée au journal d'actions.

ssha::history_log() {
  local msg="$1"
  mkdir -p "$(dirname "$(ssha::history_file)")"
  printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${msg}" >> "$(ssha::history_file)"
}


# --- ssha::history_show
# Affiche les 200 dernières lignes du journal d'actions.

ssha::history_show() {
  ssha::screen_title "Historique SSH Assistant"
  local f
  f="$(ssha::history_file)"
  if [[ ! -f "${f}" ]]; then
    ssha::log_warn "Aucun historique."
    return 0
  fi
  tail -n 200 "${f}" >&2

  ssha::pause
}


# --- ssha::dry_run_is_on
# Retourne 0 si le mode DRY-RUN est actif (SSHA_DRY_RUN=1).

ssha::dry_run_is_on() {
  [[ "${SSHA_DRY_RUN:-0}" == "1" ]]
}


# --- ssha::maybe_run
# Exécute une commande, ou la loggue seulement si DRY-RUN est ON.

ssha::maybe_run() {
  if [[ "${SSHA_DRY_RUN:-0}" == "1" ]]; then
    ssha::log_warn "[DRY-RUN] $*"
  else
    "$@"
  fi
}


# --- ssha::dry_run_toggle
# Bascule DRY-RUN ON/OFF depuis le menu (option toggle).

ssha::dry_run_toggle() {
  if ssha::dry_run_is_on; then
    SSHA_DRY_RUN=0
    export SSHA_DRY_RUN
    ssha::log_ok "DRY-RUN: OFF (actions réelles)"
    ssha::history_log "dry-run OFF"
  else
    SSHA_DRY_RUN=1
    export SSHA_DRY_RUN
    ssha::log_warn "DRY-RUN: ON (aucune action destructive ne sera exécutée)"
    ssha::history_log "dry-run ON"
  fi
}

# --- ssha::_banner_green_block
# Bannière verte standardisée (64 colonnes)

ssha::_banner_green_block() {
  local title="$1"
  local subtitle="$2"
  local host="${3:-}"

  if ssha::colors_enabled; then ssha::c_green >&2; fi

  printf '████████████████████████████████████████████████████████████████\n' >&2
  printf '  %-60s  \n' "${title}" >&2
  printf '  %-60s  \n' "${subtitle}" >&2

  if [[ -n "${host}" ]]; then
    printf '  Host: %-53s  \n' "${host}" >&2
  fi

  printf '████████████████████████████████████████████████████████████████\n\n' >&2

  if ssha::colors_enabled; then ssha::c_reset >&2; fi
}

# --- ssha::_banner_red_block
# Bannière rouge standardisée (64 colonnes)

ssha::_banner_red_block() {
  local title="$1"
  local subtitle="$2"
  local host="${3:-}"

  if ssha::colors_enabled; then ssha::c_red >&2; fi

  printf '████████████████████████████████████████████████████████████████\n' >&2
  printf '  %-60s  \n' "${title}" >&2
  printf '  %-60s  \n' "${subtitle}" >&2

  if [[ -n "${host}" ]]; then
    printf '  Host: %-53s  \n' "${host}" >&2
  fi

  printf '████████████████████████████████████████████████████████████████\n\n' >&2

  if ssha::colors_enabled; then ssha::c_reset >&2; fi
}


# --- ssha::banner
# Affiche la bannière ASCII + plateforme, avec couleurs.

ssha::banner() {
  local root_dir

  # Clear screen only if interactive TTY
  if [[ -t 1 ]]; then
    clear
  fi

  root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

  if [[ -f "${root_dir}/assets/banner.txt" ]]; then
    # Banner in orange (option 3)
    ssha::print_orange_file "${root_dir}/assets/banner.txt"
  else
    echo "SSH Assistant"
  fi

  echo
  ssha::c_green
  printf '==============================================\n'
  printf ' Plateforme: %s\n' "${SSHA_PLATFORM:-unknown}"
  printf '==============================================\n'
  ssha::c_reset
  echo
}


# --- ssha::menu
# Affiche le menu principal


ssha::menu() {
  ssha::c_blue >&2

  echo "-----------------------------------------------" >&2
  echo "* CRÉATION PAIRE DE CLÉS (PUBLIQUE ET PRIVÉE) *" >&2
  echo "-----------------------------------------------" >&2
  echo "1) Création manuelle de la paire de clé et config host" >&2
  echo "2) Création automatique à partir de la liste des hôtes" >&2

  echo "----------------------" >&2
  echo "* TEST CONNEXION SSH *" >&2
  echo "----------------------" >&2
  echo "3) Test de connexion SSH (depuis config)" >&2

  echo "---------------" >&2
  echo "* DOSSIER SSH *" >&2
  echo "---------------" >&2
  echo "4) Afficher le dossier ~/.ssh" >&2
  echo "5) Sauvegarder le dossier ~/.ssh (volontaire)" >&2
  echo "6) Effacer le dossier ~/.ssh (DANGEREUX)" >&2
  echo "-------" >&2
  echo "0) Quit" >&2

  ssha::c_reset >&2
  echo >&2
}


# --- ssha::repeat_char
# Répète un caractère N fois (utile pour encadrer des titres).

ssha::repeat_char() {
  local char="$1"
  local count="$2"
  printf '%*s' "${count}" '' | tr ' ' "${char}"
}


# --- ssha::screen_title
# Affiche un titre plein écran avec 2 lignes (haut/bas).

ssha::screen_title() {
  local title="$1"
  local line="==========================================================="

  if [[ -t 0 ]]; then
    clear
  fi

  # Couleur du bloc titre
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    if [[ "${SSHA_PROMPT_FORCE_YELLOW:-0}" == "1" ]]; then
      ssha::c_yellow >&2
    else
      ssha::c_blue >&2
    fi
  fi

  printf '%s\n' "${line}" >&2
  printf '%s\n' "${title}" >&2
  printf '%s\n\n' "${line}" >&2

  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}


# --- ssha::screen_title_inline
# Affiche un titre sur 3 lignes (ligne/titre/ligne) sans calcul de largeur.

ssha::screen_title_inline() {
  local title="$1"
  local line="==========================================================="

  if [[ -t 0 ]]; then
    clear
  fi

  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    if [[ "${SSHA_PROMPT_FORCE_YELLOW:-0}" == "1" ]]; then
      ssha::c_yellow >&2
    else
      ssha::c_blue >&2
    fi
  fi

  printf "%s %s %s\n\n" "${line}" "${title}" "${line}" >&2

  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}


# --- ssha::screen_title_inline_danger
# Affiche un titre DANGER encadré (largeur = longueur du titre), en rouge inversé.

ssha::screen_title_inline_danger() {
  local title="$1"
  local len
  local line

  # longueur réelle du titre (en caractères)
  len="${#title}"

  # ligne = répétition de '=' à la même longueur
  line="$(ssha::repeat_char '=' "${len}")"

  if [[ -t 0 ]]; then
    clear
  fi

  if ssha::colors_enabled; then
    # rouge + inverse + gras (fallback universel)
    printf '\033[1m\033[7m\033[38;5;196m%s\033[0m\n' "${line}" >&2
    printf '\033[1m\033[7m\033[38;5;196m%s\033[0m\n' "${title}" >&2
    printf '\033[1m\033[7m\033[38;5;196m%s\033[0m\n\n' "${line}" >&2
  else
    printf "%s\n%s\n%s\n\n" "${line}" "${title}" "${line}" >&2
  fi
}


# --- ssha::blink_error_red
# Affiche 'ERREUR DE SAISIE' en rouge (blink si supporté).

ssha::blink_error_red() {
  # clignotant rouge (ANSI blink 5). Sur certains terminaux, le blink peut être désactivé.
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    # red + blink
    printf '\033[38;5;196m\033[5mERREUR DE SAISIE\033[0m\n' >&2
  else
    echo "ERREUR DE SAISIE" >&2
  fi
}


# --- ssha::danger_emphasis
# Affiche un message très visible (fallback si blink désactivé).

ssha::danger_emphasis() {
  # Usage: ssha::danger_emphasis "TEXTE"
  local msg="$1"

  if ! ssha::colors_enabled; then
    printf '%s\n' "${msg}" >&2
    return 0
  fi

  if ssha::term_supports_blink; then
    # blink + rouge
    printf '\033[38;5;196m\033[5m%s\033[0m\n' "${msg}" >&2
  else
    # fallback: inverse video + rouge + gras si possible
    # 7 = reverse video, 1 = bold
    printf '\033[1m\033[7m\033[38;5;196m %s \033[0m\n' "${msg}" >&2
  fi
}


# --- ssha::danger_countdown
# Compte à rebours 3-2-1 avant action dangereuse.

ssha::danger_countdown() {
  local i
  for i in 3 2 1; do
    if ssha::colors_enabled; then
      printf '\r\033[38;5;196m\033[1mAction dangereuse dans %s...\033[0m' "${i}" >&2
    else
      printf '\rAction dangereuse dans %s...' "${i}" >&2
    fi
    sleep 1
  done
  printf '\n' >&2
}


# --- ssha::prompt
# Prompt générique: affiche sur STDERR, renvoie la saisie sur STDOUT.

ssha::prompt() {
  local label="$1"
  local default="${2:-}"
  local out=""

  # Colors only if interactive input
  local can_color=0
  if declare -F ssha::colors_enabled >/dev/null 2>&1 \
     && [[ -t 0 ]] \
     && ssha::colors_enabled; then
    can_color=1
  fi

  # Force-yellow mode (option 1)
  local force_yellow=0
  [[ "${SSHA_PROMPT_FORCE_YELLOW:-0}" == "1" ]] && force_yellow=1

  # "Choix" special
  local is_choice=0
  [[ "${label}" =~ ^[[:space:]]*Choix\b ]] && is_choice=1

  # Decide label color
  _ssha__set_label_color() {
    if [[ "${can_color}" -eq 1 ]]; then
      if [[ "${force_yellow}" -eq 1 || "${is_choice}" -eq 1 ]]; then
        ssha::c_yellow >&2
      else
        ssha::c_blue >&2
      fi
    fi
  }

  _ssha__set_input_color() {
    if [[ "${can_color}" -eq 1 ]]; then
      ssha::c_yellow >&2
    fi
  }

  _ssha__reset_color() {
    if [[ "${can_color}" -eq 1 ]]; then
      ssha::c_reset >&2
    fi
  }

  if [[ -n "${default}" ]]; then
    _ssha__set_label_color
    # IMPORTANT: prompt printed to STDERR so it is visible even inside $(...)
    printf '%s [' "${label}" >&2
    ssha::c_yellow >&2
    printf '%s' "${default}" >&2
    ssha::c_reset >&2
    printf ']: ' >&2
    _ssha__set_input_color
    IFS= read -r out
    _ssha__reset_color

    # Return value on STDOUT (capturable)
    printf '%s\n' "${out:-$default}"
  else
    _ssha__set_label_color
    printf '%s: ' "${label}" >&2
    _ssha__set_input_color
    IFS= read -r out
    _ssha__reset_color

    printf '%s\n' "${out}"
  fi
}


# --- ssha::prompt_required
# Prompt obligatoire (non vide).

ssha::prompt_required() {
  local label="$1"
  local default="${2:-}"
  local value=""

  while true; do
    value="$(ssha::prompt "${label}" "${default}")"

    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi

    ssha::blink_error_red
  done
}


# --- ssha::prompt_required_text
# Prompt obligatoire texte (non vide, pas uniquement numérique).

ssha::prompt_required_text() {
  local label="$1"
  local default="${2:-}"
  local value=""

  while true; do
    value="$(ssha::prompt "${label}" "${default}")"

    # trim espaces
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    if [[ "${value}" =~ ^[0-9]+$ ]]; then
      ssha::blink_error_red
      continue
    fi

    printf '%s\n' "${value}"
    return 0
  done
}


# --- ssha::prompt_required_port
# Prompt obligatoire port (1..65535).

ssha::prompt_required_port() {
  local label="$1"
  local default="${2:-22}"
  local value=""

  while true; do
    value="$(ssha::prompt "${label}" "${default}")"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
      ssha::blink_error_red
      continue
    fi

    if (( value < 1 || value > 65535 )); then
      ssha::blink_error_red
      continue
    fi

    printf '%s\n' "${value}"
    return 0
  done
}


# --- ssha::prompt_required_choice
# Prompt obligatoire pour menus: numérique non vide (Entrée => erreur).

ssha::prompt_required_choice() {
  local label="$1"
  local value=""

  while true; do
    value="$(ssha::prompt "${label}" "")"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
      ssha::blink_error_red
      continue
    fi

    printf '%s\n' "${value}"
    return 0
  done
}


# --- ssha::prompt_wipe_confirm
# Demande de taper 'WIPE' (mot mis en évidence).

ssha::prompt_wipe_confirm() {
  local out=""

  if ssha::colors_enabled; then
    ssha::c_yellow >&2
    printf "Tape EXACTEMENT " >&2
    if ssha::term_supports_blink; then
      printf '\033[38;5;196m\033[5mWIPE\033[0m' >&2
    else
      printf '\033[1m\033[7m\033[38;5;196m WIPE \033[0m' >&2
    fi
    ssha::c_yellow >&2
    printf " pour confirmer: " >&2
    ssha::c_reset >&2
  else
    printf "Tape EXACTEMENT WIPE pour confirmer: " >&2
  fi

  IFS= read -r out
  printf '%s\n' "${out}"
}


# --- ssha::choose_encoding
# Menu choix type de clé (ed25519/rsa/ecdsa).

ssha::choose_encoding() {
  if [[ "${SSHA_PROMPT_FORCE_YELLOW:-0}" == "1" ]] && ssha::colors_enabled; then
    ssha::c_yellow >&2
  elif ssha::colors_enabled; then
    ssha::c_blue >&2
  fi

  {
    echo
    echo "============================"
    echo "   Encodage - Type de clé   "
    echo "============================"
    echo
    echo "1) ed25519 (recommandé)"
    echo "2) rsa (fallback 1, 4096 bits)"
    echo "3) ecdsa (fallback 2, P-256)"
    echo
  } >&2

  if ssha::colors_enabled; then
    ssha::c_reset >&2
  fi

  local choice
  choice="$(ssha::prompt "Encodage" "1")"

  case "${choice}" in
    1) printf '%s\n' "ed25519" ;;
    2) printf '%s\n' "rsa" ;;
    3) printf '%s\n' "ecdsa" ;;
    *) printf '%s\n' "ed25519" ;;
  esac
}


# --- ssha::ensure_ssh_dir
# Crée le dossier SSH si besoin et applique chmod 700.

ssha::ensure_ssh_dir() {
  local dir="${1}"
  mkdir -p "${dir}"
  chmod 700 "${dir}" 2>/dev/null || true
}


# --- ssha::config_path
# Retourne le chemin du fichier config SSH (~/.ssh/config).

ssha::config_path() {
  echo "${SSHA_SSH_DIR}/config"
}


# --- ssha::key_paths
# Calcule les chemins clé privée/publique selon enc+nom.

ssha::key_paths() {
  local name="$1"
  local base="${SSHA_SSH_DIR}/${name}"
  printf '%s\n%s\n' "${base}" "${base}.pub"
}


# --- ssha::run_ssh_keygen
# Lance ssh-keygen selon l'encodage choisi.

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


# --- ssha::remove_host_block
# Supprime un bloc 'Host <alias>' du fichier config.

ssha::remove_host_block() {
  local cfg="$1"
  local alias="$2"

  [[ -f "${cfg}" ]] || return 0

  awk -v a="${alias}" '
    BEGIN{skip=0}
    /^[[:space:]]*Host[[:space:]]+/{
      if ($2==a) {skip=1; next}
      else {skip=0}
    }
    { if (!skip) print }
  ' "${cfg}" > "${cfg}.tmp"
  mv "${cfg}.tmp" "${cfg}"
}


# --- ssha::append_host_block
# Ajoute un bloc 'Host ...' au fichier config.

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


# --- ssha::print_public_key
# Affiche la clé publique sur STDOUT pour copie manuelle.

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


# --- ssha::copy_to_clipboard
# Copie un texte dans le presse-papiers (clip.exe sur Windows).

ssha::copy_to_clipboard() {
  local text="$1"
  if command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "${text}" | clip.exe
    return 0
  fi
  return 1
}



# --- ssha::normalize_keyname
# Convention: alias_user (ex: github-lddvlp_git) ou planethoster-ldbug-com_dwmkyvke
# - tout en minuscules
# - remplace @ par _at_
# - remplace espaces et caractères non sûrs par _
# - compacte les ___
# NB: on ne met pas l'encodage dans le nom : le filename = keyname (alias_user)

ssha::normalize_keyname() {
  local alias="${1:-}"
  local user="${2:-}"

  # Si un champ manque, on renvoie vide (appelant gère le fallback)
  [[ -n "${alias}" && -n "${user}" ]] || { printf '%s\n' ""; return 0; }

  local raw="${alias}_${user}"

  raw="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]')"
  raw="${raw//@/_at_}"

  raw="$(printf '%s' "${raw}" | sed -E 's/[^a-z0-9]+/_/g')"
  raw="$(printf '%s' "${raw}" | sed -E 's/_+/_/g; s/^_+//; s/_+$//')"

  printf '%s\n' "${raw}"
}

# --- ssha::option_create_key_and_config
# Option 1: crée une paire de clés + écrit le Host dans config + copie la pubkey.

ssha::option_create_key_and_config() {

  ssha::screen_title "Création de la paire de clé et génération du fichier config"

  local host_alias hostname username port enc keyname comment default_keyname
  local keypath pubpath cfg
  local -a paths
  local SKIP_KEYGEN=0

  host_alias="$(ssha::prompt_required_text "Nom de l'hote (alias dans ~/.ssh/config) ex: planethoster")"
  hostname="$(ssha::prompt_required_text "Adresse du serveur (HostName) ex: node266-eu.n0c.com")"
  username="$(ssha::prompt_required_text "Nom utilisateur SSH (User) ex: dwmkyvke")"
  port="$(ssha::prompt_required_port "Port SSH (Port)" "22")"

  default_keyname="$(ssha::normalize_keyname "${host_alias}" "${username}")"
  [[ -n "${default_keyname}" ]] || default_keyname="${host_alias}"

  enc="$(ssha::choose_encoding)"
  keyname="$(ssha::prompt_required_text "Nom de la clé " "${default_keyname}")"
  comment="${keyname}"

  mapfile -t paths < <(ssha::key_paths "${keyname}")
  keypath="${paths[0]}"
  pubpath="${paths[1]}"

  ssha::ensure_ssh_dir "${SSHA_SSH_DIR}"

  if [[ -e "${keypath}" || -e "${pubpath}" ]]; then
    ssha::log_warn "La clé existe déjà:"
    echo "  - ${keypath}"
    echo "  - ${pubpath}"
    echo

    echo "Que veux-tu faire ?" >&2
    echo "1) Annuler (ne touche à rien)" >&2
    echo "2) Réutiliser la clé existante (MAJ config uniquement)" >&2
    echo "3) Écraser (backup + régénération)" >&2
    echo >&2

    local kchoice
    kchoice="$(ssha::prompt_required_choice "Choix")"

    case "${kchoice}" in
      1)
        ssha::log_warn "Annulé."
        return 0
        ;;
      2)
        ssha::log_ok "Réutilisation de la clé existante (pas de régénération)."
        SKIP_KEYGEN=1
        ;;
      3)
        ssha::log_warn "Écrasement demandé: backup puis régénération."
        ssha::backup_existing_keypair "${keypath}" "${pubpath}"
        ;;
      *)
        ssha::log_warn "Choix invalide. Annulé."
        return 1
        ;;
    esac
  fi

  if [[ "${SKIP_KEYGEN}" != "1" ]]; then
    echo
    ssha::log_ok "Génération de la clé: ${enc} -> ${keypath}"
    ssha::run_ssh_keygen "${enc}" "${keypath}" "${comment}"
  else
    ssha::log_ok "Keygen ignoré : utilisation de la clé existante."
  fi

  cfg="$(ssha::config_path)"
  touch "${cfg}"
  chmod 600 "${cfg}" 2>/dev/null || true

  ssha::log_ok "Mise à jour du config: ${cfg}"
  ssha::remove_host_block "${cfg}" "${host_alias}"
  ssha::append_host_block "${cfg}" "${host_alias}" "${hostname}" "${username}" "${port}" "${keypath}"

  ssha::print_public_key "${pubpath}"

  if [[ -f "${pubpath}" ]]; then
    local pubkey
    pubkey="$(cat "${pubpath}")"
    if ssha::copy_to_clipboard "${pubkey}"; then
      ssha::banner_pubkey_copied_red
    else
      ssha::banner_pubkey_copy_failed_red
    fi
  fi

  echo >&2
  local do_test
  do_test="$(ssha::prompt "Tester maintenant la connexion SSH ?" "o")"
  case "${do_test}" in
    o|O|y|Y|oui|YES|yes)
      ssha::ssh_test_interactive_offer "${host_alias}" "${pubpath}"
      ;;
    *) : ;;
  esac
}

ssha::backup_existing_keypair() {
  local keypath="$1"
  local pubpath="$2"

  local base ts dest
  base="$(ssha::ssh_backup_dir_manual)"
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")"
  dest="${base}/keys-${ts}"

  ssha::maybe_run mkdir -p "${dest}"

  [[ -f "${keypath}" ]] && ssha::maybe_run mv "${keypath}" "${dest}/"
  [[ -f "${pubpath}" ]] && ssha::maybe_run mv "${pubpath}" "${dest}/"

  ssha::log_ok "Ancienne paire sauvegardée dans: ${dest}"
  ssha::history_log "backup keypair -> ${dest}"
}



# --- ssha::providers_conf_path
# Chemin de assets/providers.conf (liste des providers).

ssha::providers_conf_path() {
  local root_dir
  root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "${root_dir}/assets/providers.conf"
}


# --- ssha::providers_list
# Liste les lignes providers.conf (sans commentaires/vides).

ssha::providers_list() {
  local conf
  conf="$(ssha::providers_conf_path)"
  [[ -f "${conf}" ]] || return 1

  grep -vE '^[[:space:]]*#' "${conf}" | grep -vE '^[[:space:]]*$' || true
}


# --- ssha::providers_menu
# Option 3: menu guidé pour générer config/clé via providers.conf.

ssha::providers_menu() {
  
  ssha::screen_title "Création automatique des clés"

  local -a ids lines
  local i=0 line

  while IFS= read -r line; do
    ids[i]="$(printf '%s' "${line}" | cut -d'|' -f1)"
    lines[i]="${line}"
    i=$((i+1))
  done < <(ssha::providers_list)

  local count="${#ids[@]}"

  if [[ "${#ids[@]}" -eq 0 ]]; then
    ssha::log_err "Aucun provider dans assets/providers.conf"
    return 1
  fi

local count="${#ids[@]}"

echo >&2
ssha::c_blue >&2
printf "Hôtes enregistrés (%d) :\n" "${count}" >&2
ssha::c_reset >&2

# En-tête tableau
ssha::c_blue >&2

# Largeurs (tu peux ajuster si besoin)
W_NUM=4
W_HOST=40
W_KEY=22
W_CFG=22

ssha::cell_text "N°"  "${W_NUM}";  printf " " >&2
ssha::cell_text "Hôte" "${W_HOST}"; printf " " >&2
ssha::cell_text "Clé privée détectée" "${W_KEY}"; printf " " >&2
ssha::cell_text "Configuration valide (Fichier providers.conf renseigné)" "${W_CFG}"
printf "\n" >&2

printf "%s\n" "--------------------------------------------------------------------------------------" >&2
ssha::c_reset >&2

for ((i=0; i<${#ids[@]}; i++)); do
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${lines[i]}"

  local has_key=0 has_cfg=0
  ssha::ssh_host_has_key "${id}" && has_key=1
  ssha::ssh_test_safe_config "${id}" && has_cfg=1

  # Exemple dans ta boucle:
  # i => index, label => "PlanetHoster loicdrouet.com", has_key/has_cfg => 1/0

  # i => index, label => hôte, has_key/has_cfg => 1/0

  ssha::cell_text "$((i+1))" "${W_NUM}"; printf " " >&2
  ssha::cell_text "${label}" "${W_HOST}"; printf " " >&2
  ssha::cell_yesno "${has_key}" "${W_KEY}"; printf " " >&2
  ssha::cell_yesno "${has_cfg}" "${W_CFG}"
  printf "\n" >&2

done
  

echo >&2
ssha::c_blue >&2
echo "0) Retour" >&2
ssha::c_reset >&2
echo >&2

  local choice
  choice="$(ssha::prompt_required_choice "Choix")"
  choice="${choice//[[:space:]]/}"

  if [[ "${choice}" == "0" ]]; then
    return 0
  fi

  if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ids[@]} )); then
    ssha::provider_apply_line "${lines[choice-1]}"
    return $?
  fi

  ssha::log_warn "Choix invalide."
  return 1
}


# --- ssha::provider_apply_line
# Applique une ligne provider: génère clé + écrit 1 Host (alias id uniquement).

ssha::provider_apply_line() {
  local line="$1"
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${line}"

  if [[ -z "${id}" || -z "${label}" || -z "${hostname}" || -z "${username}" || -z "${port}" || -z "${keyname}" ]]; then
    ssha::log_err "Provider invalide (champ vide) dans providers.conf: ${line}"
    return 1
  fi

  local enc="ed25519"

  local keypath pubpath
  local -a _paths
  mapfile -t _paths < <(ssha::key_paths "${keyname}")
  keypath="${_paths[0]}"
  pubpath="${_paths[1]}"

  ssha::ensure_ssh_dir "${SSHA_SSH_DIR}"

  if [[ -e "${keypath}" || -e "${pubpath}" ]]; then
    ssha::log_warn "Cle existe deja, skip: ${keypath}"
  else
    ssha::log_ok "Generation cle ${label}: ${keypath}"
    ssha::run_ssh_keygen "${enc}" "${keypath}" "${keyname}"
  fi

  local cfg
  cfg="$(ssha::config_path)"
  touch "${cfg}"
  chmod 600 "${cfg}" 2>/dev/null || true

  # Un seul alias SSH: Host <id>
  ssha::log_ok "Maj config pour ${label}: Host ${id}"

  ssha::remove_host_block "${cfg}" "${id}"
  ssha::append_host_block "${cfg}" "${id}" "${hostname}" "${username}" "${port}" "${keypath}"

  if [[ -f "${pubpath}" ]]; then
    local pubkey
    pubkey="$(cat "${pubpath}")"
    if ssha::copy_to_clipboard "${pubkey}"; then
      ssha::log_ok "La clé publique a été copiée et est prête à être collée chez votre hôte."
    else
      ssha::log_warn "La clé publique est affichée. Copiez-la et collez-la chez votre hôte."
    fi
  fi
  ssha::pause
}


# --- ssha::provider_keypath
# Renvoie le chemin de la clé privée d'un provider (ed25519 par défaut).

ssha::provider_keypath() {
  local keyname="$1"
  local -a p
  mapfile -t p < <(ssha::key_paths "${keyname}")
  printf '%s\n' "${p[0]}"
}


# --- ssha::ssh_config_ok
# Test SAFE: ssh -G <host> (valide config sans connexion).

ssha::ssh_config_ok() {
  local host="$1"
  ssh -G "${host}" >/dev/null 2>&1
}


# --- ssha::ssh_real_test_git
# Test réel: ssh -T en BatchMode (peut échouer si clé non chargée).

ssha::ssh_real_test_git() {
  local host="$1"
  ssh -o BatchMode=yes -T "${host}" >/dev/null 2>&1
}


# --- ssha::provider_status_line
# Retourne un statut parseable pour un provider (clé/config ok).

ssha::provider_status_line() {
  local line="$1"
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${line}"

  local keypath
  keypath="$(ssha::provider_keypath "${keyname}")"

  local ok_key=0 ok_id=0 ok_host=0
  [[ -f "${keypath}" ]] && ok_key=1
  ssha::ssh_config_ok "${id}" && ok_id=1
  ssha::ssh_config_ok "${hostname}" && ok_host=1

  printf '%s|%s|%s|%s|%s|%s|%s\n' \
    "${id}" "${label}" "${hostname}" \
    "${ok_key}" "${ok_id}" "${ok_host}" "${keypath}"
}


# --- ssha::providers_status_menu
# Option 4: affiche status + propose tests (1 ou tous).

ssha::providers_status_menu() {
  ssha::screen_title "Providers: status / test"

  local -a lines
  mapfile -t lines < <(ssha::providers_list)

  if [[ "${#lines[@]}" -eq 0 ]]; then
    ssha::log_err "Aucun provider dans assets/providers.conf"
    ssha::pause
    return 1
  fi

  if ssha::colors_enabled; then ssha::c_blue >&2; fi
  printf "N\tProvider\tKey\tHost(id)\tHost(domain)\n" >&2
  printf "----------------------------------------------------------\n" >&2
  if ssha::colors_enabled; then ssha::c_reset >&2; fi

  local i st id label hostname ok_key ok_id ok_host keypath
  for ((i=0; i<${#lines[@]}; i++)); do
    st="$(ssha::provider_status_line "${lines[i]}")"
    IFS='|' read -r id label hostname ok_key ok_id ok_host keypath <<<"${st}"

    printf "%d\t%s\t%s\t%s\t%s\n" \
      "$((i+1))" \
      "${label}" \
      "$( [[ "${ok_key}" == "1" ]] && echo OK || echo NOK )" \
      "$( [[ "${ok_id}" == "1" ]] && echo OK || echo NOK )" \
      "$( [[ "${ok_host}" == "1" ]] && echo OK || echo NOK )" \
      >&2
  done

  echo >&2
  echo "1) Tester un provider" >&2
  echo "2) Tester TOUS les providers (safe)" >&2
  echo "0) Retour" >&2
  echo >&2

  local c
  c="$(ssha::prompt_required_choice "Choix")"
  case "${c}" in
    1) ssha::providers_test_one "${lines[@]}" ;;
    2) ssha::providers_test_all_safe "${lines[@]}" ;;
    0) return 0 ;;
    *) ssha::log_warn "Choix invalide." ;;
  esac

  ssha::pause
}


# --- ssha::providers_test_one
# Test un provider (SAFE + option test réel).

ssha::providers_test_one() {
  local -a lines=("$@")
  local idx
  idx="$(ssha::prompt "Numéro provider" "1")"

  [[ "${idx}" =~ ^[0-9]+$ ]] || { ssha::log_err "Numéro invalide."; return 1; }
  (( idx >= 1 && idx <= ${#lines[@]} )) || { ssha::log_err "Hors plage."; return 1; }

  local line="${lines[idx-1]}"
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${line}"

  ssha::log_ok "Test SAFE (ssh -G) pour ${label}"
  if ssha::ssh_config_ok "${id}"; then ssha::log_ok "OK: ${id}"; else ssha::log_err "NOK: ${id}"; fi
  if ssha::ssh_config_ok "${hostname}"; then ssha::log_ok "OK: ${hostname}"; else ssha::log_err "NOK: ${hostname}"; fi

  echo >&2
  local do_real
  do_real="$(ssha::prompt "Test réel (ssh -T) ?" "n")"
  case "${do_real}" in
    o|O|y|Y|oui|YES|yes)
      ssha::log_ok "Test REEL (BatchMode) pour ${label}"
      if ssha::ssh_real_test_git "${id}"; then
        ssha::log_ok "OK: ssh -T ${id}"
      else
        ssha::log_warn "NOK: ssh -T ${id} (clé non chargée ? host key ? provider refuse ?)"
      fi
      if ssha::ssh_real_test_git "git@${hostname}"; then
        ssha::log_ok "OK: ssh -T git@${hostname}"
      else
        ssha::log_warn "NOK: ssh -T git@${hostname}"
      fi
      ;;
    *) : ;;
  esac
}


# --- ssha::providers_test_all_safe
# Test SAFE de tous les providers (ssh -G).

ssha::providers_test_all_safe() {
  local -a lines=("$@")
  local line id label hostname username port keyname

  for line in "${lines[@]}"; do
    IFS='|' read -r id label hostname username port keyname <<<"${line}"
    ssha::log_ok "SAFE: ${label}"
    if ssha::ssh_config_ok "${id}"; then
      ssha::log_ok "  OK: ${id}"
    else
      ssha::log_err "  NOK: ${id}"
    fi
    
    if ssha::ssh_config_ok "${hostname}"; then
      ssha::log_ok "  OK: ${hostname}"
    else
      ssha::log_err "  NOK: ${hostname}"
    fi
  done
}


# --- ssha::proc_ps_dump
# Dump des processus (pid/ppid/comm/args) pour filtrage shells.

ssha::proc_ps_dump() {
  # Output: PID<TAB>PPID<TAB>COMM<TAB>ARGS
  if ps -W >/dev/null 2>&1; then
    ps -W -eo pid=,ppid=,comm=,args= 2>/dev/null | awk 'BEGIN{OFS="\t"} {print $1,$2,$3,substr($0, index($0,$4))}'
  else
    ps -eo pid=,ppid=,comm=,args= 2>/dev/null | awk 'BEGIN{OFS="\t"} {print $1,$2,$3,substr($0, index($0,$4))}'
  fi
}


# --- ssha::proc_filter_shells
# Filtre les processus qui ressemblent à des shells/sous-shells.

ssha::proc_filter_shells() {
  awk -F'\t' '
    BEGIN{IGNORECASE=1}
    $3 ~ /^(bash|sh|zsh|dash|ksh|fish|pwsh|powershell|cmd|mintty|conhost|ssh)$/ {print; next}
    $4 ~ /(bash|zsh|mintty|ssh|wsl|powershell|cmd\.exe)/ {print}
  '
}


# --- ssha::proc_show_shells
# Option 5: affiche la liste des shells détectés.

ssha::proc_show_shells() {
  ssha::screen_title "Processus: shells / sous-shells"

  local dump
  dump="$(ssha::proc_ps_dump | ssha::proc_filter_shells)"

  if [[ -z "${dump}" ]]; then
    ssha::log_warn "Aucun shell détecté."
    return 0
  fi

  if ssha::colors_enabled; then ssha::c_blue >&2; fi
  printf "PID\tPPID\tCOMM\tARGS\n" >&2
  printf "------------------------------------------------------------\n" >&2
  if ssha::colors_enabled; then ssha::c_reset >&2; fi

  printf "%s\n" "${dump}" >&2
}


# --- ssha::ssh_dir_show
# Option 6: affiche contenu ~/.ssh + aperçu config.

ssha::ssh_dir_show() {
  ssha::screen_title "Dossier SSH: ${SSHA_SSH_DIR}"

  local dir="${SSHA_SSH_DIR}"
  local shown_lines=6

  if [[ ! -d "${dir}" ]]; then
    ssha::log_warn "Le dossier n'existe pas: ${dir}"
    return 0
  fi

  ssha::log_ok "Contenu (trié):"
  echo >&2

  local files
  files="$(find "${dir}" -maxdepth 1 -type f -print 2>/dev/null | sort || true)"
  if [[ -n "${files}" ]]; then
    printf "%s\n" "${files}" >&2
    shown_lines=$((shown_lines + $(printf "%s\n" "${files}" | wc -l)))
  fi

  echo >&2
  shown_lines=$((shown_lines + 2))

  ssha::log_ok "Aperçu config (si présent):"
  shown_lines=$((shown_lines + 1))

  if [[ -f "${dir}/config" ]]; then
    echo "----- ${dir}/config -----" >&2
    local cfg_preview
    cfg_preview="$(sed -n '1,200p' "${dir}/config" 2>/dev/null || true)"
    if [[ -n "${cfg_preview}" ]]; then
      printf "%s\n" "${cfg_preview}" >&2
      shown_lines=$((shown_lines + $(printf "%s\n" "${cfg_preview}" | wc -l)))
    fi
    echo "-------------------------" >&2
    shown_lines=$((shown_lines + 2))
  else
    ssha::log_warn "Pas de fichier config."
    shown_lines=$((shown_lines + 1))
  # ... ton code existant
  
  fi
  
  ssha::pause_if_lines_exceed "${shown_lines}"
}





# --- ssha::ssh_backup_root
# Dossier racine des backups (~/.ssh_backup).

ssha::ssh_backup_root() {
  echo "${HOME}/.ssh_backup"
}


# --- ssha::ssh_backup_dir_wipe
# Sous-dossier backups wipe (~/.ssh_backup/wipe).

ssha::ssh_backup_dir_wipe() {
  echo "$(ssha::ssh_backup_root)/wipe"
}


# --- ssha::ssh_backup_dir_manual
# Sous-dossier backups manuels (~/.ssh_backup/manual).

ssha::ssh_backup_dir_manual() {
  echo "$(ssha::ssh_backup_root)/manual"
}


# --- ssha::ssh_backup_make
# Crée un backup 'wipe' (mv) ou 'manual' (cp -a) en DRY-RUN safe.

ssha::ssh_backup_make() {
  local kind="$1" # wipe | manual
  local dir="${SSHA_SSH_DIR}"

  if [[ ! -d "${dir}" ]]; then
    ssha::log_warn "Le dossier n'existe pas: ${dir}"
    return 0
  fi

  local base
  case "${kind}" in
    wipe)   base="$(ssha::ssh_backup_dir_wipe)" ;;
    manual) base="$(ssha::ssh_backup_dir_manual)" ;;
    *) ssha::log_err "Type backup inconnu: ${kind}"; return 1 ;;
  esac

  ssha::maybe_run mkdir -p "${base}"

  local ts backup
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")"
  backup="${base}/ssh-${ts}"

  ssha::log_ok "Sauvegarde -> ${backup}"

  if [[ "${kind}" == "wipe" ]]; then
    ssha::maybe_run mv "${dir}" "${backup}"
  else
    ssha::maybe_run cp -a "${dir}" "${backup}"
  fi

  ssha::log_ok "OK."
}


# --- ssha::ssh_backup_list
# Liste les backups disponibles (wipe + manual).

ssha::ssh_backup_list() {
  ssha::screen_title "Backups SSH disponibles"

  local root
  root="$(ssha::ssh_backup_root)"

  if [[ ! -d "${root}" ]]; then
    ssha::log_warn "Aucun dossier de backup trouvé."
    return 0
  fi

  ssha::c_blue >&2
  echo "Type     | Date / Dossier" >&2
  echo "--------------------------" >&2
  ssha::c_reset >&2

  find "${root}" -mindepth 2 -maxdepth 2 -type d | sort | while read -r d; do
    case "${d}" in
      */wipe/*)   printf "wipe     | %s\n" "$(basename "${d}")" >&2 ;;
      */manual/*) printf "manual   | %s\n" "$(basename "${d}")" >&2 ;;
    esac
  done
}


# --- ssha::ssh_backup_restore
# Restaure un backup (avec sauvegarde du .ssh courant avant restore).

ssha::ssh_backup_restore() {
  ssha::screen_title_inline_danger "RESTAURATION DU DOSSIER SSH"

  ssha::ssh_backup_list
  echo >&2

  local name
  name="$(ssha::prompt_required_text "Nom exact du dossier backup à restaurer")"

  local root
  root="$(ssha::ssh_backup_root)"

  local src
  src="$(find "${root}" -mindepth 2 -maxdepth 2 -type d -name "${name}" | head -n1)"

  if [[ -z "${src}" ]]; then
    ssha::log_err "Backup introuvable: ${name}"
    return 1
  fi

  ssha::log_warn "Le dossier SSH actuel sera sauvegardé avant restauration."
  ssha::danger_countdown

  local confirm
  confirm="$(ssha::prompt_wipe_confirm)"
  [[ "${confirm}" == "WIPE" ]] || { ssha::log_warn "Annulé."; return 0; }

  ssha::ssh_backup_make "manual"

  rm -rf "${SSHA_SSH_DIR}"
  cp -a "${src}" "${SSHA_SSH_DIR}"
  chmod 700 "${SSHA_SSH_DIR}"

  ssha::log_ok "Restauration terminée depuis ${name}"
}


# --- ssha::ssh_dir_wipe
# Option 7: déplace ~/.ssh vers backup wipe + recrée un ~/.ssh vide.

ssha::ssh_dir_wipe() {
  ssha::screen_title_inline_danger "DANGER: effacement du dossier SSH"

  local dir="${SSHA_SSH_DIR}"
  if [[ ! -d "${dir}" ]]; then
    ssha::log_warn "Le dossier n'existe pas: ${dir}"
    ssha::history_log "WIPE ssh_dir: dir missing (${dir})"
    return 0
  fi

  ssha::log_warn "Cette action va SUPPRIMER: ${dir}"
  ssha::log_warn "Toutes tes clés/known_hosts/config seront perdues."
  ssha::log_warn "Une sauvegarde sera créée automatiquement (wipe)."

  if declare -F ssha::danger_countdown >/dev/null 2>&1; then
    ssha::danger_countdown
  fi

  local confirm
  confirm="$(ssha::prompt_wipe_confirm)"
  if [[ "${confirm}" != "WIPE" ]]; then
    ssha::log_warn "Annulé."
    ssha::history_log "WIPE ssh_dir: cancelled"
    ssha::pause
    return 0
    
  fi

  local base ts backup
  base="$(ssha::ssh_backup_dir_wipe)"
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")"
  backup="${base}/ssh-${ts}"

  ssha::maybe_run mkdir -p "${base}"

  ssha::log_ok "Sauvegarde (wipe) -> ${backup}"
  ssha::history_log "WIPE ssh_dir: backup -> ${backup}"
  ssha::maybe_run mv "${dir}" "${backup}"

  ssha::log_ok "Recréation d'un dossier SSH vide: ${dir}"
  ssha::maybe_run mkdir -p "${dir}"
  ssha::maybe_run chmod 700 "${dir}"

  ssha::log_ok "Terminé. (Sauvegarde dans ${base})"
  ssha::history_log "WIPE ssh_dir: done (recreated empty ${dir})"
}




# --- ssha::option_keys_list
# Liste les clés privées présentes dans ~/.ssh (hors .pub/known_hosts/etc).

ssha::option_keys_list() {
  local dir="${SSHA_SSH_DIR:-$HOME/.ssh}"
  if [[ ! -d "${dir}" ]]; then
    ssha::log_err "SSH directory not found: ${dir}"
    return 1
  fi

  ssha::log_ok "Listing keys in ${dir}"
  echo

  find "${dir}" -maxdepth 1 -type f \
    ! -name "*.pub" ! -name "known_hosts" ! -name "config" ! -name "authorized_keys" \
    -printf "%f\n" 2>/dev/null | sort || true

  echo
}

# --- Tests SSH : tests de connexions
#
# Pourquoi le test SAFE (ssh -G) ?
# - Il valide le fichier ~/.ssh/config et ton alias (Host) sans ouvrir de connexion.
# - Ça évite de confondre une config cassée avec un problème réseau / autorisation.
#
# Pourquoi le test réel échoue après un WIPE ?
# - known_hosts est vide : OpenSSH veut confirmer l'empreinte du serveur.
# - En BatchMode, il ne peut pas demander "yes/no".
# - Solution: StrictHostKeyChecking=accept-new pour enregistrer automatiquement l'empreinte.

ssha::ensure_known_hosts_files() {
  local dir="${SSHA_SSH_DIR}"
  [[ -d "${dir}" ]] || return 0
  [[ -f "${dir}/known_hosts" ]]  || : > "${dir}/known_hosts"
  [[ -f "${dir}/known_hosts2" ]] || : > "${dir}/known_hosts2"
  chmod 600 "${dir}/known_hosts" 2>/dev/null || true
  chmod 600 "${dir}/known_hosts2" 2>/dev/null || true
}

ssha::ssh_test_safe_config() {
  local host="${1:-}"
  [[ -n "${host}" ]] || { ssha::log_err "ssh_test_safe_config: host manquant"; return 2; }
  ssh -G "${host}" >/dev/null 2>&1
}

ssha::ssh_config_resolve() {
  # sort: user|hostname|port|identityfile
  local host="${1:-}"
  [[ -n "${host}" ]] || { ssha::log_err "ssh_config_resolve: host manquant"; return 2; }

  local g user hostname port identity
  g="$(ssh -G "${host}" 2>/dev/null || true)"

  user="$(printf '%s\n' "${g}" | awk '$1=="user"{print $2; exit}')"
  hostname="$(printf '%s\n' "${g}" | awk '$1=="hostname"{print $2; exit}')"
  port="$(printf '%s\n' "${g}" | awk '$1=="port"{print $2; exit}')"
  identity="$(printf '%s\n' "${g}" | awk '$1=="identityfile"{print $2; exit}')"

  printf '%s|%s|%s|%s\n' "${user}" "${hostname}" "${port}" "${identity}"
}

# --- ssha::ssh_output_indicates_success
# Git providers (GitHub/GitLab/Bitbucket) often return exit status 1 even when the key is accepted.
# We treat certain known messages as SUCCESS.
ssha::ssh_output_indicates_success() {
  local out="${1:-}"
  [[ -n "${out}" ]] || return 1

  if printf '%s' "${out}" | grep -qiE 'successfully authenticated|welcome to gitlab|logged in as'; then
    return 0
  fi
  return 1
}

ssha::ssh_test_real_via_host() {
  local host="${1:-}"
  [[ -n "${host}" ]] || { ssha::log_err "ssh_test_real_via_host: host manquant"; return 2; }

  ssha::ensure_known_hosts_files

  local out rc
  out="$(
    ssh \
      -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes \
      -o PreferredAuthentications=publickey \
      -o PasswordAuthentication=no \
      -o KbdInteractiveAuthentication=no \
      -o ConnectTimeout=8 \
      -T "${host}" </dev/null 2>&1
  )"
  rc=$?

  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi

  if ssha::ssh_output_indicates_success "${out}"; then
    return 0
  fi

  return 1
}

# Test réel (publickey forcé) : cible "target" = git@github.com OU user@host
ssha::ssh_test_real_publickey_direct() {
  local target="${1:-}"
  local port="${2:-}"
  local identity="${3:-}"

  [[ -n "${target}" && -n "${port}" && -n "${identity}" ]] || {
    ssha::log_err "ssh_test_real_publickey_direct: arguments manquants (target/port/identity)"
    return 2
  }

  ssha::ensure_known_hosts_files

  local out rc
  out="$(
    ssh \
      -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes \
      -o PreferredAuthentications=publickey \
      -o PasswordAuthentication=no \
      -o KbdInteractiveAuthentication=no \
      -o IdentitiesOnly=yes \
      -o ConnectTimeout=8 \
      -i "${identity}" \
      -p "${port}" \
      -T "${target}" </dev/null 2>&1
  )"
  rc=$?

  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi

  if ssha::ssh_output_indicates_success "${out}"; then
    return 0
  fi

  return 1
}

ssha::is_git_provider_host() {
  local h="${1:-}"
  [[ -n "${h}" ]] || return 1
  case "${h}" in
    github.com|gitlab.com|bitbucket.org) return 0 ;;
  esac
  return 1
}

ssha::ssh_userhost_for_provider() {
  local user="${1:-}"
  local hostname="${2:-}"
  if ssha::is_git_provider_host "${hostname}"; then
    printf 'git@%s\n' "${hostname}"
  else
    printf '%s@%s\n' "${user}" "${hostname}"
  fi
}

ssha::ssh_warn_real_fail_context() {
  local hostname="${1:-}"
  if ssha::is_git_provider_host "${hostname}"; then
    ssha::log_warn "Causes fréquentes (Git provider): clé non ajoutée au compte, mauvaise IdentityFile, ou clé refusée."
    ssha::log_warn "Astuce: sur GitHub/GitLab/Bitbucket, la réussite peut afficher un message mais retourner un code != 0."
  else
    ssha::log_warn "Causes fréquentes: clé pas encore ajoutée côté serveur, mauvais user/port, accès SSH non activé."
  fi
}

ssha::ssh_test_interactive_offer() {
  local host="${1:-}"
  local pubpath="${2:-}"
  [[ -n "${host}" ]] || { ssha::log_err "ssh_test_interactive_offer: host manquant"; return 2; }

  echo >&2
  ssha::log_ok "Test SAFE (ssh -G) pour: ${host}"
  if ! ssha::ssh_test_safe_config "${host}"; then
    ssha::log_err "NOK: config invalide pour ${host}"
    return 0
  fi

  ssha::banner_config_ok_green "${host}"

  local resolved user hostname port identity
  resolved="$(ssha::ssh_config_resolve "${host}")"
  IFS='|' read -r user hostname port identity <<<"${resolved}"

  echo >&2
  ssha::log_ok "Résolution (ssh -G):"
  printf "  user     = %s\n" "${user}" >&2
  printf "  hostname = %s\n" "${hostname}" >&2
  printf "  port     = %s\n" "${port}" >&2
  printf "  identity = %s\n" "${identity}" >&2

  if [[ -n "${identity}" && ! -f "${identity}" ]]; then
    ssha::log_warn "IdentityFile introuvable: ${identity}"
    return 0
  fi

  local target
  target="$(ssha::ssh_userhost_for_provider "${user}" "${hostname}")"

  while true; do
    echo >&2
    echo "1) Test réel (via config, accept-new)" >&2
    echo "2) Test réel (publickey forcé, accept-new)" >&2
    echo "3) Afficher la clé publique à coller (rappel)" >&2
    echo "0) Retour" >&2
    echo >&2

    local c
    c="$(ssha::prompt_required_choice "Choix")"

    case "${c}" in
      1)
        if ssha::is_git_provider_host "${hostname}"; then
          ssha::log_ok "Test réel (Git provider) pour: ${target}"
          if ssha::ssh_test_real_via_host "${target}"; then
            ssha::banner_conn_ok_green "${target}"
          else
            ssha::banner_conn_refused_red "${target}"
            ssha::ssh_warn_real_fail_context "${hostname}"
          fi
        else
          ssha::log_ok "Test réel (BatchMode, accept-new) pour: ${host}"
          if ssha::ssh_test_real_via_host "${host}"; then
            ssha::banner_conn_ok_green "${host}"
          else
            ssha::banner_conn_refused_red "${host}"
            ssha::ssh_warn_real_fail_context "${hostname}"
          fi
        fi
        ;;
      2)
        ssha::log_ok "Test réel (publickey forcé) pour: ${target}:${port}"
        if ssha::ssh_test_real_publickey_direct "${target}" "${port}" "${identity}"; then
          ssha::banner_auth_ok_green
        else
          ssha::banner_auth_refused_red "${target}"
          ssha::ssh_warn_real_fail_context "${hostname}"
        fi
        ;;
      3)
        # Si pubpath non fourni → on tente de le reconstruire depuis identity
        if [[ -z "${pubpath}" && -n "${identity}" ]]; then
          pubpath="${identity}.pub"
        fi

        if [[ -n "${pubpath}" && -f "${pubpath}" ]]; then
          ssha::print_public_key "${pubpath}"
        else
          ssha::log_warn "Clé publique introuvable (${pubpath})."
        fi
        ;;
      0) break ;;
      *) ssha::blink_error_red ;;
    esac
  done

  return 0
}

ssha::screen_notice_red() {
  local msg="$1"
  local len line

  len=${#msg}
  line="$(printf '%*s' "${len}" '' | tr ' ' '=')"

  if ssha::colors_enabled; then
    ssha::c_red >&2
  fi

  printf '\n%s\n%s\n%s\n\n' "${line}" "${msg}" "${line}" >&2

  if ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}

# --- ssha::banner_pubkey_copied_red
# Bannière rouge quand la clé publique est copiée (à coller chez le provider).

ssha::banner_pubkey_copied_red() {
  if ssha::colors_enabled; then ssha::c_red >&2; fi
  printf '████████████████████████████████████████████████████████████████\n' >&2
  printf '            CLÉ PUBLIQUE COPIÉE DANS LE PRESSE-PAPIER           \n' >&2
  printf '              COLLEZ-LA MAINTENANT CHEZ VOTRE HÔTE              \n' >&2
  printf '               RAFRAÎCHIR LA PAGE WEB SI BESOIN                 \n' >&2
  printf '████████████████████████████████████████████████████████████████\n' >&2
  if ssha::colors_enabled; then ssha::c_reset >&2; fi
  echo >&2
}

# --- ssha::banner_pubkey_copy_failed_red
# Bannière rouge si la copie auto est impossible.

ssha::banner_pubkey_copy_failed_red() {
  if ssha::colors_enabled; then ssha::c_red >&2; fi
  printf '████████████████████████████████████████████████████████████████\n' >&2
  printf '            COPIE AUTOMATIQUE IMPOSSIBLE (CLIPBOARD)            \n' >&2
  printf '             COPIEZ LA CLÉ CI-DESSUS ET COLLEZ-LA               \n' >&2
  printf '████████████████████████████████████████████████████████████████\n' >&2
  if ssha::colors_enabled; then ssha::c_reset >&2; fi
  echo >&2
}

# --- ssha::banner_auth_ok_green
# Bannière verte quand l’authentification SSH est réussie.

ssha::banner_auth_ok_green() {
  ssha::_banner_green_block \
    "PUBLICKEY ACCEPTÉE PAR LE SERVEUR" \
    "AUTHENTIFICATION SSH RÉUSSIE"
}

# --- ssha::banner_config_ok_green
# Bannière verte quand ssh -G valide la config pour un host

ssha::banner_config_ok_green() {
  local host="${1:-}"
  ssha::_banner_green_block \
    "CONFIG SSH VALIDE" \
    "ssh -G OK (alias correctement resolu)" \
    "${host}"
}

# --- ssha::banner_conn_ok_green
# Bannière verte quand la connexion SSH est acceptée

ssha::banner_conn_ok_green() {
  local host="${1:-}"
  ssha::_banner_green_block \
    "CONNEXION SSH ACCEPTÉE" \
    "Authentification reussie" \
    "${host}"
}

# --- BANNIERES ROUGES (refus)

ssha::banner_conn_refused_red() {
  local host="${1:-}"
  ssha::_banner_red_block \
    "CONNEXION SSH REFUSÉE" \
    "Le serveur a rejeté la connexion" \
    "${host}"
}

ssha::banner_auth_refused_red() {
  local host="${1:-}"
  ssha::_banner_red_block \
    "AUTHENTIFICATION REFUSÉE" \
    "La clé n'est pas acceptée (publickey)" \
    "${host}"
}



# --- ssha::main
# Boucle principale: bannière, menu, dispatch des options.

ssha::main() {
  ssha::detect_platform

  SSHA_SSH_DIR="${SSHA_SSH_DIR:-$HOME/.ssh}"
  export SSHA_SSH_DIR

  while true; do
    ssha::banner
    ssha::menu

    local choice rc=0
    choice="$(ssha::prompt_required_choice "Choix")"

    case "${choice}" in
      1) ssha::option_create_key_and_config ;;
      2) ssha::providers_menu ;;
      3) ssha::option_ssh_test_menu ;;
      4) ssha::ssh_dir_show ;;
      5) ssha::ssh_dir_backup_manual ;;
      6) ssha::ssh_dir_wipe ;;
      0) return 0 ;;
      *) ssha::log_warn "Choix invalide." ;;
    esac

    if [[ "${rc}" != "0" ]]; then
      ssha::log_warn "Action terminée avec erreur (code ${rc}). Retour au menu."
    fi

  done
}



# --- ssha::term_supports_blink

ssha::term_supports_blink() {
  return 1
}

ssha::ssh_config_list_hosts() {
  local cfg
  cfg="$(ssha::config_path)"
  [[ -f "${cfg}" ]] || return 0

  awk '
    /^[[:space:]]*Host[[:space:]]+/{
      for (i=2;i<=NF;i++){
        if ($i !~ /[*?]/) print $i
      }
    }
  ' "${cfg}" | sort -u
}


ssha::ssh_dir_backup_manual() {
  ssha::screen_title "Sauvegarde volontaire du dossier SSH"
  ssha::ssh_backup_make "manual"
  ssha::history_log "backup manual ssh_dir"
  ssha::pause
}

ssha::option_ssh_test_menu() {
  ssha::screen_title "Test de connexion SSH"

  local -a hosts
  mapfile -t hosts < <(ssha::ssh_config_list_hosts)

  if [[ "${#hosts[@]}" -eq 0 ]]; then
    ssha::log_warn "Aucun host trouvé dans $(ssha::config_path)"
    return 0
  fi

  ssha::c_blue >&2
  echo "Hosts détectés:" >&2
  local i
  for ((i=0; i<${#hosts[@]}; i++)); do
    printf "%d) %s\n" "$((i+1))" "${hosts[i]}" >&2
  done
  echo "0) Retour" >&2
  ssha::c_reset >&2
  echo >&2

  local choice
  choice="$(ssha::prompt_required_choice "Choix")"

  [[ "${choice}" == "0" ]] && return 0

  if (( choice >= 1 && choice <= ${#hosts[@]} )); then
    ssha::ssh_test_interactive_offer "${hosts[choice-1]}"
    return $?
  fi

  ssha::log_warn "Choix invalide."
  return 1
}

ssha::print_auth_success_banner() {
  if ssha::colors_enabled; then
    ssha::c_green >&2
  fi

  printf '\n' >&2
  printf '████████████████████████████████████████████████████████\n' >&2
  printf '        PUBLICKEY ACCEPTÉE PAR LE SERVEUR              \n' >&2
  printf '          AUTHENTIFICATION SSH RÉUSSIE                 \n' >&2
  printf '████████████████████████████████████████████████████████\n\n' >&2

  if ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}

# Retourne 0 si un IdentityFile est trouvé et existe
ssha::ssh_host_has_key() {
  local host="${1:-}"
  [[ -n "${host}" ]] || return 1

  local g identity
  g="$(ssh -G "${host}" 2>/dev/null || true)"
  identity="$(printf '%s\n' "${g}" | awk '$1=="identityfile"{print $2; exit}')"

  [[ -n "${identity}" && -f "${identity}" ]]
}

# Retourne "OK" / "NOK" (texte simple)
ssha::oui_non() {
  if [[ "${1:-0}" == "1" ]]; then
    printf 'oui'
  else
    printf 'non'
  fi
}

# --- ssha::_pad_visible
# Pad à droite sur largeur "width" en comptant uniquement les caractères visibles (sans couleurs)
ssha::_pad_visible() {
  local s="$1"
  local width="$2"
  local len=${#s}
  local pad=0
  (( width > len )) && pad=$((width - len))
  printf '%s%*s' "${s}" "${pad}" ''
}

# --- ssha::cell_yesno
# Retourne une cellule "✔ oui" / "✖ non" colorée, MAIS alignée sur une largeur fixe.
# Usage: ssha::cell_yesno 1 22  (true, width)

ssha::cell_yesno() {
  local yes="${1:-0}"
  local width="${2:-22}"

  local raw padded

  if [[ "${yes}" == "1" ]]; then
    raw="[OK]"
  else
    raw="[NO]"
  fi

  padded="$(ssha::_pad_visible "${raw}" "${width}")"

  if ssha::colors_enabled; then
    if [[ "${yes}" == "1" ]]; then
      ssha::c_green >&2
    else
      ssha::c_red >&2
    fi
  fi

  printf '%s' "${padded}" >&2

  if ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}

ssha::cell_text() {
  local text="${1:-}"
  local width="${2:-22}"
  printf '%s' "$(ssha::_pad_visible "${text}" "${width}")" >&2
}

# --- ssha::ssh_config_find_duplicate_hosts
# Liste les alias Host présents plusieurs fois dans ~/.ssh/config

ssha::ssh_config_find_duplicate_hosts() {
  local cfg
  cfg="$(ssha::config_path)"
  [[ -f "${cfg}" ]] || return 0

  awk '
    /^[[:space:]]*Host[[:space:]]+/{
      for (i=2; i<=NF; i++) {
        if ($i !~ /[*?]/) print $i
      }
    }
  ' "${cfg}" | sort | uniq -d
}

# --- ssha::ssh_config_show_duplicate_hosts
# Affiche les alias Host en doublon

ssha::ssh_config_show_duplicate_hosts() {
  ssha::screen_title "Doublons dans ~/.ssh/config"

  local -a dups
  mapfile -t dups < <(ssha::ssh_config_find_duplicate_hosts)

  if [[ "${#dups[@]}" -eq 0 ]]; then
    ssha::log_ok "Aucun doublon détecté."
    return 0
  fi

  ssha::log_warn "Alias en doublon détectés :"
  local h
  for h in "${dups[@]}"; do
    printf '  - %s\n' "${h}" >&2
  done
}

# --- ssha::pause
# Pause interactive pour lire un écran avant retour menu.



# --- ssha::term_rows
# Retourne le nombre de lignes du terminal (fallback: 24)

ssha::term_rows() {
  local rows
  rows="$(tput lines 2>/dev/null || true)"
  [[ "${rows}" =~ ^[0-9]+$ ]] || rows=24
  printf '%s\n' "${rows}"
}

# --- ssha::pause
# Pause simple

ssha::pause() {
  echo >&2
  read -r -p "Entrée pour continuer..." _ >&2
}

# --- ssha::pause_if_lines_exceed
# Pause seulement si le nombre de lignes affichées dépasse la hauteur utile du terminal

ssha::pause_if_lines_exceed() {
  local shown_lines="${1:-0}"
  local rows margin threshold

  rows="$(ssha::term_rows)"
  margin=4
  threshold=$((rows - margin))

  if (( shown_lines >= threshold )); then
    ssha::pause
  fi
}

ssha::doctor() {
  ssha::screen_title "Diagnostic SSH (doctor)"

  local dir="${SSHA_SSH_DIR:-$HOME/.ssh}"

  echo "🔍 Vérifications..." >&2
  echo >&2

  if command -v ssh >/dev/null 2>&1; then
    ssha::log_ok "ssh installé"
  else
    ssha::log_err "ssh introuvable"
  fi

  if [[ -d "${dir}" ]]; then
    ssha::log_ok "dossier ~/.ssh présent"
  else
    ssha::log_err "dossier ~/.ssh absent"
  fi

  if [[ -d "${dir}" ]]; then
    perms="$(stat -c "%a" "${dir}" 2>/dev/null || echo "unknown")"
    ssha::log_info "permissions ~/.ssh : ${perms}"
  fi

  if [[ -f "${dir}/config" ]]; then
    ssha::log_ok "fichier config présent"
  else
    ssha::log_warn "pas de config SSH"
  fi

  local keys
  keys="$(find "${dir}" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" 2>/dev/null || true)"

  if [[ -n "${keys}" ]]; then
    ssha::log_ok "clés privées détectées"
  else
    ssha::log_warn "aucune clé privée trouvée"
  fi

  echo >&2
  ssha::log_ok "Diagnostic terminé"

  ssha::pause
}