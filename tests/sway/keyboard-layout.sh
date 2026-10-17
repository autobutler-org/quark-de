#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
grep -qx 'exec quark-de-keyboard' "$config" || fail "the sway config does not run quark-de-keyboard at startup"

sway_start
fixture="$repo/tests/fixtures/keyboard/default-keyboard"
sway_env SWAYSOCK="$SWAYSOCK" quark-de-keyboard "$fixture" 2>"$tmp/keyboard.err" ||
	fail "sway rejected the layout from $fixture: $(cat "$tmp/keyboard.err")"

printf 'XKBLAYOUT="no-such-layout"\n' >"$tmp/bad-keyboard"
sway_env SWAYSOCK="$SWAYSOCK" quark-de-keyboard "$tmp/bad-keyboard" 2>"$tmp/keyboard.err" &&
	fail "quark-de-keyboard reported success for a layout sway cannot compile"
grep -q 'localectl set-x11-keymap' "$tmp/keyboard.err" || fail "the error does not say how to fix the layout: $(cat "$tmp/keyboard.err")"

echo "ok  keyboard layout"
