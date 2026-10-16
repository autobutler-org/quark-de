#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
readonly root="$tmp/root"
readonly launcher="$root/usr/bin/quark-de"
readonly config="$root/usr/share/quark-de/sway/config"
readonly desktop="$root/usr/share/wayland-sessions/quark-de.desktop"

make -s -C "$repo" install DESTDIR="$root" PREFIX=/usr >/dev/null

[ -x "$launcher" ] || fail "make install did not install an executable $launcher"
[ -f "$config" ] || fail "make install did not install $config"
[ -f "$desktop" ] || fail "make install did not install $desktop"
grep -qx 'Exec=/usr/bin/quark-de' "$desktop" ||
	fail "make install did not rewrite Exec= to /usr/bin/quark-de: $(grep '^Exec=' "$desktop")"

"$launcher" --check >"$tmp/check.log" 2>&1 || :
grep -Eq '^(ok|missing) +sway( |$)' "$tmp/check.log" || fail "quark-de --check did not run its checks: $(cat "$tmp/check.log")"
if grep -q '^missing  /' "$tmp/check.log"; then
	fail "quark-de --check did not find the installed config: $(cat "$tmp/check.log")"
fi

make -s -C "$repo" uninstall DESTDIR="$root" PREFIX=/usr >/dev/null
leftover="$(find "$root" ! -type d)"
[ -z "$leftover" ] || fail "make uninstall left files behind: $leftover"
echo "ok  install"
