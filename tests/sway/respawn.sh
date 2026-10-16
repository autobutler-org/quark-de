#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

readonly kills=3
readonly respawn_timeout=5
readonly kill_spacing=16
readonly reload_settle=3

quark_views() {
	swaymsg_ -t get_tree | jq -c '.. | objects | select(.type? == "workspace") | .name as $ws
		| .. | objects | select(.app_id? == "org.autobutler.quark")
		| {pid, ws: $ws, fs: .fullscreen_mode}'
}

quark_count() {
	quark_views | grep -c . || :
}

respawned() {
	views="$(quark_views)"
	[ "$(printf '%s\n' "$views" | grep -c .)" -eq 1 ] || return 1
	[ "$(printf '%s' "$views" | jq '.pid')" != "$1" ] || return 1
	[ "$(printf '%s' "$views" | jq -r '.ws')" = "1:quark" ] || return 1
	[ "$(printf '%s' "$views" | jq '.fs')" -eq 1 ]
}

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
wait_for "$respawn_timeout" respawned 0 || fail "Quark did not start on 1:quark fullscreen: $(quark_views)"

i=1
while [ "$i" -le "$kills" ]; do
	[ "$i" -gt 1 ] && sleep "$kill_spacing"
	pid="$(quark_views | jq '.pid')"
	kill -9 "$pid"
	wait_for "$respawn_timeout" respawned "$pid" ||
		fail "kill $i of $kills: no new Quark view on 1:quark fullscreen within ${respawn_timeout}s (killed pid $pid): $(quark_views)"
	i=$((i + 1))
done

swaymsg_ reload >/dev/null || fail "swaymsg reload failed"
sleep "$reload_settle"
count="$(quark_count)"
[ "$count" -eq 1 ] || fail "expected exactly one Quark view after swaymsg reload, found $count: $(quark_views)"

echo "ok  respawn"
