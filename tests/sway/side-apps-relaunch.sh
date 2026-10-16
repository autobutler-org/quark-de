#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

relaunch_case() {
	key="$1" app_id="$2" workspace="$3"

	app_kill "$app_id"
	wait_for 10 app_views_is "$app_id" 0 || fail "$app_id did not exit"

	binding_run "$key"
	wait_for 10 app_views_is "$app_id" 1 || fail "Super+$key did not relaunch $app_id"
	app_on_workspace "$app_id" "$workspace" || fail "the relaunched $app_id is not on $workspace"
	[ "$(focused_workspace)" = "$workspace" ] || fail "Super+$key did not switch to $workspace"

	binding_run 1
	binding_run "$key"
	sleep 2
	app_views_is "$app_id" 1 || fail "Super+$key started a second $app_id while one was running"
	[ "$(focused_workspace)" = "$workspace" ] || fail "Super+$key did not switch to $workspace with $app_id running"
}

relaunch_case 2 firefox 2:browser
relaunch_case 3 foot 3:terminal
echo "ok  side apps relaunch"
