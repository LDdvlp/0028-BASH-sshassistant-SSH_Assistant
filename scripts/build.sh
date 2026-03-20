#!/usr/bin/env bash

set -e

VERSION="$1"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/build.sh v1.0.0"
  exit 1
fi

BUILD_DIR="dist/ssha-$VERSION"

echo "🔧 Building release $VERSION..."

rm -rf dist
mkdir -p "$BUILD_DIR"

# Copy required files
cp -r bin "$BUILD_DIR/"
cp -r lib "$BUILD_DIR/"
cp -r assets "$BUILD_DIR/"
cp install.sh uninstall.sh README.md "$BUILD_DIR/"

# Create archive
cd dist
zip -r "ssha-$VERSION.zip" "ssha-$VERSION" >/dev/null

echo "✅ Build created: dist/ssha-$VERSION.zip"