#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

quark_pid() {
	swaymsg_ -t get_tree | jq -r '[.. | objects | select(.app_id? == "org.autobutler.quark") | .pid] | first // empty'
}

quark_workspace() {
	swaymsg_ -t get_tree | jq -r '.. | objects | select(.type? == "workspace") | select([.. | objects | select(.app_id? == "org.autobutler.quark")] | length > 0) | .name'
}

focused_workspace() {
	swaymsg_ -t get_workspaces | jq -r '.[] | select(.focused) | .name'
}

respawned() {
	pid="$(quark_pid)"
	[ -n "$pid" ] && [ "$pid" != "$first" ]
}

sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
first="$(quark_pid)"
[ -n "$first" ] || fail "no quark window"
swaymsg_ workspace 3:terminal >/dev/null
kill "$first"
wait_for 10 respawned || fail "quark was not restarted after it exited"
[ "$(quark_workspace)" = "1:quark" ] || fail "the restarted quark landed on '$(quark_workspace)', not 1:quark"
[ "$(focused_workspace)" = "1:quark" ] || fail "focus stayed on '$(focused_workspace)' after quark restarted"
grep -q 'quark exited' "$tmp/state/quark-de/quark.log" || fail "the quark exit was not logged"
echo "ok  quark respawns on 1:quark and takes focus"
