profile_novaos() {
	profile_standard
	profile_abbrev="novaos"
	title="NovaOS"
	desc="NovaOS Desktop"
	arch="x86_64"
	apkovl="genapkovl-novaos.sh"
	
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
		xf86-video-vmware \
		xf86-input-libinput \
		udev \
		udev-openrc"
}
