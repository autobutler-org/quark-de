#!/bin/sh
# multi-monitor.sh covers one unplug and one plug. This repeats the cycle from a single output and also checks
# Quark is never restarted, 1:quark never sits on a disconnected output, and the side workspaces survive.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

quark_pid() {
	swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "org.autobutler.quark") | .pid'
}

quark_on_live_output() {
	out="$(swaymsg_ -t get_workspaces | jq -r '.[] | select(.name == "1:quark") | .output')"
	swaymsg_ -t get_outputs | jq -e --arg out "$out" 'any(.[]; .name == $out and .active)' >/dev/null &&
		quark_shown_on "$out"
}

workspaces_exist() {
	swaymsg_ -t get_workspaces | jq -e '[.[].name] | contains(["1:quark", "2:browser", "3:terminal"])' >/dev/null
}

check() {
	wait_for 5 quark_on_live_output ||
		fail "after $1, Quark is not fullscreen and visible on a connected output: $(output_layout)"
	workspaces_exist || fail "after $1, the browser and terminal workspaces are gone: $(output_layout)"
	[ "$(quark_pid)" = "$pid" ] || fail "after $1, Quark was restarted (pid $pid, now $(quark_pid))"
}

harness_setup
mkdir -p "$tmp/config/quark-de/sway"
echo "set \$primary HEADLESS-4 HEADLESS-3 HEADLESS-2" >"$tmp/config/quark-de/sway/outputs"
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
pid="$(quark_pid)"
check "startup on one output"

for n in 2 3 4; do
	swaymsg_ create_output >/dev/null
	wait_for 5 quark_shown_on "HEADLESS-$n" ||
		fail "after plugging in the primary output HEADLESS-$n, Quark did not move to it: $(output_layout)"
	check "plugging in HEADLESS-$n"
	swaymsg_ output "HEADLESS-$n" unplug >/dev/null
	wait_for 5 quark_shown_on HEADLESS-1 ||
		fail "after unplugging HEADLESS-$n, Quark did not return to HEADLESS-1: $(output_layout)"
	check "unplugging HEADLESS-$n"
done
echo "ok  monitor hotplug"
