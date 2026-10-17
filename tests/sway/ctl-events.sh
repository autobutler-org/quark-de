#!/bin/sh
# quark-de-ctl's events: Quark may subscribe to workspace and window events on its socket, and nothing else.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

quark_pid="$(swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "org.autobutler.quark") | .pid')"
quark_sock="$(tr '\0' '\n' <"/proc/$quark_pid/environ" | sed -n 's/^SWAYSOCK=//p')"
readonly quark_sock
[ -S "$quark_sock" ] && [ "$quark_sock" != "$SWAYSOCK" ] || fail "quark is not handed its own IPC socket (SWAYSOCK='$quark_sock')"

event_seen() {
	grep -q "$1" "$tmp/events"
}

swaymsg -s "$quark_sock" -m -t subscribe '["workspace","window"]' >"$tmp/events" 2>&1 &
sub=$!
sleep 1
swaymsg_ workspace 3:terminal >/dev/null
wait_for 5 event_seen '"change": "focus"' || fail "no workspace event reached quark's subscription: $(cat "$tmp/events")"
app_kill foot
wait_for 5 event_seen '"change": "close"' || fail "no window close event reached quark's subscription: $(cat "$tmp/events")"
kill "$sub" 2>/dev/null || :

for events in '["binding"]' '["shutdown"]' '["workspace","input"]' '{}' '[]'; do
	if swaymsg -s "$quark_sock" -t subscribe "$events" >"$tmp/reply" 2>&1; then
		fail "quark's socket accepted a subscription to $events: $(cat "$tmp/reply")"
	fi
done
echo "ok  quark-de-ctl passes workspace and window events to quark and nothing else"
