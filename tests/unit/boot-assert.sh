#!/bin/sh
# tests/boot/assert.sh judges what the nightly QEMU boot collected; check each failure it must catch.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"
unit_setup

readonly assert="$repo/tests/boot/assert.sh"

# tree <workspace> <fullscreen_mode> <focused>: a sway tree holding one org.autobutler.quark view.
tree() {
	cat <<JSON
{"type":"root","nodes":[{"type":"output","name":"Virtual-1","nodes":[
 {"type":"workspace","name":"$1","nodes":[{"type":"con","app_id":"org.autobutler.quark","fullscreen_mode":$2,"focused":$3,"nodes":[]}]},
 {"type":"workspace","name":"3:terminal","nodes":[{"type":"con","app_id":"foot","fullscreen_mode":0,"focused":false,"nodes":[]}]}]}]}
JSON
}

# ppm <lit-pixels> <total-pixels>: a P6 image with that many white pixels, the rest black.
ppm() {
	printf 'P6\n%s 1\n255\n' "$2"
	i=0
	while [ "$i" -lt "$2" ]; do
		if [ "$i" -lt "$1" ]; then printf '\377\377\377'; else printf '\0\0\0'; fi
		i=$((i + 1))
	done
}

# good <dir>: artifacts from a healthy boot.
good() {
	mkdir -p "$1"
	tree 1:quark 1 true >"$1/tree.json"
	ppm 10 200 >"$1/shot.ppm"
	echo 'sway[812]: [sway/config.c:899] Running deferred commands' >"$1/journal.txt"
}

expect_fail() {
	if out="$(sh "$assert" "$1" 2>&1)"; then
		fail "assert.sh passed $2; output: $out"
	fi
	printf '%s\n' "$out" | grep -q -- "$3" || fail "assert.sh did not say '$3' for $2; output: $out"
}

good "$tmp/ok"
out="$(sh "$assert" "$tmp/ok" 2>&1)" || fail "assert.sh failed a healthy boot: $out"

good "$tmp/timeout"
rm "$tmp/timeout/tree.json"
expect_fail "$tmp/timeout" "a boot with no session" "no sway session"

good "$tmp/missing"
sed 's/org.autobutler.quark/com.example.other/' "$tmp/ok/tree.json" >"$tmp/missing/tree.json"
expect_fail "$tmp/missing" "a tree without Quark" "com.example.other on 1:quark"

good "$tmp/workspace"
tree 2:browser 1 true >"$tmp/workspace/tree.json"
expect_fail "$tmp/workspace" "Quark on the wrong workspace" "org.autobutler.quark on 2:browser"

good "$tmp/windowed"
tree 1:quark 0 true >"$tmp/windowed/tree.json"
expect_fail "$tmp/windowed" "a windowed Quark" "fullscreen=0"

good "$tmp/unfocused"
tree 1:quark 1 false >"$tmp/unfocused/tree.json"
expect_fail "$tmp/unfocused" "an unfocused Quark" "focused=false"

good "$tmp/black"
ppm 0 200 >"$tmp/black/shot.ppm"
expect_fail "$tmp/black" "an all-black screenshot" "0 of 200 pixels"

good "$tmp/dim"
ppm 2 200 >"$tmp/dim/shot.ppm"
expect_fail "$tmp/dim" "a screenshot with 1% lit pixels" "2 of 200 pixels"

good "$tmp/noshot"
rm "$tmp/noshot/shot.ppm"
expect_fail "$tmp/noshot" "a boot with no screenshot" "no screenshot"

good "$tmp/journal"
echo 'sway[812]: [sway/config.c:801] Error on line 42 (/usr/local/share/quark-de/sway/config)' >>"$tmp/journal/journal.txt"
expect_fail "$tmp/journal" "a journal with a sway config error" "Error on line 42"

echo "ok  boot assertions"
