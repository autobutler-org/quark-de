#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

readonly summary="quark-de test notification"

listed() {
	[ "$(sway_env makoctl list | grep -c "$summary")" -eq "$1" ]
}

dnd_on() {
	sway_env makoctl mode | grep -qx do-not-disturb
}

harness_setup
dbus_start
sway_start

wait_for 10 pgrep -f "mako --config $tmp/usr/share/quark-de/mako/config" >/dev/null ||
	fail "the session did not start mako with the installed config; sway log: $(cat "$tmp/sway.log")"
wait_for 10 sway_env makoctl list >/dev/null 2>&1 ||
	fail "mako is not answering on the session bus; sway log: $(cat "$tmp/sway.log")"

sway_env notify-send "$summary"
wait_for 5 listed 1 || fail "notify-send did not produce a notification in 'makoctl list'"

sway_env makoctl dismiss
wait_for 5 listed 0 || fail "makoctl dismiss did not dismiss the notification"

sway_env makoctl restore
wait_for 5 listed 1 || fail "makoctl restore did not bring the notification back from history"

sway_env quark-de-dnd
dnd_on || fail "quark-de-dnd did not turn on do-not-disturb"
sway_env quark-de-dnd
! dnd_on || fail "quark-de-dnd did not turn off do-not-disturb"
echo "ok  notifications"
