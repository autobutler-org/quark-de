#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/sway/config"
readonly config

value="$(awk '$1 == "focus_on_window_activation" { v = $2 } END { print v }' "$config")"

case "$value" in
focus) ;;
"")
	echo "FAIL: $config has no focus_on_window_activation; add 'focus_on_window_activation focus' so opening a link from Quark switches to the browser" >&2
	exit 1
	;;
*)
	echo "FAIL: $config sets focus_on_window_activation $value; set it to focus so opening a link from Quark switches to the browser" >&2
	exit 1
	;;
esac
echo "ok  focus on window activation"
