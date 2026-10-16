#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

nagged() {
	[ -e "$tmp/swaynag.args" ] && [ "$(grep -c 'Super+Tab' "$tmp/swaynag.args")" -eq "$1" ]
}

sway_start
wait_for 10 nagged 1 || fail "the first login did not show the cheat sheet; log: $(cat "$tmp/sway.log")"
[ -e "$tmp/state/quark-de/first-login-hint-shown" ] || fail "the first login left no marker"

swaymsg_ -t get_config | jq -r .config >"$tmp/loaded.config"
for key in slash F1; do
	grep -qxF "bindsym \$mod+$key exec quark-de-hint" "$tmp/loaded.config" ||
		fail "\$mod+$key is not bound to quark-de-hint in the loaded config"
	swaymsg_ unbindsym "Mod4+$key" >/dev/null || fail "sway has no Mod4+$key binding"
done

swaymsg_ exec quark-de-hint >/dev/null
wait_for 5 nagged 2 || fail "quark-de-hint did not show the cheat sheet from inside sway"

echo "ok  cheat sheet"
