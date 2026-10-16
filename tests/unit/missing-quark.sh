#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub_bin logger foot firefox
cat >"$bin/sway" <<STUB
#!/bin/sh
echo "\$*" >>"$tmp/sway.calls"
echo "\$QUARK_DE_ERROR" >"$tmp/nag.txt"
STUB
chmod +x "$bin/sway"

run_session XDG_STATE_HOME="$tmp/state" ||
	fail "quark-de failed instead of starting the fallback session: $(cat "$tmp/out.log")"

grep -q -- "--config $tmp/usr/share/quark-de/sway/fallback" "$tmp/sway.calls" ||
	fail "sway was not started with the fallback config: $(cat "$tmp/sway.calls")"
hint='github.com/autobutler-org/quark/releases'
grep -q "$hint" "$tmp/state/quark-de/session.log" || fail "session.log lacks the install hint"
grep -q -- "-t quark-de .*$hint" "$tmp/logger.calls" || fail "logger was not called with the install hint"
grep -q "$hint" "$tmp/nag.txt" || fail "QUARK_DE_ERROR did not reach sway"
echo "ok  missing quark starts the fallback session"
