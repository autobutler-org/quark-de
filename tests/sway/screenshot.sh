#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

command -v grim >/dev/null || fail "grim not found: sudo apt install grim"

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

display=""
for sock in "$runtime"/wayland-*; do
	[ -S "$sock" ] && display="${sock##*/}" && break
done
[ -n "$display" ] || fail "sway created no wayland socket in $runtime"
mkdir -p "$tmp/home"
printf '#!/bin/sh\ncat >/dev/null\n' >"$tmp/shim/wl-copy"
printf '#!/bin/sh\n' >"$tmp/shim/notify-send"
chmod +x "$tmp/shim/wl-copy" "$tmp/shim/notify-send"
file="$(sway_env HOME="$tmp/home" WAYLAND_DISPLAY="$display" quark-de-screenshot full)" ||
	fail "quark-de-screenshot full failed"

case "$file" in
"$tmp/home/Pictures/Screenshots/"*.png) ;;
*) fail "screenshot saved to '$file', expected ~/Pictures/Screenshots/<timestamp>.png" ;;
esac
[ -s "$file" ] || fail "$file is empty or missing"
[ "$(head -c 8 "$file" | od -An -tx1 | tr -d ' \n')" = 89504e470d0a1a0a ] || fail "$file is not a PNG"
echo "ok  screenshot full"
