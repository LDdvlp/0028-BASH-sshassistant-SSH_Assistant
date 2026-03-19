#!/usr/bin/env bash

set -e

BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib/ssha"

echo "🔧 Installing SSH Assistant..."

if [[ "$EUID" -ne 0 ]]; then
  echo "⚠️  Please run as root (sudo ./install.sh)"
  exit 1
fi

# Clean previous install
rm -rf "$LIB_DIR"

# Install files
mkdir -p "$LIB_DIR"
cp -r lib "$LIB_DIR/"
cp bin/ssha "$LIB_DIR/"

# Create wrapper
cat > "$BIN_DIR/ssha" << 'EOF'
#!/usr/bin/env bash

ROOT_DIR="/usr/local/lib/ssha"

# shellcheck disable=SC1091
source "$ROOT_DIR/lib/ssha_colors.sh"

# shellcheck disable=SC1091
source "$ROOT_DIR/lib/ssha_core.sh"

ssha::main "$@"
EOF

chmod +x "$BIN_DIR/ssha"

echo "✅ Installed to $BIN_DIR/ssha"
echo "📁 Files in $LIB_DIR"
echo "🚀 You can now run: ssha"