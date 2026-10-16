#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
for app in foot firefox; do
	rm -rf "${tmp:?}/bin" "$tmp/state" "$tmp/sway.calls" "$tmp/logger.calls"
	other=firefox
	[ "$app" = firefox ] && other=foot
	stub_bin sway quark logger "$other"
	run_session XDG_STATE_HOME="$tmp/state" || fail "quark-de failed with $app missing: $(cat "$tmp/out.log")"
	grep -q "warning: $app is missing" "$tmp/state/quark-de/session.log" || fail "no warning logged for missing $app"
	grep -q "warning: $app is missing" "$tmp/logger.calls" || fail "logger got no warning for missing $app"
	grep -q -- "--config $tmp/usr/share/quark-de/sway/config$" "$tmp/sway.calls" ||
		fail "sway did not start with the main config when $app was missing"
done
echo "ok  missing foot or firefox warns and starts"
