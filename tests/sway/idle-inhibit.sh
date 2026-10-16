#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

user_inhibitor() {
	swaymsg_ -t get_tree | jq -r --arg id "$1" '.. | objects | select(.app_id? == $id) | .idle_inhibitors.user'
}

[ "$(user_inhibitor org.autobutler.quark)" = none ] ||
	fail "Quark inhibits idle; it is always fullscreen, so the screen would never lock"
[ "$(user_inhibitor firefox)" = fullscreen ] ||
	fail "a fullscreen browser does not inhibit idle; video would be interrupted by the lock"
echo "ok  idle inhibit"
