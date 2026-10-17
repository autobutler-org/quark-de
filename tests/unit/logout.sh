#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
readonly repo
tmp="$(mktemp -d)"
readonly tmp
cleanup() {
	for pidfile in "$tmp"/*/loop.pid "$tmp"/*/quark.pid; do
		if [ -s "$pidfile" ]; then kill -KILL "$(cat "$pidfile")" 2>/dev/null || :; fi
	done
	rm -rf "$tmp"
}
trap cleanup EXIT

stub() {
	printf '#!/bin/sh\n%s\n' "$2" >"$dir/bin/$1"
	chmod +x "$dir/bin/$1"
}

case_setup() {
	dir="$tmp/$1"
	mkdir -p "$dir/bin" "$dir/state"
	: >"$dir/calls"
	stub swaymsg "echo \"swaymsg \$*\" >>'$dir/calls'"
	stub systemctl "echo \"systemctl \$*\" >>'$dir/calls'"
	stub quark "echo run >>'$dir/runs'; trap 'echo \"quark TERM\" >>\"$dir/calls\"; exit 0' TERM; echo \$\$ >'$dir/quark.pid'; while :; do sleep 0.1; done"
}

session_env() {
	env PATH="$dir/bin:$PATH" XDG_STATE_HOME="$dir/state" "$@"
}

start_loop() {
	(
		env PATH="$dir/bin:$PATH" XDG_STATE_HOME="$dir/state" sh "$repo/session/quark-de-respawn" 1:quark &
		echo $! >"$dir/loop.pid"
	)
	loop_pid="$(cat "$dir/loop.pid")"
	wait_for 10 test -s "$dir/quark.pid" || fail "$case: quark did not start"
}

logout() {
	session_env sh "$repo/session/quark-de-logout" "$@" 2>"$dir/stderr"
}

expect_calls() {
	want="$(printf '%s\n' "$@")"
	[ "$(cat "$dir/calls")" = "$want" ] ||
		fail "$case: expected calls:
$want
got:
$(cat "$dir/calls")"
}

expect_stopped() {
	sleep 2
	! kill -0 "$loop_pid" 2>/dev/null || fail "$case: the respawn loop is still running"
	! kill -0 "$(cat "$dir/quark.pid")" 2>/dev/null || fail "$case: quark is still running"
	[ "$(wc -l <"$dir/runs")" -eq 1 ] || fail "$case: quark was restarted after logout"
}

case=logout
case_setup "$case"
start_loop
logout
expect_calls 'quark TERM' 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target' 'swaymsg exit'
expect_stopped
echo "ok  logout stops the respawn loop, then quark, then graphical-session.target, then sway"

case=no-systemd
case_setup "$case"
stub systemctl "echo \"systemctl \$*\" >>'$dir/calls'; exit 1"
start_loop
logout logout
expect_calls 'quark TERM' 'systemctl --user show-environment' 'swaymsg exit'
expect_stopped
echo "ok  logout without a systemd user manager skips graphical-session.target"

for action in poweroff reboot; do
	case="$action"
	case_setup "$case"
	start_loop
	logout "$action"
	expect_calls 'quark TERM' 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target' "systemctl $action"
	expect_stopped
	echo "ok  $action closes quark first, then goes through logind"
done

case=poweroff-denied
case_setup "$case"
stub systemctl "echo \"systemctl \$*\" >>'$dir/calls'; [ \"\$1\" != poweroff ]"
start_loop
logout poweroff
expect_calls 'quark TERM' 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target' 'systemctl poweroff' 'swaymsg exit'
grep -q 'logind' "$dir/stderr" || fail "$case: no hint about logind: $(cat "$dir/stderr")"
expect_stopped
echo "ok  a refused poweroff logs out instead of leaving an empty desktop"

case=stubborn
case_setup "$case"
stub quark "echo run >>'$dir/runs'; trap 'echo \"quark TERM\" >>\"$dir/calls\"' TERM; echo \$\$ >'$dir/quark.pid'; while :; do sleep 0.1; done"
start_loop
start=$(date +%s)
logout
elapsed=$(($(date +%s) - start))
[ "$elapsed" -ge 4 ] || fail "$case: logout took ${elapsed}s, so it did not wait for quark"
[ "$elapsed" -le 8 ] || fail "$case: logout took ${elapsed}s, expected about 5s of grace"
expect_calls 'quark TERM' 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target' 'swaymsg exit'
echo "ok  logout waits a few seconds for quark, then goes on"

case=no-loop
case_setup "$case"
logout
expect_calls 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target' 'swaymsg exit'
echo "ok  logout works without a respawn loop"

case=bad-action
case_setup "$case"
if logout suspend; then fail "$case: an unknown action was accepted"; fi
expect_calls
echo "ok  logout rejects an unknown action"

for config in "$repo/config/sway/config" "$repo/config/sway/fallback"; do
	binding="$(grep "^bindsym \\\$mod+Shift+e " "$config")" || fail "no Super+Shift+E in $config"
	for part in "-B 'Log out' 'quark-de-logout'" "-Z 'Lock' 'swaylock -f'" \
		"-B 'Power off' 'quark-de-logout poweroff'" "-B 'Reboot' 'quark-de-logout reboot'"; do
		case "$binding" in
		*"$part"*) ;;
		*) fail "Super+Shift+E in $config lacks \"$part\": $binding" ;;
		esac
	done
done
echo "ok  Super+Shift+E offers log out, lock, power off and reboot"
