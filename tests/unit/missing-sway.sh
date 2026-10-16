#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub_bin logger foot firefox

if run_session XDG_STATE_HOME=; then
	fail "quark-de exited 0 without sway or quark"
fi
grep -q 'sudo apt install sway' "$tmp/home/.local/state/quark-de/session.log" ||
	fail "session.log lacks the sway hint: $(cat "$tmp/out.log")"
grep -q -- '-t quark-de .*sudo apt install sway' "$tmp/logger.calls" || fail "logger was not called with the sway hint"

rm "$bin/logger"
if run_session XDG_STATE_HOME=; then
	fail "quark-de exited 0 without sway, quark or logger"
fi
grep -q 'sudo apt install sway' "$tmp/out.log" || fail "the sway hint did not reach stderr without logger"
echo "ok  missing sway fails and logs why"
