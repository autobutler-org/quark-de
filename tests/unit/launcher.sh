#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
readonly launcher="$tmp/root/usr/bin/quark-de"
make -s -C "$repo" install PREFIX="$tmp/root/usr" WAYLAND_SESSIONS="$tmp/root/wayland-sessions" >/dev/null
for tool in dirname cat ls id; do
	ln -s "$(command -v "$tool")" "$tmp/shim/$tool"
done
mkdir -m 700 "$tmp/run"
stub sway "echo \"\$*\" >'$tmp/sway.ran'"

run() {
	status=0
	env PATH="$tmp/shim" XDG_RUNTIME_DIR="$tmp/run" "$launcher" "$@" >"$tmp/out" 2>"$tmp/err" || status=$?
}

run -h
[ "$status" -eq 0 ] || fail "quark-de -h exited $status, want 0"
grep -q '^Usage: quark-de' "$tmp/out" || fail "quark-de -h did not print usage: $(cat "$tmp/out")"

run --bogus
[ "$status" -eq 2 ] || fail "quark-de --bogus exited $status, want 2"
grep -q "unknown argument '--bogus'" "$tmp/err" || fail "quark-de --bogus did not name the argument: $(cat "$tmp/err")"

run
[ "$status" -eq 0 ] || fail "quark-de without quark on PATH exited $status, want 0"
grep -q 'install the Quark Linux app from https://github.com/autobutler-org/quark/releases' "$tmp/err" ||
	fail "quark-de without quark on PATH did not print the install hint: $(cat "$tmp/err")"
[ "$(cat "$tmp/sway.ran")" = "--config $tmp/root/usr/share/quark-de/sway/fallback" ] ||
	fail "quark-de without quark on PATH did not start the fallback session: $(cat "$tmp/sway.ran" 2>/dev/null)"
echo "ok  launcher"
