#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
make -s -C "$repo" install PREFIX="$tmp/usr" WAYLAND_SESSIONS="$tmp/wayland-sessions" >/dev/null
for tool in dirname mkdir date ls; do
	ln -s "$(command -v "$tool")" "$tmp/shim/$tool"
done
stub quark
stub sway ": >'$tmp/sway.ran'"
stub id "echo \"\${QUARK_DE_TEST_UID:-$(id -u)}\""

run() {
	rm -rf "$tmp/sway.ran" "$tmp/state"
	status=0
	env -i HOME="$tmp/home" PATH="$tmp/shim" XDG_STATE_HOME="$tmp/state" "$@" "$tmp/usr/bin/quark-de" >"$tmp/out" 2>&1 || status=$?
}

refused() {
	[ "$status" -ne 0 ] || fail "quark-de exited 0 with $1"
	[ ! -e "$tmp/sway.ran" ] || fail "quark-de ran sway with $1"
	grep -q "$2" "$tmp/out" || fail "quark-de with $1 did not say '$2': $(cat "$tmp/out")"
	grep -q "$2" "$tmp/state/quark-de/session.log" || fail "quark-de with $1 did not log '$2'"
}

run
refused "XDG_RUNTIME_DIR unset" 'XDG_RUNTIME_DIR is not set.*log in through the display manager'

run XDG_RUNTIME_DIR="$tmp/missing"
refused "a missing XDG_RUNTIME_DIR" "XDG_RUNTIME_DIR=$tmp/missing does not exist.*log in again"

mkdir -m 755 "$tmp/run"
run XDG_RUNTIME_DIR="$tmp/run"
refused "XDG_RUNTIME_DIR mode 0755" "has mode drwxr-xr-x, not 0700.*chmod 0700 $tmp/run"

chmod 700 "$tmp/run"
run XDG_RUNTIME_DIR="$tmp/run" QUARK_DE_TEST_UID=4242
refused "someone else's XDG_RUNTIME_DIR" "belongs to uid $(id -u), not you (uid 4242).*instead of su or sudo"

run XDG_RUNTIME_DIR="$tmp/run"
[ "$status" -eq 0 ] || fail "quark-de failed with a good XDG_RUNTIME_DIR: $(cat "$tmp/out")"
[ -e "$tmp/sway.ran" ] || fail "quark-de did not start sway with a good XDG_RUNTIME_DIR"
echo "ok  launcher checks XDG_RUNTIME_DIR"
