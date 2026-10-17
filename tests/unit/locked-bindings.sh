#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup

check_locked() {
	grep -En '^[[:space:]]*bind(sym|code|switch)[[:space:]].*--locked' "$1" |
		grep -Ev '[[:space:]]exec quark-de-osd [a-z-]+[[:space:]]*$' || :
}

for file in "$repo"/config/sway/*; do
	bad="$(check_locked "$file")"
	[ -z "$bad" ] ||
		fail "$file runs something other than quark-de-osd while the screen is locked; drop --locked from: $bad"
done

printf 'bindsym --locked XF86AudioMute exec quark-de-osd mute\nbindsym --to-code --locked Mod4+Return exec foot\n' >"$tmp/config"
[ -n "$(check_locked "$tmp/config")" ] || fail "the --locked check misses 'bindsym --locked ... exec foot'"
echo "ok  locked bindings"
