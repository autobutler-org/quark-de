#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub swayidle "printf '%s\\n' \"\$@\" >\"$tmp/swayidle.args\""
mkdir -p "$tmp/config/quark-de/sway"
printf "set \$lock_timeout 120\n" >"$tmp/config/quark-de/sway/idle"
sway_start
wait_for 10 test -s "$tmp/swayidle.args" || fail "sway did not start swayidle"

args="$(tr '\n' ' ' <"$tmp/swayidle.args")"
for part in "timeout 120 swaylock -f" "timeout 600 swaymsg \"output * power off\"" "lock swaylock -f"; do
	case "$args" in
	*"$part"*) ;;
	*) fail "swayidle was started without \"$part\": $args" ;;
	esac
done
echo "ok  idle timeouts"
