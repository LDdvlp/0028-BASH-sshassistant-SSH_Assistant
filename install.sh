#!/usr/bin/env bash

set -e

echo "🔧 Installing SSH Assistant..."

# Détection OS
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
  INSTALL_BIN="/usr/local/bin"
  INSTALL_LIB="/usr/local/lib/ssha"
  NEED_SUDO=true
else
  INSTALL_BIN="$HOME/.local/bin"
  INSTALL_LIB="$HOME/.local/lib/ssha"
  NEED_SUDO=false
fi

# sudo si nécessaire
if [[ "$NEED_SUDO" == true && "$EUID" -ne 0 ]]; then
  echo "⚠️  Please run with sudo"
  exit 1
fi

# Clean
rm -rf "$INSTALL_LIB"

# Install
mkdir -p "$INSTALL_LIB"
cp -r lib "$INSTALL_LIB/"
cp bin/ssha "$INSTALL_LIB/"
cp -r assets "$INSTALL_LIB/"

# Wrapper
WRAPPER="$INSTALL_BIN/ssha"

mkdir -p "$INSTALL_BIN"

cat > "$WRAPPER" << EOF
#!/usr/bin/env bash
ROOT_DIR="$INSTALL_LIB"

source "\$ROOT_DIR/lib/ssha_colors.sh"
source "\$ROOT_DIR/lib/ssha_core.sh"

ssha::main "\$@"
EOF

chmod +x "$WRAPPER"

echo "✅ Installed to $WRAPPER"

# PATH hint
if [[ ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
  echo "⚠️  Add this to your PATH:"
  echo "export PATH=\"$INSTALL_BIN:\$PATH\""
fi

echo "🚀 You can now run: ssha"