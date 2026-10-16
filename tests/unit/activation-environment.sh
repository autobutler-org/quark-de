#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/sway/config"
readonly config

line="$(sed -n 's/^exec dbus-update-activation-environment //p' "$config")"
case "$line" in
"") fail_msg="has no 'exec dbus-update-activation-environment --systemd ...' line" ;;
*--systemd*WAYLAND_DISPLAY*XDG_CURRENT_DESKTOP*SWAYSOCK*) fail_msg= ;;
*) fail_msg="must pass --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK to dbus-update-activation-environment" ;;
esac
if [ -n "$fail_msg" ]; then
	echo "FAIL: $config $fail_msg so portals start without the distro snippet" >&2
	exit 1
fi
echo "ok  activation environment"
