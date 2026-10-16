#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

sway_env sway --validate --config "$config" >"$tmp/validate.log" 2>&1 ||
	fail "sway --validate rejected the config: $(cat "$tmp/validate.log")"

sed '/^include /d' "$config" >"$tmp/config.no-includes"
sway_env sway --validate --config "$tmp/config.no-includes" >"$tmp/validate.log" 2>&1 ||
	fail "sway --validate rejected the config without distro snippets: $(cat "$tmp/validate.log")"

sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
if grep -E 'Error on line|Unknown/invalid command' "$tmp/sway.log"; then
	fail "sway reported config errors at runtime"
fi
echo "ok  config parses"
