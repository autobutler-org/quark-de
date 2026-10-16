#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
readonly launcher="$tmp/root/usr/bin/quark-de"
make -s -C "$repo" install DESTDIR="$tmp/root" PREFIX=/usr >/dev/null
ln -s "$(command -v dirname)" "$tmp/shim/dirname"
ln -s "$(command -v cat)" "$tmp/shim/cat"
stub sway "echo \"\$*\" >'$tmp/sway.ran'"

run() {
	status=0
	env PATH="$tmp/shim" "$launcher" "$@" >"$tmp/out" 2>"$tmp/err" || status=$?
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
