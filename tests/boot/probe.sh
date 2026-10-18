#!/bin/sh
# Usage (as the session user, inside the guest): probe.sh ready | probe.sh collect <dir>
#   ready    exit 0 once sway is up and a window with Quark's app_id has mapped
#   collect  write tree.json, shot.png and shot.ppm of the running session into <dir>
set -eu

runtime="/run/user/$(id -u)"

socket() {
	for sock in "$runtime"/sway-ipc.*.sock; do
		[ -S "$sock" ] && echo "$sock" && return 0
	done
	return 1
}

display() {
	for sock in "$runtime"/wayland-*; do
		case "$sock" in *.lock) continue ;; esac
		[ -S "$sock" ] && basename "$sock" && return 0
	done
	return 1
}

case "${1:-}" in
ready)
	SWAYSOCK="$(socket)" || exit 1
	export SWAYSOCK
	swaymsg -t get_tree | jq -e '[.. | objects | select(.app_id? == "org.autobutler.quark")] | length > 0' >/dev/null
	;;
collect)
	dir="${2:?usage: probe.sh collect <dir>}"
	mkdir -p "$dir"
	SWAYSOCK="$(socket)" || {
		echo "probe: no sway IPC socket in $runtime; the session is not running" >&2
		exit 1
	}
	export SWAYSOCK XDG_RUNTIME_DIR="$runtime"
	swaymsg -t get_tree >"$dir/tree.json"
	WAYLAND_DISPLAY="$(display)" || {
		echo "probe: no Wayland socket in $runtime" >&2
		exit 1
	}
	export WAYLAND_DISPLAY
	grim "$dir/shot.png"
	grim -t ppm "$dir/shot.ppm"
	;;
*)
	echo "usage: probe.sh ready | probe.sh collect <dir>" >&2
	exit 2
	;;
esac
