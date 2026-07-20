profile_novaos() {
	profile_standard
	profile_abbrev="novaos"
	title="NovaOS"
	desc="NovaOS Desktop"
	arch="x86_64"
	apkovl="genapkovl-novaos.sh"
	kernel_cmdline="quiet splash tmpfs_size=2G"
	
	apks="$apks \
		dbus \
		dbus-openrc \
		lightdm \
		lightdm-openrc \
		lightdm-gtk-greeter \
		lxqt-desktop \
		openbox \
		pcmanfm-qt \
		qterminal \
		firefox \
		xorg-server \
		xf86-video-vmware \
		xf86-input-libinput \
		font-dejavu \
		mesa-dri-gallium \
		udev \
		ca-certificates"
}
