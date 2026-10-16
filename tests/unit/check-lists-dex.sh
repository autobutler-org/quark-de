#!/bin/sh
set -eu

launcher="$(cd "$(dirname "$0")/../.." && pwd)/session/quark-de"
readonly launcher
tmp="$(mktemp -d)"
readonly tmp
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: quark-de --check: $1" >&2
	echo "$out" >&2
	exit 1
}

mkdir "$tmp/bin"
ln -s "$(command -v dirname)" "$tmp/bin/dirname"

out="$(PATH="$tmp/bin" /bin/sh "$launcher" --check 2>&1)" || :
echo "$out" | grep -q '^warning  dex — sudo apt install dex' || fail "does not list a missing dex as optional with an install hint"

for cmd in sway quark foot firefox dex; do
	printf '#!/bin/sh\n' >"$tmp/bin/$cmd"
	chmod +x "$tmp/bin/$cmd"
done
out="$(PATH="$tmp/bin" /bin/sh "$launcher" --check 2>&1)" || :
echo "$out" | grep -qx 'ok       dex' || fail "does not report an installed dex as ok"
echo "ok  check lists dex"
