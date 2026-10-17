#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
make -s -C "$repo" install PREFIX="$tmp/usr" WAYLAND_SESSIONS="$tmp/wayland-sessions" >/dev/null
for tool in dirname ls id; do
	ln -s "$(command -v "$tool")" "$tmp/shim/$tool"
done
stub quark
stub sway "echo \"\$*\" >'$tmp/sway.ran'"
mkdir -m 700 "$tmp/run"
mkdir -p "$tmp/home/.local/bin"
ln -s "$tmp/usr/bin/quark-de" "$tmp/home/.local/bin/quark-de"
readonly want="--config $tmp/usr/share/quark-de/sway/config"

for how in symlink sh; do
	rm -f "$tmp/sway.ran"
	if [ "$how" = symlink ]; then
		set -- "$tmp/home/.local/bin/quark-de"
	else
		set -- /bin/sh "$tmp/home/.local/bin/quark-de"
	fi
	env -i HOME="$tmp/home" PATH="$tmp/shim" XDG_RUNTIME_DIR="$tmp/run" XDG_STATE_HOME="$tmp/state" "$@" >"$tmp/out" 2>&1 ||
		fail "quark-de started via $how failed: $(cat "$tmp/out")"
	[ "$(cat "$tmp/sway.ran" 2>/dev/null)" = "$want" ] ||
		fail "quark-de started via $how did not find the installed config: $(cat "$tmp/sway.ran" 2>/dev/null) $(cat "$tmp/out")"
done
echo "ok  launcher finds its config through a symlink"
