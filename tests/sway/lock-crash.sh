#!/bin/sh
# A Quark crash while the session is locked must not unlock it or show Quark over the lock: the
# respawned Quark stays hidden under swaylock until the user unlocks, then shows on 1:quark again.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

command -v swaylock >/dev/null || fail "swaylock not found: sudo apt install swaylock"
command -v grim >/dev/null || fail "grim not found: sudo apt install grim"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

display=""
for sock in "$runtime"/wayland-*; do
	[ -S "$sock" ] && display="${sock##*/}" && break
done
[ -n "$display" ] || fail "sway created no wayland socket in $runtime"
readonly display

quark_pid() {
	swaymsg_ -t get_tree | jq -r '[.. | objects | select(.app_id? == "org.autobutler.quark") | .pid] | first // empty'
}

# Only the swaylock inside this test's sway: session_pids matches on its XDG_RUNTIME_DIR. swaylock
# spawns its password-checking child before it forks into the background, so the lock holder is
# the swaylock started last.
swaylock_pid() {
	for pid in $(session_pids); do
		[ "$(cat "/proc/$pid/comm" 2>/dev/null)" = swaylock ] || continue
		# Field 22 of stat is the start time; the comm (field 2) is plain "swaylock", so no spaces.
		echo "$(cut -d' ' -f22 "/proc/$pid/stat" 2>/dev/null) $pid"
	done | sort -n | tail -n 1 | cut -d' ' -f2 | grep .
}

shot() {
	sway_env WAYLAND_DISPLAY="$display" grim "$1"
}

locked_shot_is_reference() {
	shot "$tmp/now.png" && cmp -s "$tmp/now.png" "$tmp/locked.png"
}

respawned() {
	pid="$(quark_pid)"
	[ -n "$pid" ] && [ "$pid" != "$first" ]
}

swaylock_gone() {
	! swaylock_pid >/dev/null
}

shot "$tmp/unlocked.png" || fail "grim could not capture the unlocked session"
binding_run l
wait_for 10 swaylock_pid >/dev/null || fail "\$mod+l did not start swaylock; log: $(cat "$tmp/sway.log")"
# swaylock -f forks once the lock is held; give sway a frame to render the lock surface.
sleep 1
shot "$tmp/locked.png" || fail "grim could not capture the locked session"
cmp -s "$tmp/locked.png" "$tmp/unlocked.png" && fail "the locked screen looks the same as the unlocked desktop"

first="$(quark_pid)"
[ -n "$first" ] || fail "no quark window"
kill -9 "$first"
wait_for 10 respawned || fail "quark was not restarted after it was killed while locked"
for check in respawn 5s; do
	[ "$check" = 5s ] && sleep 5
	swaylock_pid >/dev/null || fail "the lock was released after quark crashed ($check)"
	wait_for 2 locked_shot_is_reference || fail "the screen differs from the lock screen after quark crashed ($check); see $tmp/now.png"
done

kill -USR1 "$(swaylock_pid)"
wait_for 5 swaylock_gone || fail "swaylock did not unlock on SIGUSR1"
wait_for 5 quark_shown_on HEADLESS-1 || fail "quark is not shown fullscreen on 1:quark after unlocking: $(output_layout)"
echo "ok  a quark crash while locked keeps the session locked"
