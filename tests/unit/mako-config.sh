#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/mako/config"
readonly config
sway_config="$(dirname "$0")/../../config/sway/config"
readonly sway_config

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

grep -qx 'layer=overlay' "$config" ||
	fail "$config must set layer=overlay, or toasts hide behind fullscreen Quark"

awk '/^\[/ { section = $0 } section == "[mode=do-not-disturb]" && $0 == "invisible=1" { found = 1 } END { exit !found }' "$config" ||
	fail "$config needs a [mode=do-not-disturb] section with invisible=1 so do-not-disturb hides toasts"

for bind in 'makoctl dismiss' 'makoctl restore' 'quark-de-dnd'; do
	grep -q "^bindsym .* exec $bind\$" "$sway_config" ||
		fail "$sway_config has no keybind for '$bind'; add a bindsym for it"
done
echo "ok  mako config"
