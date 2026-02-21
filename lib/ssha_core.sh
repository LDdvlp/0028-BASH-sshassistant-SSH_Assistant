#!/usr/bin/env bash
set -euo pipefail

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
    MINGW*|MSYS*) SSHA_PLATFORM="gitbash" ;;
    CYGWIN*)      SSHA_PLATFORM="cygwin" ;;
    Linux*)       SSHA_PLATFORM="linux" ;;
    Darwin*)      SSHA_PLATFORM="mac" ;;
    *)            SSHA_PLATFORM="unknown" ;;
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
# Affiche le menu principal (inclut statut DRY-RUN).

ssha::menu() {
  ssha::c_blue
  echo "1) Création de la paire de clé + config host"
  echo "2) Test de connexion SSH (depuis config)"
  echo "4) Providers: GitHub / GitLab / Bitbucket (guide)"
  echo "5) Providers: status / test"
  echo "6) Proc: shells en cours"
  echo "7) SSH: afficher le dossier ~/.ssh"
  echo "8) SSH: effacer le dossier ~/.ssh (DANGEREUX)"
  echo "9) SSH: sauvegarder le dossier ~/.ssh (volontaire)"
  local dr="OFF"
  ssha::dry_run_is_on && dr="ON"
  echo "10) DRY-RUN: ${dr} (toggle)"
  echo "11) Historique: afficher"
  echo "0) Quit"
  ssha::c_reset
  echo
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
    printf '%s [%s]: ' "${label}" "${default}" >&2
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

    # "pas une chaîne de caractères" en Bash = on interprète comme "vide / rien saisi"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi

    # message d'erreur juste en dessous
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

    # vide -> erreur
    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    # purement numérique -> erreur (ton cas)
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

    # trim espaces
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # vide -> erreur
    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    # non numérique -> erreur
    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
      ssha::blink_error_red
      continue
    fi

    # hors plage -> erreur
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
    # ⚠️ pas de valeur par défaut
    value="$(ssha::prompt "${label}" "")"

    # trim espaces
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # vide -> erreur
    if [[ -z "${value}" ]]; then
      ssha::blink_error_red
      continue
    fi

    # non numérique -> erreur
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
  # Menu sur STDERR (pour fonctionner avec enc="$(...)")
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
  local enc="$1"
  local name="$2"
  local base="${SSHA_SSH_DIR}/${enc}_${name}"
  echo "${base}"$'\n'"${base}.pub"
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


# --- ssha::option_create_key_and_config
# Option 1: crée une paire de clés + écrit le Host dans config + copie la pubkey.

ssha::option_create_key_and_config() {

  ssha::screen_title "Création de la paire de clé et génération du fichier config"

  local host_alias hostname username port enc keyname comment
  local keypath pubpath cfg
  local -a paths
  local SKIP_KEYGEN=0


  host_alias="$(ssha::prompt_required_text "Nom de l'hote (alias dans ~/.ssh/config) ex: planethoster")"
  hostname="$(ssha::prompt_required_text "Adresse du serveur (HostName) ex: node266-eu.n0c.com")"
  username="$(ssha::prompt_required_text "Nom utilisateur SSH (User) ex: dwmkyvke")"    
  port="$(ssha::prompt_required_port "Port SSH (Port)" "22")"

  enc="$(ssha::choose_encoding)"
  keyname="$(ssha::prompt_required_text "Nom de la clé (ex: planethoster)")"
  comment="$(ssha::prompt "Commentaire (ssh-keygen -C)" "${username}@${host_alias}")"

  mapfile -t paths < <(ssha::key_paths "${enc}" "${keyname}")
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
        # on saute ssh-keygen plus bas
        SKIP_KEYGEN=1
        ;;
      3)
        ssha::log_warn "Écrasement demandé: backup puis régénération."
        ssha::backup_existing_keypair "${keypath}" "${pubpath}"
        # on continue, ssh-keygen va régénérer
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
  if ssha::copy_to_clipboard "$(cat "${pubpath}")"; then
    ssha::print_pubkey_copied_banner
  else
    ssha::screen_notice_red "COPIE AUTOMATIQUE IMPOSSIBLE – COPIEZ LA CLÉ CI-DESSUS ET COLLEZ-LA CHEZ VOTRE HÔTE"
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

  # Print: id|label|hostname|user|port|keyname
  grep -vE '^[[:space:]]*#' "${conf}" | grep -vE '^[[:space:]]*$' || true
}


# --- ssha::providers_menu
# Option 3: menu guidé pour générer config/clé via providers.conf.

ssha::providers_menu() {
  local -a ids labels lines
  local i=0 line id label hostname user port keyname

  while IFS= read -r line; do
    ids[i]="$(printf '%s' "${line}" | cut -d'|' -f1)"
    labels[i]="$(printf '%s' "${line}" | cut -d'|' -f2)"
    lines[i]="${line}"
    i=$((i+1))
  done < <(ssha::providers_list)

  if [[ "${#ids[@]}" -eq 0 ]]; then
    ssha::log_err "Aucun provider dans assets/providers.conf"
    return 1
  fi

  echo
  ssha::c_blue
  echo "Providers (guide):"
  for ((i=0; i<${#ids[@]}; i++)); do
    printf '%d) %s\n' "$((i+1))" "${labels[i]}"
  done
  printf '%d) %s\n' "$(( ${#ids[@]} + 1 ))" "Tout (generer pour tous)"
  echo "0) Retour"
  ssha::c_reset
  echo

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

  if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice == ${#ids[@]} + 1 )); then
    local rc=0
    for ((i=0; i<${#ids[@]}; i++)); do
      ssha::provider_apply_line "${lines[i]}" || rc=1
    done
    return "${rc}"
  fi

  ssha::log_warn "Choix invalide."
  return 1
}


# --- ssha::provider_apply_line
# Applique une ligne provider: génère clé + écrit 2 Host (id + hostname).

ssha::provider_apply_line() {
  local line="$1"
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${line}"

  # Validation (anti-casse config)
  if [[ -z "${id}" || -z "${label}" || -z "${hostname}" || -z "${username}" || -z "${port}" || -z "${keyname}" ]]; then
    ssha::log_err "Provider invalide (champ vide) dans providers.conf: ${line}"
    return 1
  fi

  # Encodage fixe en mode guidé (recommandé)
  local enc="ed25519"

  # Paths
  local keypath pubpath

  mapfile -t _paths < <(ssha::key_paths "${enc}" "${keyname}")
  keypath="${_paths[0]}"
  pubpath="${_paths[1]}"

  ssha::ensure_ssh_dir "${SSHA_SSH_DIR}"

  if [[ -e "${keypath}" || -e "${pubpath}" ]]; then
    ssha::log_warn "Cle existe deja, skip: ${keypath}"
  else
    ssha::log_ok "Generation cle ${label}: ${keypath}"
    ssha::run_ssh_keygen "${enc}" "${keypath}" "${username}@${hostname}"
  fi

  local cfg
  cfg="$(ssha::config_path)"
  touch "${cfg}"
  chmod 600 "${cfg}" 2>/dev/null || true

  # Remove + append TWO host blocks:
  # - alias: Host <id>
  # - domain: Host <hostname>
  ssha::log_ok "Maj config pour ${label}: Host ${id} + Host ${hostname}"

  ssha::remove_host_block "${cfg}" "${id}"
  ssha::append_host_block "${cfg}" "${id}" "${hostname}" "${username}" "${port}" "${keypath}"

  ssha::remove_host_block "${cfg}" "${hostname}"
  ssha::append_host_block "${cfg}" "${hostname}" "${hostname}" "${username}" "${port}" "${keypath}"

  # Print public key (copy/paste)
  if [[ -f "${pubpath}" ]]; then
    local pubkey
    pubkey="$(cat "${pubpath}")"
    if ssha::copy_to_clipboard "${pubkey}"; then
      ssha::log_ok "La clé publique a été copiée et est prête à être collée chez votre hôte."
    else
      ssha::log_warn "La clé publique est affichée. Copiez-la et collez-la chez votre hôte."
    fi
  fi
}


# --- ssha::provider_keypath
# Renvoie le chemin de la clé privée d'un provider (ed25519 par défaut).

ssha::provider_keypath() {
  local enc="$1"
  local keyname="$2"
  local -a p
  mapfile -t p < <(ssha::key_paths "${enc}" "${keyname}")
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
  # BatchMode: no password prompts
  ssh -o BatchMode=yes -T "${host}" >/dev/null 2>&1
}


# --- ssha::provider_status_line
# Retourne un statut parseable pour un provider (clé/config ok).

ssha::provider_status_line() {
  local line="$1"
  local id label hostname username port keyname
  IFS='|' read -r id label hostname username port keyname <<<"${line}"

  local enc="ed25519"
  local keypath
  keypath="$(ssha::provider_keypath "${enc}" "${keyname}")"

  local ok_key=0 ok_id=0 ok_host=0
  [[ -f "${keypath}" ]] && ok_key=1
  ssha::ssh_config_ok "${id}" && ok_id=1
  ssha::ssh_config_ok "${hostname}" && ok_host=1

  # Print: label | key | host(id) | host(domain)
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

  # Tableau status
  if ssha::colors_enabled; then ssha::c_blue >&2; fi
  printf "N\tProvider\tKey\tHost(id)\tHost(domain)\n" >&2
  printf "----------------------------------------------------------\n" >&2
  if ssha::colors_enabled; then ssha::c_reset >&2; fi

  local i st id label hostname ok_key ok_id ok_host keypath
  for ((i=0; i<${#lines[@]}; i++)); do
    st="$(ssha::provider_status_line "${lines[i]}")"
    IFS='|' read -r id label hostname ok_key ok_id ok_host keypath <<<"${st}"

    # Affichage OK/NOK (sans emoji pour rester clean)
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
    ssha::ssh_config_ok "${id}" && ssha::log_ok "  OK: ${id}" || ssha::log_err "  NOK: ${id}"
    ssha::ssh_config_ok "${hostname}" && ssha::log_ok "  OK: ${hostname}" || ssha::log_err "  NOK: ${hostname}"
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
  if [[ ! -d "${dir}" ]]; then
    ssha::log_warn "Le dossier n'existe pas: ${dir}"
    return 0
  fi

  ssha::log_ok "Contenu (trié):"
  echo >&2
  find "${dir}" -maxdepth 1 -type f -print 2>/dev/null | sort >&2

  echo >&2
  ssha::log_ok "Aperçu config (si présent):"
  if [[ -f "${dir}/config" ]]; then
    echo "----- ${dir}/config -----" >&2
    sed -n '1,200p' "${dir}/config" >&2
    echo "-------------------------" >&2
  else
    ssha::log_warn "Pas de fichier config."
  fi
}


# --- ssha::ssh_backup_root
# Dossier racine des backups (~/.ssh_backup).

ssha::ssh_backup_root() {
  # Dossier racine des backups
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

  mkdir -p "${base}"

  local ts backup
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")"
  backup="${base}/ssh-${ts}"

  ssha::log_ok "Sauvegarde -> ${backup}"
  # mv pour wipe (on déplace), cp pour manual (on copie)
  # Ici on choisit selon le kind :
  if [[ "${kind}" == "wipe" ]]; then
    mv "${dir}" "${backup}"
  else
    cp -a "${dir}" "${backup}"
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

  # backup du ssh actuel
  ssha::ssh_backup_make "manual"

  rm -rf "${SSHA_SSH_DIR}"
  cp -a "${src}" "${SSHA_SSH_DIR}"
  chmod 700 "${SSHA_SSH_DIR}"

  ssha::log_ok "Restauration terminée depuis ${name}"
}


# --- ssha::ssh_dir_wipe
# Option 7: déplace ~/.ssh vers backup wipe + recrée un ~/.ssh vide.

ssha::ssh_dir_wipe() {
  # Ecran danger (encadré, même longueur que le titre, rouge/inverse)
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

  # Petit “pulse” visuel (optionnel, mais recommandé)
  if declare -F ssha::danger_countdown >/dev/null 2>&1; then
    ssha::danger_countdown
  fi

  # Confirmation WIPE (WIPE en rouge + clignotant si possible / fallback inverse)
  local confirm
  confirm="$(ssha::prompt_wipe_confirm)"
  if [[ "${confirm}" != "WIPE" ]]; then
    ssha::log_warn "Annulé."
    ssha::history_log "WIPE ssh_dir: cancelled"
    return 0
  fi

  # Emplacement backup wipe
  local base ts backup
  base="$(ssha::ssh_backup_dir_wipe)"
  ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "backup")"
  backup="${base}/ssh-${ts}"

  # Création du dossier wipe/
  ssha::maybe_run mkdir -p "${base}"

  # Déplacement du .ssh -> backup (wipe)
  ssha::log_ok "Sauvegarde (wipe) -> ${backup}"
  ssha::history_log "WIPE ssh_dir: backup -> ${backup}"
  ssha::maybe_run mv "${dir}" "${backup}"

  # Recréation d'un .ssh vide
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

  # Show private keys (best-effort)
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

  # Messages seen after successful publickey auth:
  # - GitHub: "You've successfully authenticated, but GitHub does not provide shell access."
  # - GitLab: "Welcome to GitLab"
  # - Bitbucket: "logged in as"
  if printf '%s' "${out}" | grep -qiE 'successfully authenticated|welcome to gitlab|logged in as'; then
    return 0
  fi
  return 1
}



ssha::ssh_test_real_via_host() {
local host="${1:-}"
[[ -n "${host}" ]] || { ssha::log_err "ssh_test_real_via_host: host manquant"; return 2; }

# Capture output because some servers (notably git providers) return non-zero even on success.
local out rc
out="$(
  ssh           -o StrictHostKeyChecking=accept-new           -o BatchMode=yes           -o PreferredAuthentications=publickey           -o PasswordAuthentication=no           -o KbdInteractiveAuthentication=no           -o ConnectTimeout=8           -T "${host}" </dev/null 2>&1
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

ssha::ssh_test_real_publickey_direct() {
local user="${1:-}"
local hostname="${2:-}"
local port="${3:-}"
local identity="${4:-}"

[[ -n "${user}" && -n "${hostname}" && -n "${port}" && -n "${identity}" ]] || {
  ssha::log_err "ssh_test_real_publickey_direct: arguments manquants (user/hostname/port/identity)"
  return 2
}

local out rc
out="$(
  ssh           -o StrictHostKeyChecking=accept-new           -o BatchMode=yes           -o PreferredAuthentications=publickey           -o PasswordAuthentication=no           -o KbdInteractiveAuthentication=no           -o IdentitiesOnly=yes           -o ConnectTimeout=8           -i "${identity}"           -p "${port}"           -T "${user}@${hostname}" </dev/null 2>&1
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


# --- ssha::print_auth_success_banner
# Affiche la bannière verte "AUTHENTIFICATION SSH RÉUSSIE".
ssha::print_auth_success_banner() {
  # UI => STDERR
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_green >&2
  fi

  printf '████████████████████████████████████████████\n' >&2
  printf '      PUBLICKEY ACCEPTÉE PAR LE SERVEUR     \n' >&2
  printf '        AUTHENTIFICATION SSH RÉUSSIE        \n' >&2
  printf '████████████████████████████████████████████\n' >&2

  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}


ssha::print_pubkey_copied_banner() {
  # UI => STDERR : bannière rouge (clé copiée)
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_red >&2
  fi

  printf '██████████████████████████████████████████████████████████████████████████
' >&2
  printf ' LA CLÉ PUBLIQUE A ÉTÉ COPIÉE – COLLEZ-LA MAINTENANT CHEZ VOTRE HÔTE        
' >&2
  printf '██████████████████████████████████████████████████████████████████████████
' >&2

  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}


ssha::print_pubkey_copy_failed_banner() {
  # Bannière rouge: copie auto impossible (STDERR)
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_red >&2
  fi
  printf '===================================================================\n' >&2
  printf 'COPIE AUTOMATIQUE IMPOSSIBLE – COPIEZ LA CLÉ CI-DESSUS ET COLLEZ-LA\n' >&2
  printf '===================================================================\n\n' >&2
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi
}


ssha::ssh_test_interactive_offer() {
  local host="${1:-}"
  local pubpath="${2:-}"
  [[ -n "${host}" ]] || { ssha::log_err "ssh_test_interactive_offer: host manquant"; return 2; }
  local _ssha__printed_success=0

  echo >&2
  ssha::log_ok "Test SAFE (ssh -G) pour: ${host}"
  if ! ssha::ssh_test_safe_config "${host}"; then
    ssha::log_err "NOK: config invalide pour ${host}"
    return 1
  fi
  ssha::log_ok "OK: config valide pour ${host}"

  local resolved user hostname port identity
  resolved="$(ssha::ssh_config_resolve "${host}")"
  IFS='|' read -r user hostname port identity <<<"${resolved}"

  echo >&2
  ssha::log_ok "Résolution (ssh -G):"
  printf "  user     = %s\n" "${user}" >&2
  printf "  hostname = %s\n" "${hostname}" >&2
  printf "  port     = %s\n" "${port}" >&2
  printf "  identity = %s\n" "${identity}" >&2

  # Explication (affichée une seule fois à l'entrée du sous-menu)
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_blue >&2
  fi
  cat >&2 <<'EOF'

--- Explication des tests ---
• Test SAFE (ssh -G) : vérifie uniquement que ton ~/.ssh/config est VALIDE pour cet alias
  et te montre la résolution (user / hostname / port / IdentityFile). Il ne contacte pas le serveur.

• Test 1 (via alias, accept-new) : tente une connexion réelle en utilisant ton alias SSH.
  Cela applique toutes les options du bloc "Host <alias>" (IdentityFile, Port, etc.).

• Test 2 (publickey forcé, accept-new) : tente une connexion réelle en forçant
  "publickey seulement" + l'IdentityFile exact (-i) + user@hostname:port.
  Utile pour diagnostiquer les cas où l'agent / d'autres clés / des options globales perturbent le test.
EOF
  if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
    ssha::c_reset >&2
  fi

  if [[ -n "${identity}" && ! -f "${identity}" ]]; then
    ssha::log_warn "IdentityFile introuvable: ${identity}"
    return 0
  fi

  while true; do
    echo >&2
    if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
      ssha::c_blue >&2
    fi
    echo "1) Test réel (via alias, accept-new)" >&2
    echo "2) Test réel (publickey forcé, accept-new)" >&2
    echo "3) Afficher la clé publique à coller (rappel)" >&2
    echo "0) Retour" >&2
    if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
      ssha::c_reset >&2
    fi
    echo >&2

    local c
    c="$(ssha::prompt_required_choice "Choix")"

    case "${c}" in
      1)
        ssha::log_ok "Test réel (BatchMode, accept-new) pour: ${host}"
        if ssha::ssh_test_real_via_host "${host}"; then
          ssha::log_ok "OK: connexion SSH acceptée par le serveur"
          
      ssha::print_auth_success_banner
        else
          ssha::log_warn "NOK: connexion refusée."
          ssha::log_warn "Causes fréquentes: clé pas encore ajoutée côté PlanetHoster, mauvais user/port, accès SSH non activé." 
        fi
        ;;
      2)
        ssha::log_ok "Test réel (publickey forcé) pour: ${user}@${hostname}:${port}"
        if ssha::ssh_test_real_publickey_direct "${user}" "${hostname}" "${port}" "${identity}"; then
          if declare -F ssha::colors_enabled >/dev/null 2>&1 && ssha::colors_enabled; then
          if [[ "${_ssha__printed_success}" -eq 0 ]]; then
          _ssha__printed_success=1
          ssha::print_auth_success_banner
        fi
          else
            printf 'PUBLICKEY ACCEPTÉE PAR LE SERVEUR - AUTHENTIFICATION SSH RÉUSSIE
' >&2
          fi

        else
          ssha::log_warn "NOK: authentification refusée."
          ssha::log_warn "Si tu viens de générer la clé, colle-la dans l'interface PlanetHoster (clé autorisée) puis reteste." 
        fi
        ;;
      3)
        if [[ -n "${pubpath}" && -f "${pubpath}" ]]; then
          ssha::print_public_key "${pubpath}"
        else
          ssha::log_warn "Chemin de clé publique non fourni (ou fichier introuvable)."
        fi
        ;;
      0) break ;;
      *) ssha::blink_error_red ;;
    esac
  done
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




# --- ssha::main
# Boucle principale: bannière, menu, dispatch des options.

ssha::main() {
  ssha::detect_platform

  # Allow tests to override ssh dir
  SSHA_SSH_DIR="${SSHA_SSH_DIR:-$HOME/.ssh}"
  export SSHA_SSH_DIR

  while true; do
    ssha::banner
    ssha::menu
    local choice
    choice="$(ssha::prompt_required_choice "Choix")"
    case "${choice}" in
      1) ssha::option_create_key_and_config ;;
      2) ssha::option_ssh_test_menu ;;
      4) ssha::providers_menu ;;
      5) ssha::providers_status_menu ;;
      6) ssha::proc_show_shells ;;
      7) ssha::ssh_dir_show ;;
      8) ssha::ssh_dir_wipe ;;
      9) ssha::ssh_dir_backup_manual ;;
      10) ssha::dry_run_toggle ;;
      11) ssha::history_show ;;
      0) exit 0 ;;
      *) ssha::log_warn "Choix invalide." ;;
    esac
    echo
    read -r -p "Appuie sur Entrée pour revenir au menu..." _
  done
}


# --- ssha::term_supports_blink
# 

ssha::term_supports_blink() {
  # Beaucoup de terminaux mentent; on considère blink "non fiable"
  # On retourne toujours 1 (désactivé) => on utilise le fallback inverse.
  return 1
}

ssha::ssh_config_list_hosts() {
  local cfg
  cfg="$(ssha::config_path)"
  [[ -f "${cfg}" ]] || return 0

  # Récupère les noms après "Host", ignore les patterns (* ?)
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
}





ssha::option_ssh_test_menu() {
  ssha::screen_title "Test de connexion SSH (hosts du config)"

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
  printf "%d) %s\n" "$(( ${#hosts[@]} + 1 ))" "Tester TOUS (SAFE)" >&2
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

  if (( choice == ${#hosts[@]} + 1 )); then
    local rc=0
    for h in "${hosts[@]}"; do
      ssha::log_ok "SAFE: ${h}"
      if ssha::ssh_test_safe_config "${h}"; then
        ssha::log_ok "  OK"
      else
        ssha::log_err "  NOK"
        rc=1
      fi
    done
    return "${rc}"
  fi

  ssha::log_warn "Choix invalide."
  return 1
}

