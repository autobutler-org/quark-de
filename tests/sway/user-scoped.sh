#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

owner_is() {
	[ "$(ps -o user= -p "$1" | tr -d ' ')" = "$2" ]
}

# Processes whose session is the runtime dir $1, as "pid comm" lines.
pids_in() {
	for environ in /proc/[0-9]*/environ; do
		pid="${environ#/proc/}"
		pid="${pid%/environ}"
		{ tr '\0' '\n' <"$environ"; } 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=$1" &&
			echo "$pid $(cat "/proc/$pid/comm" 2>/dev/null)"
	done
	return 0
}

# @pending: two real users logged in through the greeter (#15). Until it lands,
# this runs only when the nightly VM job, as root, names two logged-in users,
# e.g. QUARK_DE_TEST_USERS="alice bob".
greeter_session_scoped() {
	user="$1" peer="$2"
	dir="/run/user/$(id -u "$user")"
	pids_in "$dir" >"$tmp/$user.pids"
	grep -q ' sway$' "$tmp/$user.pids" || fail "$user has no sway session in $dir; log in through the greeter first"
	grep -q ' quark' "$tmp/$user.pids" || fail "$user's session in $dir has no quark running"
	while read -r pid comm; do
		user_="$(ps -o user= -p "$pid" | tr -d ' ')" || continue
		[ "$user_" = "$user" ] || fail "$comm ($pid) in $user's session runs as $user_"
	done <"$tmp/$user.pids"
	[ "$(stat -c %U:%a "$dir")" = "$user:700" ] || fail "$dir is $(stat -c %U:%a "$dir"), not $user:700"
	for sock in "$dir"/sway-ipc.*.sock; do
		[ -S "$sock" ] || fail "no sway IPC socket in $dir"
		[ "$(stat -c %U "$sock")" = "$user" ] || fail "$sock is owned by $(stat -c %U "$sock"), not $user"
		runuser -u "$user" -- swaymsg -s "$sock" -t get_version >/dev/null || fail "$user cannot use their own socket $sock"
		if runuser -u "$peer" -- swaymsg -s "$sock" -t get_tree >/dev/null 2>&1; then
			fail "$peer could read $user's tree through $sock"
		fi
	done
}

if [ -n "${QUARK_DE_TEST_USERS:-}" ]; then
	# shellcheck disable=SC2086
	set -- $QUARK_DE_TEST_USERS
	[ "$#" -eq 2 ] || fail "QUARK_DE_TEST_USERS needs exactly two users, got: $QUARK_DE_TEST_USERS"
	[ "$(id -u)" -eq 0 ] || fail "the greeter-login check reads other users' sessions; run it as root"
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	greeter_session_scoped "$1" "$2"
	greeter_session_scoped "$2" "$1"
	echo "ok  greeter sessions for $1 and $2 are scoped to their users"
	exit 0
fi
echo "pending greeter logins: set QUARK_DE_TEST_USERS to two users logged in through the greeter (#15)"

[ "$(id -u)" -ne 0 ] || {
	echo "skip user-scoped harness: run as a regular user; as root every process is trivially root's"
	exit 0
}
me="$(id -un)"
readonly me

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

owner_is "$sway_pid" "$me" || fail "sway runs as $(ps -o user= -p "$sway_pid"), not $me"
quark_pid="$(swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "org.autobutler.quark") | .pid')"
[ -n "$quark_pid" ] || fail "no quark window to inspect"
owner_is "$quark_pid" "$me" || fail "quark runs as $(ps -o user= -p "$quark_pid"), not $me"
pids_in "$runtime" >"$tmp/session.pids"
while read -r pid comm; do
	user="$(ps -o user= -p "$pid" | tr -d ' ')" || continue
	[ "$user" = "$me" ] || fail "$comm ($pid) in the session runs as $user, not $me"
done <"$tmp/session.pids"

[ "$(stat -c %U:%a "$runtime")" = "$me:700" ] || fail "the runtime dir is $(stat -c %U:%a "$runtime"), not $me:700"
[ "$(dirname "$SWAYSOCK")" = "$runtime" ] || fail "SWAYSOCK=$SWAYSOCK is outside the runtime dir $runtime"
[ "$(stat -c %U "$SWAYSOCK")" = "$me" ] || fail "SWAYSOCK is owned by $(stat -c %U "$SWAYSOCK"), not $me"
echo "ok  sway, quark and the runtime dir belong to the user"

# Another account must not reach this session's IPC socket.
other=nobody
if sudo -n -u "$other" true 2>/dev/null; then
	swaymsg_ -t get_version >/dev/null || fail "swaymsg failed for the session's own user"
	if sudo -n -u "$other" "$(command -v swaymsg)" -s "$SWAYSOCK" -t get_tree >/dev/null 2>&1; then
		fail "$other could read this session's tree through $SWAYSOCK"
	fi
	echo "ok  another user cannot use the session's IPC socket"
else
	echo "skip cross-user IPC: needs passwordless 'sudo -u $other'"
fi
