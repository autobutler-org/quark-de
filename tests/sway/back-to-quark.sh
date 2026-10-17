#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

# Only ever talk to the test sway, never the desktop the test runs from.
guard_session() {
	kill -0 "$sway_pid" 2>/dev/null || fail "the test sway ($sway_pid) is gone; not sending commands"
	case "$SWAYSOCK" in
	"$runtime"/sway-ipc.*.sock) [ -S "$SWAYSOCK" ] || fail "$SWAYSOCK is not a socket; not sending commands" ;;
	*) fail "SWAYSOCK '$SWAYSOCK' is not the test sway's socket in $runtime; not sending commands" ;;
	esac
}

press() {
	guard_session
	binding_run "$1"
}

# Runs the command bound to the touchpad gesture, as sway would on a 3-finger swipe down.
swipe() {
	guard_session
	command="$(sed -n 's/^bindgesture swipe:3:down //p' "$config")"
	[ -n "$command" ] || fail "no 'bindgesture swipe:3:down' in the installed config; touchpad users have no way back to Quark"
	swaymsg_ "$command" >/dev/null
}

workspace_is() {
	[ "$(focused_workspace)" = "$1" ]
}

for case in 2:2:browser 3:3:terminal; do
	key="${case%%:*}" ws="${case#*:}"
	press "$key"
	wait_for 5 workspace_is "$ws" || fail "Super+$key focused $(focused_workspace), not $ws"
	press Tab
	wait_for 5 workspace_is 1:quark || fail "Super+Tab from $ws focused $(focused_workspace), not 1:quark"
	press Tab
	wait_for 5 workspace_is "$ws" || fail "a second Super+Tab focused $(focused_workspace), not $ws; it should toggle back"

	swipe
	wait_for 5 workspace_is 1:quark || fail "the 3-finger swipe down from $ws focused $(focused_workspace), not 1:quark"
	press Tab
	wait_for 5 workspace_is "$ws" || fail "Super+Tab after the swipe focused $(focused_workspace), not $ws"
	press 1
	wait_for 5 workspace_is 1:quark || fail "Super+1 from $ws focused $(focused_workspace), not 1:quark"
done
echo "ok  back to quark"
