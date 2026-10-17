#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

# login <n>: start a session through the installed launcher, its processes marked with QUARK_DE_TEST_LOGIN=<n>.
login() {
	sway_env QUARK_DE_TEST_LOGIN="$1" sh "$tmp/usr/bin/quark-de" >"$tmp/login$1.log" 2>&1 &
	login_job=$!
	wait_for 10 sway_socket_ready || fail "login $1 did not start sway; log: $(cat "$tmp/login$1.log")"
	# $! is the subshell running sway_env; sway's own pid is in its socket name.
	sway_pid="${SWAYSOCK%.sock}"
	sway_pid="${sway_pid##*.}"
	wait_for 10 views_up 3 || fail "login $1 did not map its three clients"
}

# login_pids <n>: processes still carrying login <n>'s marker.
login_pids() {
	for environ in /proc/[0-9]*/environ; do
		pid="${environ#/proc/}"
		pid="${pid%/environ}"
		{ tr '\0' '\n' <"$environ"; } 2>/dev/null | grep -qx "QUARK_DE_TEST_LOGIN=$1" && echo "$pid"
	done
	return 0
}

no_login_pids() {
	[ -z "$(login_pids "$1")" ]
}

describe_pids() {
	for pid in "$@"; do
		printf '  %s: %s\n' "$pid" "$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)"
	done
}

sway_exited() {
	! kill -0 "$sway_pid" 2>/dev/null
}

login 1
old_sock="$SWAYSOCK"
old_wayland=
for file in "$runtime"/wayland-*; do
	[ -e "$file" ] && old_wayland="$old_wayland $file"
done
[ -n "$old_wayland" ] || fail "login 1 created no wayland-* socket in $runtime"

swaymsg_ exit >/dev/null 2>&1 || :
wait_for 10 sway_exited || fail "sway is still running after swaymsg exit"
wait "$login_job" 2>/dev/null || :
sway_pid=
sleep 5

# shellcheck disable=SC2046
left="$(describe_pids $(login_pids 1))"
[ -z "$left" ] || fail "processes from the logged-out session are still running:
$left"
[ ! -e "$old_sock" ] || fail "the old sway IPC socket $old_sock was left behind"
for file in $old_wayland; do
	[ ! -e "$file" ] || fail "the old Wayland file $file was left behind"
done

login 2
app_views_is org.autobutler.quark 1 || fail "the new session has $(swaymsg_ -t get_tree | jq '[.. | objects | select(.app_id? == "org.autobutler.quark")] | length') Quark views, not 1"
app_on_workspace org.autobutler.quark 1:quark || fail "the new session's Quark is not on 1:quark"
loops="$(pgrep -fc "$tmp/usr/bin/quark-de-respawn" || :)"
[ "$loops" -eq 1 ] || fail "the new session runs $loops quark-de-respawn loops, not 1"
# shellcheck disable=SC2046
no_login_pids 1 || fail "the new login revived processes from the old one:
$(describe_pids $(login_pids 1))"
echo "ok  logout leaves no orphan processes or sockets, and the next login starts one Quark"
