#!/usr/bin/env bash

set -e

export SSHA_VERSION="1.0.1"

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
# Install
mkdir -p "$INSTALL_LIB"

cp -r lib "$INSTALL_LIB/"
cp -r assets "$INSTALL_LIB/"
cp bin/ssha "$INSTALL_LIB/"
if [[ -f "VERSION" ]]; then
  cp VERSION "$INSTALL_LIB/"
fi

# Wrapper - Heredoc
WRAPPER="$INSTALL_BIN/ssha"
mkdir -p "$INSTALL_BIN"

cat > "$WRAPPER" << EOF
#!/usr/bin/env bash

ROOT_DIR="$INSTALL_LIB"

VERSION_FILE="\$ROOT_DIR/VERSION"

if [[ -f "\$VERSION_FILE" ]]; then
  SSHA_VERSION="\$(cat "\$VERSION_FILE")"
else
  SSHA_VERSION="dev"
fi

# --- CLI arguments ---
case "\${1:-}" in
  "")
    ;;
  --version|-v)
    echo "SSH Assistant v\${SSHA_VERSION}"
    exit 0
    ;;
  doctor)
    source "\$ROOT_DIR/lib/ssha_colors.sh"
    source "\$ROOT_DIR/lib/ssha_core.sh"
    ssha::doctor
    exit 0
    ;;
  help|-h|--help)
    source "\$ROOT_DIR/lib/ssha_colors.sh"
    source "\$ROOT_DIR/lib/ssha_core.sh"
    ssha::help
    exit 0
    ;;
  list)
    source "\$ROOT_DIR/lib/ssha_colors.sh"
    source "\$ROOT_DIR/lib/ssha_core.sh"
    ssha::list_hosts
    exit 0
    ;;
  test)
    source "\$ROOT_DIR/lib/ssha_colors.sh"
    source "\$ROOT_DIR/lib/ssha_core.sh"
  
    if [[ "\${2:-}" == "--full" ]]; then
      ssha::test_host_full "\${3:-}"
    else
      ssha::test_host "\${2:-}"
    fi
  
    exit 0
    ;;
esac

# --- Load ---
source "\$ROOT_DIR/lib/ssha_colors.sh"
source "\$ROOT_DIR/lib/ssha_core.sh"

# --- Run ---
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