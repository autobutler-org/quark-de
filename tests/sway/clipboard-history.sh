#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start

wayland_display() {
	for sock in "$runtime"/wayland-*; do
		case "$sock" in
		*.lock) ;;
		*) [ -S "$sock" ] && basename "$sock" && return 0 ;;
		esac
	done
	return 1
}

display="$(wayland_display)" || fail "sway did not create a Wayland socket in $runtime"

session_run() {
	sway_env env WAYLAND_DISPLAY="$display" "$@"
}

history_has() {
	session_run cliphist list 2>/dev/null | grep -qF "$1"
}

session_run wl-copy 'copied in the session' </dev/null >/dev/null 2>&1
wait_for 10 history_has 'copied in the session' ||
	fail "text copied with wl-copy did not reach 'cliphist list'; is 'exec wl-paste --watch quark-de-clipboard store' in the sway config?"

session_run wl-copy --type x-kde-passwordManagerHint 'password manager secret' </dev/null >/dev/null 2>&1
session_run wl-copy 'copied after the secret' </dev/null >/dev/null 2>&1
wait_for 10 history_has 'copied after the secret' || fail "the second copy did not reach 'cliphist list'"
if history_has 'password manager secret'; then
	fail "a copy marked x-kde-passwordManagerHint was stored in the clipboard history"
fi
echo "ok  clipboard history"
