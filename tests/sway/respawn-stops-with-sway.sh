#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub quark "echo run >>'$tmp/quark.runs'; exec foot --app-id=org.autobutler.quark"

respawn_running() {
	pgrep -f "$tmp/usr/bin/quark-de-respawn" >/dev/null
}

respawn_gone() {
	! respawn_running
}

sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
respawn_running || fail "quark-de-respawn is not running"
swaymsg_ exit >/dev/null 2>&1 || :
wait "$sway_pid" 2>/dev/null || :
sway_pid=""
wait_for 10 respawn_gone || {
	pkill -f "$tmp/usr/bin/quark-de-respawn" || :
	fail "quark-de-respawn kept running after sway exited; quark ran $(wc -l <"$tmp/quark.runs") times"
}
runs="$(wc -l <"$tmp/quark.runs")"
[ "$runs" -eq 1 ] || fail "quark was restarted after sway exited: $runs runs"
! grep -qF 'Quark keeps crashing.' "$tmp/swaynag.args" 2>/dev/null || fail "the crash bar was shown after sway exited"
echo "ok  respawn stops once sway is gone"
