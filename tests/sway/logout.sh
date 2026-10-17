#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub systemctl "echo \"systemctl \$*\" >>'$tmp/calls'"
stub quark "trap 'echo \"quark TERM\" >>\"$tmp/calls\"; exit 0' TERM; foot --app-id=org.autobutler.quark & wait"

sway_exited() {
	! kill -0 "$sway_pid" 2>/dev/null
}

sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
swaymsg_ exec quark-de-logout >/dev/null
wait_for 10 sway_exited || fail "sway is still running after quark-de-logout"
want="$(printf '%s\n' 'quark TERM' 'systemctl --user show-environment' 'systemctl --user stop graphical-session.target')"
got="$(grep -v 'import-environment' "$tmp/calls" || :)"
[ "$got" = "$want" ] || fail "expected calls:
$want
got:
$got"
sway_pid=
echo "ok  quark-de-logout closes quark and ends the sway session"
