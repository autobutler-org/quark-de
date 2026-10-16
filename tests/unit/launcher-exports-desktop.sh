#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

printf '#!/bin/sh\nenv\n' >"$tmp/shim/sway"
chmod +x "$tmp/shim/sway"

env -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP PATH="$tmp/shim:$PATH" \
	"$tmp/usr/bin/quark-de" >"$tmp/env" 2>"$tmp/err" ||
	fail "quark-de did not reach sway: $(cat "$tmp/err")"

grep -qx 'XDG_CURRENT_DESKTOP=Quark:sway' "$tmp/env" ||
	fail "quark-de must export XDG_CURRENT_DESKTOP=Quark:sway before exec sway so portals pick quark-portals.conf"
grep -qx 'XDG_SESSION_DESKTOP=quark-de' "$tmp/env" ||
	fail "quark-de must export XDG_SESSION_DESKTOP=quark-de before exec sway"

desktop="$(sed -n 's/^XDG_CURRENT_DESKTOP=//p' "$tmp/env" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')"
portals="$tmp/usr/share/xdg-desktop-portal/$desktop-portals.conf"
[ -r "$portals" ] || fail "make install must put $desktop-portals.conf in \$(PREFIX)/share/xdg-desktop-portal/ to match XDG_CURRENT_DESKTOP"

value() {
	sed -n "s/^$1=//p" "$portals"
}
[ "$(value default)" = "gtk" ] || fail "$portals must set default=gtk"
for iface in ScreenCast Screenshot; do
	[ "$(value "org.freedesktop.impl.portal.$iface")" = "wlr" ] ||
		fail "$portals must route org.freedesktop.impl.portal.$iface to wlr"
done

make -s -C "$repo" uninstall DESTDIR="$tmp" PREFIX=/usr >/dev/null
[ ! -e "$portals" ] || fail "make uninstall left $portals behind"
echo "ok  launcher exports desktop and portals config installed"
