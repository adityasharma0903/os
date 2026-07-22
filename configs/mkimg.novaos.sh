profile_novaos() {
	profile_standard
	profile_abbrev="novaos"
	title="NovaOS"
	desc="NovaOS Desktop"
	arch="x86_64"
	apkovl="genapkovl-novaos.sh"
	modloop_sign=no
	kernel_cmdline="quiet splash"
	
	apks="$apks \
		dbus \
		dbus-openrc \
		elogind \
		elogind-openrc \
		polkit \
		polkit-elogind \
		accountsservice \
		lightdm \
		lightdm-openrc \
		lightdm-gtk-greeter \
		lxqt-desktop \
		lxqt-session \
		openbox \
		pcmanfm-qt \
		qterminal \
		firefox \
		xorg-server \
		xinit \
		xauth \
		xrandr \
		setxkbmap \
		mesa \
		mesa-gl \
		mesa-egl \
		mesa-dri-gallium \
		xf86-input-libinput \
		xf86-video-vmware \
		xf86-video-vesa \
		font-dejavu \
		udev \
		ca-certificates"
}
