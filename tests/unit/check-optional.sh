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
make -s -C "$repo" install DESTDIR="$tmp" PREFIX=/usr >/dev/null
mkdir "$tmp/bin"
for cmd in sway quark foot firefox swayidle swaylock; do
	printf '#!/bin/sh\n' >"$tmp/bin/$cmd"
	chmod +x "$tmp/bin/$cmd"
done
ln -s "$(command -v dirname)" "$tmp/bin/dirname"

PATH="$tmp/bin" /bin/sh "$tmp/usr/bin/quark-de" --check >"$tmp/out" 2>&1 ||
	fail "quark-de --check failed when only optional tools are missing: $(cat "$tmp/out")"
for cmd in wpctl brightnessctl playerctl notify-send; do
	grep -q "^warning  $cmd — " "$tmp/out" || fail "quark-de --check did not warn about $cmd: $(cat "$tmp/out")"
done

rm "$tmp/bin/foot"
if PATH="$tmp/bin" /bin/sh "$tmp/usr/bin/quark-de" --check >"$tmp/out" 2>&1; then
	fail "quark-de --check passed with foot missing"
fi
echo "ok  check optional tools"
