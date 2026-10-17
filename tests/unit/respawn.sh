#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

stub() {
	printf '#!/bin/sh\n%s\n' "$2" >"$dir/bin/$1"
	chmod +x "$dir/bin/$1"
}

case_setup() {
	dir="$tmp/$1"
	mkdir -p "$dir/bin" "$dir/state"
	stub swaynag "printf '%s\n' \"\$@\" >'$dir/nag'"
	stub swaymsg "[ \"\$*\" = '-t get_version' ] || echo \"\$*\" >>'$dir/swaymsg'"
}

respawn() {
	env PATH="$dir/bin:$PATH" XDG_STATE_HOME="$dir/state" sh "$repo/session/quark-de-respawn" 1:quark &
	respawn_pid=$!
}

runs() {
	if [ -e "$dir/runs" ]; then wc -l <"$dir/runs"; else echo 0; fi
}

exited() {
	! kill -0 "$respawn_pid" 2>/dev/null
}

case_setup always-failing
stub quark "echo run >>'$dir/runs'; exit 1"
respawn
wait_for 15 exited || {
	kill "$respawn_pid"
	fail "always-failing: still looping after $(runs) runs"
}
[ "$(runs)" -eq 3 ] || fail "always-failing: expected 3 runs before giving up, got $(runs)"
[ -e "$dir/nag" ] || fail "always-failing: swaynag was not called"
for want in 'Quark keeps crashing.' 'Open terminal' 'View log' 'Retry' 'Log out' 'swaymsg exit'; do
	grep -qxF "$want" "$dir/nag" || fail "always-failing: swaynag arguments lack '$want': $(cat "$dir/nag")"
done
echo "ok  respawn gives up and nags after 3 fast exits"

case_setup crash-once
stub quark "echo run >>'$dir/runs'; [ \"\$(wc -l <'$dir/runs')\" -gt 1 ] || exit 1; echo \$\$ >'$dir/pid'; exec sleep 60"
respawn
wait_for 10 test -s "$dir/pid" || fail "crash-once: quark was not restarted"
sleep 2
kill "$respawn_pid"
kill "$(cat "$dir/pid")"
[ "$(runs)" -eq 2 ] || fail "crash-once: expected exactly 1 restart, got $(($(runs) - 1))"
[ ! -e "$dir/nag" ] || fail "crash-once: swaynag was called: $(cat "$dir/nag")"
[ "$(cat "$dir/swaymsg")" = "workspace 1:quark" ] || fail "crash-once: expected one 'workspace 1:quark', got: $(cat "$dir/swaymsg")"
echo "ok  respawn restarts a crash once and does not nag"

case_setup stderr
stub quark "echo 'quark: libfoo.so.1 not found' >&2; exit 1"
respawn
wait_for 15 exited || {
	kill "$respawn_pid"
	fail "stderr: still looping"
}
grep -qF 'quark: libfoo.so.1 not found' "$dir/state/quark-de/quark.log" ||
	fail "stderr: quark's stderr is not in the log"
echo "ok  respawn appends quark's stderr to the log"

case_setup sway-gone
stub quark "echo run >>'$dir/runs'; exit 1"
stub swaymsg "[ \"\$*\" != '-t get_version' ] || exit 1"
respawn
wait_for 5 exited || {
	kill "$respawn_pid"
	fail "sway-gone: still looping after $(runs) runs"
}
[ "$(runs)" -eq 1 ] || fail "sway-gone: expected 1 run before stopping, got $(runs)"
[ ! -e "$dir/nag" ] || fail "sway-gone: swaynag was called: $(cat "$dir/nag")"
grep -qF 'sway is gone' "$dir/state/quark-de/quark.log" || fail "sway-gone: the stop was not logged"
echo "ok  respawn stops once sway is gone"
