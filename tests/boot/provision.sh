#!/bin/sh
# Usage (as root, inside the Debian guest): provision.sh <quark-de checkout> <quark AppImage>
# Turn a Debian cloud image into a Quark desktop: install sway and friends, `make install` quark-de,
# install the real Quark app as `quark`, and autologin the test user through greetd.
set -eu

readonly src="${1:?usage: provision.sh <quark-de checkout> <quark AppImage>}"
readonly appimage="${2:?usage: provision.sh <quark-de checkout> <quark AppImage>}"
readonly user=quark

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
# quark-de's Depends and Recommends from packaging/deb/debian/control, as `apt install quark-de` would pull them.
apt-get install -y -q --no-install-recommends \
	sway foot firefox-esr swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
	mako-notifier libnotify-bin wl-clipboard cliphist wofi grim slurp wireplumber brightnessctl playerctl dex lxpolkit socat
# What any desktop install has and the Quark AppImage expects from the host: GL, xcb-shape, the MIME database.
apt-get install -y -q --no-install-recommends libgl1 libgl1-mesa-dri libegl-mesa0 libxcb-shape0 shared-mime-info fonts-dejavu-core
# The greeter, the user session bus, and what this test needs.
apt-get install -y -q --no-install-recommends greetd dbus-user-session jq make

make -C "$src" install PREFIX=/usr/local

# The AppImage runtime needs FUSE to mount itself; extracting it once avoids that.
rm -rf /opt/quark /opt/squashfs-root
chmod +x "$appimage"
(cd /opt && "$appimage" --appimage-extract >/dev/null)
mv /opt/squashfs-root /opt/quark
printf '#!/bin/sh\nexec /opt/quark/AppRun "$@"\n' >/usr/local/bin/quark
chmod 755 /usr/local/bin/quark

id "$user" >/dev/null 2>&1 || useradd -m -s /bin/sh -G video,render,input "$user"

# VT 7: Debian's greetd.service conflicts with getty@tty7, not tty1, so VT 1 never comes free.
# initial_session logs the test user straight in once per boot; default_session is the greeter after logout.
# greetd drops the session's output, so systemd-cat sends sway's log to the journal the test reads.
cat >/etc/greetd/config.toml <<TOML
[terminal]
vt = 7

[default_session]
command = "agreety --cmd quark-de"
user = "_greetd"

[initial_session]
command = "systemd-cat --identifier=quark-de quark-de"
user = "$user"
TOML
systemctl enable greetd.service
systemctl set-default graphical.target
