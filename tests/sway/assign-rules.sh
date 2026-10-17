#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

readonly quark=org.autobutler.quark

views() {
	swaymsg_ -t get_tree | jq -r '
		[.. | objects | select(.type? == "workspace") | .name as $ws
		| .. | objects | select(.app_id? != null)
		| {id, app_id, $ws, fullscreen_mode}]
		| sort_by(.id)[] | "\(.app_id) \(.ws) \(.fullscreen_mode)"'
}

check_views() {
	views >"$tmp/views"
	for app in "$quark" firefox foot; do
		[ "$(grep -c "^$app " "$tmp/views")" -eq "$1" ] ||
			fail "expected $1 $app view(s); got: $(cat "$tmp/views")"
	done
	while read -r app ws _; do
		case "$app" in
		"$quark") want=1:quark ;;
		firefox) want=2:browser ;;
		foot) want=3:terminal ;;
		*) fail "unexpected app_id $app on workspace $ws" ;;
		esac
		[ "$ws" = "$want" ] || fail "$app opened on workspace $ws, expected $want"
	done <"$tmp/views"
	[ "$(grep "^$quark " "$tmp/views" | tail -n 1 | cut -d ' ' -f 3)" = 1 ] ||
		fail "the newest $quark view is not fullscreen; views: $(cat "$tmp/views")"
	[ "$(grep -c "^$quark .* 1$" "$tmp/views")" -eq 1 ] ||
		fail "expected exactly one fullscreen $quark view; views: $(cat "$tmp/views")"
}

start_elsewhere() {
	swaymsg_ workspace "$1" >/dev/null
	swaymsg_ exec "foot --app-id=$2" >/dev/null
}

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
check_views 1

start_elsewhere 3:terminal "$quark"
start_elsewhere 1:quark firefox
start_elsewhere 2:browser foot
wait_for 10 views_up 6 || fail "the hand-started clients did not map; views: $(views)"
check_views 2

start_elsewhere 1:quark firefox-esr
wait_for 10 app_views_is firefox-esr 1 || fail "the hand-started firefox-esr did not map; views: $(views)"
app_on_workspace firefox-esr 2:browser || fail "firefox-esr opened off 2:browser; views: $(views)"
echo "ok  assign rules"
