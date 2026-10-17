#!/bin/sh
# idle-timeouts.sh checks the swayidle arguments; this runs the real swayidle and swaylock and checks the
# session actually locks on idle, before sleep and on a logind Lock, and that a second trigger starts no
# second locker. logind is faked on a private bus that is both the system and the session bus.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

for cmd in swayidle swaylock dbus-send; do
	command -v "$cmd" >/dev/null || fail "$cmd not found: sudo apt install swayidle swaylock dbus"
done
real_swaylock="$(readlink -f "$(command -v swaylock)")"
readonly real_swaylock

harness_setup
# A swaylock that holds its lock exits 0 once locked (-f); one that was refused the lock exits non-zero.
stub swaylock "\"$real_swaylock\" \"\$@\"; echo \$? >>\"$tmp/swaylock.status\""
mkdir -p "$tmp/config/quark-de/sway"

session_start() {
	printf "set \$lock_timeout %s\n" "$1" >"$tmp/config/quark-de/sway/idle"
	: >"$tmp/swaylock.status"
	dbus_start
	DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
	export DBUS_SYSTEM_BUS_ADDRESS
	sway_start
	wait_for 10 swayidle_bus_name || fail "swayidle did not connect to the test bus; log: $(cat "$tmp/sway.log")"
}

session_stop() {
	pkill -TERM -P "$sway_pid" 2>/dev/null || :
	kill "$sway_pid" 2>/dev/null || :
	wait "$sway_pid" 2>/dev/null || :
	sway_pid=
	kill "$dbus_pid" 2>/dev/null || :
	dbus_pid=
	session_pids | xargs -r kill -9 2>/dev/null || :
	wait_for 5 no_session_pids || fail "the previous test session did not exit"
	rm -f "$runtime"/sway-ipc.*.sock "$runtime"/wayland-* "$runtime/bus"
}

bus_() {
	dbus-send --bus="$DBUS_SESSION_BUS_ADDRESS" "$@"
}

swayidle_pid() {
	for pid in $(session_pids); do
		[ "$(readlink "/proc/$pid/exe" 2>/dev/null)" = "$(readlink -f "$(command -v swayidle)")" ] && echo "$pid" && return 0
	done
	return 1
}

swayidle_bus_name() {
	pid="$(swayidle_pid)" || return 1
	for name in $(bus_ --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames | grep -o '":[0-9.]*"' | tr -d '"'); do
		owner="$(bus_ --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID "string:$name" 2>/dev/null | awk '/uint32/ { print $2 }')"
		[ "$owner" = "$pid" ] && swayidle_name="$name" && return 0
	done
	return 1
}

# A directed signal reaches swayidle's logind match without a fake logind owning org.freedesktop.login1.
logind_signal() {
	bus_ --type=signal --dest="$swayidle_name" "$1" "$2" ${3:+"$3"}
}

# swaylock forks a PAM helper before -f daemonizes it; the daemon is the one that leads its own session.
lockers() {
	count=0
	for pid in $(session_pids); do
		[ "$(readlink "/proc/$pid/exe" 2>/dev/null)" = "$real_swaylock" ] || continue
		[ "$(ps -o sid= -p "$pid" | tr -d ' ')" = "$pid" ] && count=$((count + 1))
	done
	echo "$count"
}

locked() {
	grep -qx 0 "$tmp/swaylock.status" && [ "$(lockers)" -eq 1 ]
}

swaylock_runs_are() {
	[ "$(wc -l <"$tmp/swaylock.status")" -ge "$1" ]
}

# Idle: with a 3 s timeout and no input, the session locks within 5 s.
session_start 3
sleep 3
wait_for 2 locked || fail "the session did not lock within 5 s of idle (lockers: $(lockers)); log: $(cat "$tmp/sway.log")"
echo "ok  locks on idle"
session_stop

# Before sleep: logind's PrepareForSleep(true) locks; a second one while locked starts no second locker.
session_start 600
logind_signal /org/freedesktop/login1 org.freedesktop.login1.Manager.PrepareForSleep boolean:true
wait_for 5 locked || fail "the session did not lock before sleep (lockers: $(lockers)); log: $(cat "$tmp/sway.log")"
logind_signal /org/freedesktop/login1 org.freedesktop.login1.Manager.PrepareForSleep boolean:false
logind_signal /org/freedesktop/login1 org.freedesktop.login1.Manager.PrepareForSleep boolean:true
wait_for 5 swaylock_runs_are 2 || fail "the second sleep did not run the locker; log: $(cat "$tmp/sway.log")"
[ "$(lockers)" -eq 1 ] || fail "a second sleep while locked left $(lockers) lockers running, want 1"
echo "ok  locks before sleep, once"
session_stop

# loginctl lock-session: logind's Lock signal on the session locks.
session_start 600
logind_signal /org/freedesktop/login1/session/auto org.freedesktop.login1.Session.Lock
wait_for 5 locked || fail "the session did not lock on loginctl lock-session (lockers: $(lockers)); log: $(cat "$tmp/sway.log")"
echo "ok  locks on lock-session"
