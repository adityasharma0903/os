#!/bin/bash
set -e

# Get script and root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== NovaOS v2 ISO Build Script ==="
echo "Root directory: $ROOT_DIR"

# Determine if we need sudo
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
        echo "Running privileged commands with sudo..."
    else
        echo "Warning: Build script should be run as root, but sudo was not found. Attempting to run directly."
    fi
fi

# Clean old builds and releases using sudo (since previous runs create root-owned files)
echo "Cleaning old builds and releases..."
$SUDO rm -rf "$ROOT_DIR/build"
$SUDO rm -rf "$ROOT_DIR/releases"

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

# Copy abuild keys if they are relative paths to ensure mkimage.sh can find them
echo "Checking for relative abuild keys..."
CONF_PRIVKEY=""
CONF_PUBKEY=""
if [ -f /etc/abuild.conf ]; then
    eval "$(grep -E "^PACKAGER_(PRIVKEY|PUBKEY)=" /etc/abuild.conf)" || true
    [ -n "$PACKAGER_PRIVKEY" ] && CONF_PRIVKEY="$PACKAGER_PRIVKEY"
    [ -n "$PACKAGER_PUBKEY" ] && CONF_PUBKEY="$PACKAGER_PUBKEY"
fi
if [ -f "$HOME/.abuild/abuild.conf" ]; then
    eval "$(grep -E "^PACKAGER_(PRIVKEY|PUBKEY)=" "$HOME/.abuild/abuild.conf")" || true
    [ -n "$PACKAGER_PRIVKEY" ] && CONF_PRIVKEY="$PACKAGER_PRIVKEY"
    [ -n "$PACKAGER_PUBKEY" ] && CONF_PUBKEY="$PACKAGER_PUBKEY"
fi

if [ -n "$CONF_PUBKEY" ] && [[ "$CONF_PUBKEY" != /* ]]; then
    for dir in "$HOME/.abuild" "$HOME" "$ROOT_DIR"; do
        if [ -f "$dir/$CONF_PUBKEY" ]; then
            echo "Copying key $CONF_PUBKEY from $dir to scripts dir..."
            cp "$dir/$CONF_PUBKEY" "$ROOT_DIR/build/aports/scripts/"
            break
        fi
    done
fi

if [ -n "$CONF_PRIVKEY" ] && [[ "$CONF_PRIVKEY" != /* ]]; then
    for dir in "$HOME/.abuild" "$HOME" "$ROOT_DIR"; do
        if [ -f "$dir/$CONF_PRIVKEY" ]; then
            echo "Copying key $CONF_PRIVKEY from $dir to scripts dir..."
            cp "$dir/$CONF_PRIVKEY" "$ROOT_DIR/build/aports/scripts/"
            break
        fi
    done
fi

# Build the ISO
echo "Starting Alpine mkimage build..."
cd "$ROOT_DIR/build/aports/scripts"

# Run mkimage
$SUDO ./mkimage.sh \
    --profile novaos \
    --arch x86_64 \
    --outdir "$ROOT_DIR/releases" \
    --workdir "$ROOT_DIR/build/work" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v3.24/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/v3.24/community"

echo "Build finished! Check releases/ directory for the output ISO."
