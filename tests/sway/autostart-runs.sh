#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
sway_start
wait_for 10 test -e "$tmp/autostart.ran" ||
	fail "the session did not run quark-de-autostart; add 'exec quark-de-autostart' to config/sway/config"
echo "ok  autostart runs"
