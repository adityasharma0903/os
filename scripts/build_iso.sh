#!/bin/bash
set -e

# Get script and root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== NovaOS v2 ISO Build Script ==="
echo "Root directory: $ROOT_DIR"

# Clean old builds and releases
echo "Cleaning old builds and releases..."
rm -rf "$ROOT_DIR/build"
rm -rf "$ROOT_DIR/releases"

# Re-create directories
mkdir -p "$ROOT_DIR/build"
mkdir -p "$ROOT_DIR/releases"

# Clone clean aports if not already there
echo "Cloning alpine aports repository (branch 3.24-stable)..."
git clone --depth=1 -b 3.24-stable https://gitlab.alpinelinux.org/alpine/aports.git "$ROOT_DIR/build/aports"

# Setup custom configs
echo "Setting up custom profiles..."
cp "$ROOT_DIR/configs/mkimg.novaos.sh" "$ROOT_DIR/build/aports/scripts/"
cp "$ROOT_DIR/configs/genapkovl-novaos.sh" "$ROOT_DIR/build/aports/scripts/"
chmod +x "$ROOT_DIR/build/aports/scripts/genapkovl-novaos.sh"
chmod +x "$ROOT_DIR/build/aports/scripts/mkimg.novaos.sh"

# Patch mkimage.sh to remove --no-chown flag (fixes apk 3.x --usermode compat)
echo "Patching mkimage.sh for apk 3.x --usermode compatibility..."
sed -i 's/--no-chown//g' "$ROOT_DIR/build/aports/scripts/mkimage.sh"

# Export the overlay directory location so our genapkovl script can access it
export NOVAOS_OVERLAY="$ROOT_DIR/overlay"
echo "Overlay path exported: $NOVAOS_OVERLAY"

# Build the ISO
echo "Starting Alpine mkimage build..."
cd "$ROOT_DIR/build/aports/scripts"

# Determine if we need sudo
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
        echo "Running build with sudo..."
    else
        echo "Warning: Build script should be run as root, but sudo was not found. Attempting to run directly."
    fi
fi

# Run mkimage
$SUDO ./mkimage.sh \
    --profile novaos \
    --arch x86_64 \
    --outdir "$ROOT_DIR/releases" \
    --workdir "$ROOT_DIR/build/work" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v3.24/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v3.24/community"

echo "Build finished! Check releases/ directory for the output ISO."
