#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/sway/config"
readonly config

if ! grep -qx 'exec wl-paste --watch quark-de-clipboard store' "$config"; then
	echo "FAIL: $config does not start the clipboard history; add 'exec wl-paste --watch quark-de-clipboard store'" >&2
	exit 1
fi
# shellcheck disable=SC2016
if ! grep -qx 'bindsym $mod+v exec quark-de-clipboard pick' "$config"; then
	echo "FAIL: $config has no clipboard picker binding; add 'bindsym \$mod+v exec quark-de-clipboard pick'" >&2
	exit 1
fi
echo "ok  clipboard bindings"
