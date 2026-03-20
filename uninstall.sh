#!/usr/bin/env bash

set -e

echo "🧹 Uninstalling SSH Assistant..."

# Détection OS (même logique que install.sh)
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
  BIN_PATH="/usr/local/bin/ssha"
  LIB_PATH="/usr/local/lib/ssha"
  NEED_SUDO=true
else
  BIN_PATH="$HOME/.local/bin/ssha"
  LIB_PATH="$HOME/.local/lib/ssha"
  NEED_SUDO=false
fi

# Vérification sudo si nécessaire
if [[ "$NEED_SUDO" == true && "$EUID" -ne 0 ]]; then
  echo "⚠️  Please run with sudo"
  exit 1
fi

# Suppression binaire
if [[ -f "$BIN_PATH" ]]; then
  rm -f "$BIN_PATH"
  echo "✅ Removed $BIN_PATH"
else
  echo "ℹ️  Binary not found ($BIN_PATH)"
fi

# Suppression lib
if [[ -d "$LIB_PATH" ]]; then
  rm -rf "$LIB_PATH"
  echo "✅ Removed $LIB_PATH"
else
  echo "ℹ️  Lib directory not found ($LIB_PATH)"
fi

echo "👋 SSH Assistant uninstalled"