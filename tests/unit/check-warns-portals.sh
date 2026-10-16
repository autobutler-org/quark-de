#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

for cmd in sway foot swayidle swaylock; do
	printf '#!/bin/sh\n' >"$tmp/shim/$cmd"
	chmod +x "$tmp/shim/$cmd"
done
mkdir -p "$tmp/data"

run_check() {
	XDG_DATA_DIRS="$tmp/data" PATH="$tmp/shim:$PATH" "$tmp/usr/bin/quark-de" --check
}

out="$(run_check)" || fail "quark-de --check must only warn about missing portals, not fail: $out"
for portal in xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
	echo "$out" | grep -q "^warn  *$portal " || fail "quark-de --check did not warn about missing $portal: $out"
done

mkdir -p "$tmp/data/dbus-1/services" "$tmp/data/xdg-desktop-portal/portals"
touch "$tmp/data/dbus-1/services/org.freedesktop.portal.Desktop.service" \
	"$tmp/data/xdg-desktop-portal/portals/wlr.portal" "$tmp/data/xdg-desktop-portal/portals/gtk.portal"
out="$(run_check)" || fail "quark-de --check failed with every portal installed: $out"
for portal in xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
	echo "$out" | grep -q "^ok  *$portal$" || fail "quark-de --check did not find installed $portal: $out"
done
echo "ok  check warns about missing portals"
