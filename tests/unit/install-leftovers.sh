#!/bin/sh
# make install, an upgrade over an older install, and make uninstall leave no leftovers (#49).
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
readonly root="$tmp/root"
readonly fresh="$tmp/fresh"
readonly old="$tmp/old"
readonly stale='# stale line from an older quark-de install'

# The older release: HEAD~1 when history is available, else HEAD (a shallow CI checkout).
# Either way its config gets a stale line, so an upgrade that keeps the old config fails.
mkdir -p "$old"
if git -C "$repo" rev-parse -q --verify 'HEAD~1^{commit}' >/dev/null 2>&1; then
	git -C "$repo" archive HEAD~1 Makefile session config | tar -x -C "$old"
else
	cp -R "$repo/Makefile" "$repo/session" "$repo/config" "$old/"
fi
echo "$stale" >>"$old/config/sway/config"

# snapshot <dir>: every path under <dir>, relative and sorted.
snapshot() {
	find "$1" | sed "s|^$1||" | sort
}

# A system that already has the directories and another session the install shares.
mkdir -p "$root/usr/bin" "$root/usr/share/wayland-sessions" "$root/usr/share/xdg-desktop-portal"
: >"$root/usr/bin/sway"
: >"$root/usr/share/wayland-sessions/sway.desktop"
snapshot "$root" >"$tmp/before"

make -s -C "$old" install DESTDIR="$root" PREFIX=/usr >/dev/null
grep -qxF "$stale" "$root/usr/share/quark-de/sway/config" || fail "the older install did not install its config"
make -s -C "$repo" install DESTDIR="$root" PREFIX=/usr >/dev/null

# shellcheck disable=SC2016 # $share is sway's variable, matched literally.
sed 's|^set $share .*|set $share /usr/share/quark-de|' "$repo/config/sway/config" >"$tmp/expected-config"
cmp -s "$tmp/expected-config" "$root/usr/share/quark-de/sway/config" ||
	fail "the upgrade kept a stale config: $(diff "$tmp/expected-config" "$root/usr/share/quark-de/sway/config")"
grep -qx 'Exec=/usr/bin/quark-de' "$root/usr/share/wayland-sessions/quark-de.desktop" ||
	fail "the upgrade did not rewrite Exec=: $(grep '^Exec=' "$root/usr/share/wayland-sessions/quark-de.desktop")"

mkdir -p "$fresh/usr/bin" "$fresh/usr/share/wayland-sessions" "$fresh/usr/share/xdg-desktop-portal"
: >"$fresh/usr/bin/sway"
: >"$fresh/usr/share/wayland-sessions/sway.desktop"
make -s -C "$repo" install DESTDIR="$fresh" PREFIX=/usr >/dev/null
snapshot "$fresh" >"$tmp/fresh.list"
snapshot "$root" >"$tmp/upgraded.list"
cmp -s "$tmp/fresh.list" "$tmp/upgraded.list" ||
	fail "the upgrade left files a fresh install does not have: $(diff "$tmp/fresh.list" "$tmp/upgraded.list")"

make -s -C "$repo" uninstall DESTDIR="$root" PREFIX=/usr >/dev/null
snapshot "$root" >"$tmp/after"
cmp -s "$tmp/before" "$tmp/after" ||
	fail "make uninstall after an upgrade did not restore the tree: $(diff "$tmp/before" "$tmp/after")"

# The upgraded launcher finds its config: install where it runs, without DESTDIR.
readonly prefix="$tmp/prefix"
make -s -C "$old" install PREFIX="$prefix" WAYLAND_SESSIONS="$prefix/share/wayland-sessions" >/dev/null
make -s -C "$repo" install PREFIX="$prefix" WAYLAND_SESSIONS="$prefix/share/wayland-sessions" >/dev/null
"$prefix/bin/quark-de" --check >"$tmp/check.log" 2>&1 || :
grep -Eq '^(ok|missing) +sway( |$)' "$tmp/check.log" || fail "quark-de --check did not run its checks after the upgrade: $(cat "$tmp/check.log")"
if grep -q '^missing  /' "$tmp/check.log"; then
	fail "quark-de --check did not find the upgraded config: $(cat "$tmp/check.log")"
fi
make -s -C "$repo" uninstall PREFIX="$prefix" WAYLAND_SESSIONS="$prefix/share/wayland-sessions" >/dev/null
leftover="$(find "$prefix" ! -type d)"
[ -z "$leftover" ] || fail "make uninstall left files behind after the upgrade: $leftover"
echo "ok  install-leftovers"
