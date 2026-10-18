#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

respawn="$(dirname "$0")/../../session/quark-de-respawn"
threshold="$(sed -n 's/^readonly threshold=//p' "$respawn")"
window="$(sed -n 's/^readonly window=//p' "$respawn")"
readonly respawn threshold window
readonly settle=3

[ -n "$threshold" ] && [ -n "$window" ] || fail "could not read threshold and window from $respawn"

starts() {
	if [ -e "$tmp/quark.starts" ]; then
		grep -c . "$tmp/quark.starts"
	else
		echo 0
	fi
}

starts_are() {
	[ "$(starts)" -eq "$1" ]
}

nag_shown() {
	grep -qxF 'Quark keeps crashing.' "$tmp/swaynag.args" 2>/dev/null
}

loop_running() {
	kill -0 "$(cat "$tmp/state/quark-de/respawn.pid")" 2>/dev/null
}

# quark_mode <script>: a stand-in quark that logs each start, then runs <script> with $n set to the start number.
quark_mode() {
	stub quark "echo start >>'$tmp/quark.starts'
n=\$(grep -c . '$tmp/quark.starts')
$1"
}

session_end() {
	harness_teardown
	sway_pid=""
	dbus_pid=""
	unset SWAYSOCK
}

harness_setup
quark_mode 'exit 1'
sway_start
wait_for $((threshold * 3 + 5)) nag_shown || fail "quark failed $(starts) times and no nag was shown"
sleep "$settle"
starts_are "$threshold" || fail "an always-failing quark started $(starts) times, expected $threshold"
! loop_running || fail "the respawn loop kept running after the nag was dismissed"
for arg in 'Quark keeps crashing.' 'Open terminal' 'View log' 'Retry' 'Log out'; do
	grep -qxF "$arg" "$tmp/swaynag.args" || fail "the nag lacks '$arg': $(cat "$tmp/swaynag.args")"
done
session_end
echo "ok  an always-failing quark starts $threshold times, then the nag shows and no more starts"

harness_setup
quark_mode "[ \"\$n\" -eq 1 ] && exit 1
exec sleep 600"
sway_start
wait_for 10 starts_are 2 || fail "a quark that crashed once was started $(starts) times, expected 2"
sleep "$settle"
starts_are 2 || fail "a quark that crashed once was started $(starts) times, expected 2"
! nag_shown || fail "a single crash showed the nag: $(cat "$tmp/swaynag.args")"
session_end
echo "ok  a quark that crashes once is restarted once and no nag shows"

# Two quick crashes, then one after the window: only a loop that forgets old exits stays quiet.
harness_setup
quark_mode "[ \"\$n\" -le $((threshold - 1)) ] && exit 1
[ \"\$n\" -eq $threshold ] && sleep $((window + 2)) && exit 1
exec sleep 600"
sway_start
wait_for $((window + threshold * 2 + 10)) starts_are $((threshold + 1)) ||
	fail "a quark that crashed after the window was started $(starts) times, expected $((threshold + 1))"
sleep "$settle"
starts_are $((threshold + 1)) || fail "a quark that crashed after the window was started $(starts) times, expected $((threshold + 1))"
! nag_shown || fail "crashes more than ${window}s apart showed the nag: $(cat "$tmp/swaynag.args")"
echo "ok  a quark that crashes after the ${window}s window is restarted and no nag shows"
