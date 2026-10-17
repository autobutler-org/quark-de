#!/bin/sh
set -eu

repo="$(cd "$(dirname "$0")/../.." && pwd)"
readonly repo

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make -s -C "$repo" install PREFIX="$tmp/usr" WAYLAND_SESSIONS="$tmp/wayland-sessions" >/dev/null
mkdir "$tmp/bin"
for cmd in sway quark foot firefox swayidle swaylock; do
	printf '#!/bin/sh\n' >"$tmp/bin/$cmd"
	chmod +x "$tmp/bin/$cmd"
done
ln -s "$(command -v dirname)" "$tmp/bin/dirname"

PATH="$tmp/bin" /bin/sh "$tmp/usr/bin/quark-de" --check >"$tmp/out" 2>&1 ||
	fail "quark-de --check failed when only optional tools are missing: $(cat "$tmp/out")"
for cmd in wpctl brightnessctl playerctl notify-send grim slurp wl-copy; do
	grep -q "^warning  $cmd — " "$tmp/out" || fail "quark-de --check did not warn about $cmd: $(cat "$tmp/out")"
done
grep -q '^warning  wl-copy — sudo apt install wl-clipboard' "$tmp/out" || fail "quark-de --check does not say wl-copy comes from wl-clipboard: $(cat "$tmp/out")"

rm "$tmp/bin/foot"
if PATH="$tmp/bin" /bin/sh "$tmp/usr/bin/quark-de" --check >"$tmp/out" 2>&1; then
	fail "quark-de --check passed with foot missing"
fi
echo "ok  check optional tools"
