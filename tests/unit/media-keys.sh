#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/sway/config"
readonly config

for binding in \
	'XF86AudioRaiseVolume volume-up' \
	'XF86AudioLowerVolume volume-down' \
	'XF86AudioMute mute' \
	'XF86AudioMicMute mic-mute' \
	'XF86MonBrightnessUp brightness-up' \
	'XF86MonBrightnessDown brightness-down' \
	'XF86AudioPlay play-pause' \
	'XF86AudioPause pause' \
	'XF86AudioNext next' \
	'XF86AudioPrev previous'; do
	key="${binding% *}"
	action="${binding#* }"
	if ! grep -qxF "bindsym --locked $key exec quark-de-osd $action" "$config"; then
		echo "FAIL: $config does not bind $key; add 'bindsym --locked $key exec quark-de-osd $action'" >&2
		exit 1
	fi
done
echo "ok  media keys"
