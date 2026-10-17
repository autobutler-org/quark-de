#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

browser_env_has_no_ipc() {
	pid="$(swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "firefox") | .pid')"
	[ -n "$pid" ] || fail "no firefox window to inspect"
	tr '\0' '\n' <"/proc/$pid/environ" >"$tmp/browser.env"
	grep -q '^WAYLAND_DISPLAY=' "$tmp/browser.env" || fail "could not read the browser environment"
	if grep -E '^(SWAYSOCK|I3SOCK)=' "$tmp/browser.env"; then
		fail "the browser $1 inherited the sway IPC socket"
	fi
}

browser_env_has_no_ipc "started at login"

app_kill firefox
wait_for 10 app_views_is firefox 0 || fail "firefox did not exit"
binding_run 2
wait_for 10 app_views_is firefox 1 || fail "Super+2 did not relaunch firefox"
browser_env_has_no_ipc "relaunched by Super+2"
echo "ok  browser has no sway IPC socket"
