#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
config="$tmp/usr/share/quark-de/sway/fallback"

sway_env sway --validate --config "$config" >"$tmp/validate.log" 2>&1 ||
	fail "sway --validate rejected the fallback config: $(cat "$tmp/validate.log")"

sed '/^include /d' "$config" >"$tmp/fallback.no-includes"
sway_env sway --validate --config "$tmp/fallback.no-includes" >"$tmp/validate.log" 2>&1 ||
	fail "sway --validate rejected the fallback config without distro snippets: $(cat "$tmp/validate.log")"

QUARK_DE_ERROR="Quark is missing: test message $tmp"
export QUARK_DE_ERROR
sway_start
wait_for 10 views_up 1 || fail "the fallback session did not open foot"

nag_up() {
	[ "$(cat "$tmp/swaynag.args" 2>/dev/null)" = "$(printf '%s\n' -t error -m "$QUARK_DE_ERROR" -B "Log out" "swaymsg exit")" ]
}
wait_for 10 nag_up || fail "the fallback session did not show the error in swaynag: $(cat "$tmp/swaynag.args" 2>/dev/null)"
if grep -E 'Error on line|Unknown/invalid command' "$tmp/sway.log"; then
	fail "sway reported fallback config errors at runtime"
fi
echo "ok  fallback session shows the error"
