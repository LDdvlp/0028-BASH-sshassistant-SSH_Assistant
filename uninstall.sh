#!/usr/bin/env bash

set -e

BIN="/usr/local/bin/ssha"
LIB="/usr/local/lib/ssha"

echo "🧹 Uninstalling SSH Assistant..."

if [[ "$EUID" -ne 0 ]]; then
  echo "⚠️  Please run as root (sudo ./uninstall.sh)"
  exit 1
fi

rm -f "$BIN"
rm -rf "$LIB"

echo "✅ SSH Assistant removed"