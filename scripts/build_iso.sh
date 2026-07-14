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
        echo "ERROR: This script must be run as root (or with sudo). Please run as root (e.g. run 'su -' first, or install sudo via 'apk add sudo')."
        exit 1
    fi
fi

# Clean old builds and releases using sudo (since previous runs create root-owned files)
echo "Cleaning old builds and releases..."
$SUDO rm -rf "$ROOT_DIR/build"
$SUDO rm -rf "$ROOT_DIR/releases"

# Re-create directories
mkdir -p "$ROOT_DIR/build"
mkdir -p "$ROOT_DIR/releases"

# Set up custom temp directory to avoid running out of space on /tmp (tmpfs RAM disk)
export TMPDIR="$ROOT_DIR/build/tmp"
mkdir -p "$TMPDIR"
echo "TMPDIR set to storage-backed directory: $TMPDIR"

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

# Gather potential config paths (root's home, ~/.abuild, and all user homes in /home)
CONFIG_PATHS=("/etc/abuild.conf" "$HOME/.abuild/abuild.conf" "$HOME/abuild.conf")
for user_home in /home/*; do
    if [ -d "$user_home/.abuild" ]; then
        CONFIG_PATHS+=("$user_home/.abuild/abuild.conf")
    fi
done

# Read the configurations
for conf in "${CONFIG_PATHS[@]}"; do
    if [ -f "$conf" ]; then
        eval "$(grep -E "^PACKAGER_(PRIVKEY|PUBKEY)=" "$conf")" || true
        [ -n "$PACKAGER_PRIVKEY" ] && CONF_PRIVKEY="$PACKAGER_PRIVKEY"
        [ -n "$PACKAGER_PUBKEY" ] && CONF_PUBKEY="$PACKAGER_PUBKEY"
    fi
done

if [ -n "$CONF_PRIVKEY" ] && [ -z "$CONF_PUBKEY" ]; then
    CONF_PUBKEY="${CONF_PRIVKEY}.pub"
fi

# Gather search directories for the actual key files
SEARCH_DIRS=("$HOME/.abuild" "$HOME" "$ROOT_DIR" "/etc/apk/keys")
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        SEARCH_DIRS+=("$user_home/.abuild" "$user_home")
    fi
done

# Copy the keys to target scripts directory if relative paths are used
if [ -n "$CONF_PUBKEY" ] && [[ "$CONF_PUBKEY" != /* ]]; then
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -f "$dir/$CONF_PUBKEY" ]; then
            echo "Copying key $CONF_PUBKEY from $dir to scripts dir..."
            cp "$dir/$CONF_PUBKEY" "$ROOT_DIR/build/aports/scripts/"
            break
        fi
    done
fi

if [ -n "$CONF_PRIVKEY" ] && [[ "$CONF_PRIVKEY" != /* ]]; then
    for dir in "${SEARCH_DIRS[@]}"; do
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
