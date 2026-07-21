#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname" >&2
	exit 1
fi

CLEANUP=
tmp="$(mktemp -d -t alpine-apkovl-XXXXXX)"
CLEANUP="rm -rf $tmp"
trap "$CLEANUP" EXIT INT TERM

# Set up basic directory structure
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# Create standard runlevels
mkdir -p "$tmp"/etc/runlevels/sysinit
mkdir -p "$tmp"/etc/runlevels/boot
mkdir -p "$tmp"/etc/runlevels/default
mkdir -p "$tmp"/etc/runlevels/shutdown

# Associate default services
# Boot runlevel services:
for service in devfs dmesg hwdrivers mdev sysfs; do
	ln -sf /etc/init.d/$service "$tmp"/etc/runlevels/sysinit/$service
done

for service in bootmisc hostname hwclock keymaps modules networking rsyslog urandom; do
	ln -sf /etc/init.d/$service "$tmp"/etc/runlevels/boot/$service
done

for service in savecache; do
	ln -sf /etc/init.d/$service "$tmp"/etc/runlevels/shutdown/$service
done

# Graphical desktop / VMware services:
# dbus is required for LXQt and LightDM
ln -sf /etc/init.d/dbus "$tmp"/etc/runlevels/default/dbus
# lightdm display manager
ln -sf /etc/init.d/lightdm "$tmp"/etc/runlevels/default/lightdm
# local startup scripts
ln -sf /etc/init.d/local "$tmp"/etc/runlevels/default/local

# If udev is available, let's configure it in boot runlevel
ln -sf /etc/init.d/udev "$tmp"/etc/runlevels/boot/udev
ln -sf /etc/init.d/udev-trigger "$tmp"/etc/runlevels/boot/udev-trigger

# Copy files from our custom overlay directory if specified
if [ -n "$NOVAOS_OVERLAY" ] && [ -d "$NOVAOS_OVERLAY" ]; then
	echo "Installing custom files from overlay: $NOVAOS_OVERLAY" >&2
	cp -a "$NOVAOS_OVERLAY"/* "$tmp"/
	chmod +x "$tmp"/etc/local.d/*.start 2>/dev/null || true
fi

# Pack the apkovl archive
cd "$tmp"
tar -c -z -f "$OLDPWD/$HOSTNAME.apkovl.tar.gz" .
