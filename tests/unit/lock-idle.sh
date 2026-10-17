#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
readonly repo
readonly config="$repo/config/sway/config"

grep -qxF "bindsym \$mod+l exec swaylock -f" "$config" ||
	fail "Super+L does not lock: add 'bindsym \$mod+l exec swaylock -f' to config/sway/config"

idle="$(grep '^exec swayidle ' "$config")" ||
	fail "no swayidle exec in config/sway/config: the screen never locks or blanks when idle"
for part in "-w " "timeout \$lock_timeout 'swaylock -f'" "timeout \$screen_off_timeout 'swaymsg \"output * power off\"'" \
	"resume 'swaymsg \"output * power on\"'" "before-sleep 'swaylock -f'" "lock 'swaylock -f'"; do
	case "$idle" in
	*"$part"*) ;;
	*) fail "the swayidle exec is missing \"$part\": $idle" ;;
	esac
done

for default in "set \$lock_timeout 300" "set \$screen_off_timeout 600"; do
	grep -qxF "$default" "$config" || fail "config/sway/config does not default to '$default'"
done

doctor="$(sh "$repo/session/quark-de" --check 2>&1 || :)"
for cmd in swayidle swaylock; do
	printf '%s\n' "$doctor" | grep -Eq "^(ok|missing) +$cmd( |$)" ||
		fail "quark-de --check does not report $cmd"
done
echo "ok  lock and idle"
