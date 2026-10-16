#!/bin/sh
set -eu

script="$(cd "$(dirname "$0")/../.." && pwd)/session/quark-de-screenshot"
readonly script

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stubs="$tmp/stubs"
log="$tmp/log"
mkdir -p "$stubs" "$tmp/home"

stub() {
	{
		echo '#!/bin/sh'
		cat
	} >"$stubs/$1"
	chmod +x "$stubs/$1"
}

stub grim <<'STUB'
echo "grim $*" >>"$STUB_LOG"
for a; do f="$a"; done
printf png >"$f"
STUB
stub slurp <<'STUB'
echo "slurp $*" >>"$STUB_LOG"
[ -z "${STUB_SLURP_CANCEL:-}" ] || exit 1
echo "10,20 300x200"
STUB
stub wl-copy <<'STUB'
echo "wl-copy $*" >>"$STUB_LOG"
cat >"$STUB_CLIP"
STUB
stub notify-send <<'STUB'
echo "notify-send $*" >>"$STUB_LOG"
STUB
stub swaymsg <<'STUB'
echo "swaymsg $*" >>"$STUB_LOG"
cat <<JSON
{"type":"root","focused":false,"rect":{"x":0,"y":0,"width":1920,"height":1080},"nodes":[
 {"type":"output","focused":false,"rect":{"x":0,"y":0,"width":1920,"height":1080},"nodes":[
  {"type":"workspace","focused":false,"rect":{"x":0,"y":0,"width":1920,"height":1080},"nodes":[
   {"type":"con","app_id":"foot","focused":false,"rect":{"x":0,"y":0,"width":960,"height":1080},"nodes":[]},
   {"type":"con","app_id":"firefox","focused":true,"rect":{"x":960,"y":0,"width":960,"height":1080},"nodes":[]}
  ]}
 ]}
]}
JSON
STUB
stub xdg-user-dir <<'STUB'
echo "${STUB_PICTURES:-$HOME}"
STUB

shoot() {
	: >"$log"
	rm -f "$tmp/clip"
	env PATH="$stubs:$PATH" HOME="$tmp/home" STUB_LOG="$log" STUB_CLIP="$tmp/clip" "$@"
}

expect_log() {
	grep -qxF "$1" "$log" || fail "$2: expected '$1' in the calls, got: $(cat "$log")"
}

expect_shot() {
	mode="$1"
	dir="$2"
	file="$3"
	case "$file" in
	"$dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9].png) ;;
	*) fail "$mode: saved to '$file', expected $dir/<YYYY-MM-DD_HH-MM-SS>.png" ;;
	esac
	[ -s "$file" ] || fail "$mode: $file was not written"
	expect_log "wl-copy --type image/png" "$mode"
	cmp -s "$file" "$tmp/clip" || fail "$mode: the clipboard did not get the screenshot"
	expect_log "notify-send Screenshot saved $file" "$mode"
}

shots="$tmp/home/Pictures/Screenshots"

file="$(shoot STUB_PICTURES= sh "$script" full)"
expect_log "grim $file" full
expect_shot full "$shots" "$file"

file="$(shoot sh "$script" region)"
expect_log "slurp " region
expect_log "grim -g 10,20 300x200 $file" region
expect_shot region "$shots" "$file"

file="$(shoot sh "$script" window)"
expect_log "swaymsg -t get_tree" window
expect_log "grim -g 960,0 960x1080 $file" window
expect_shot window "$shots" "$file"

file="$(shoot STUB_PICTURES="$tmp/home/Bilder" sh "$script" full)"
expect_shot "full with XDG Pictures set" "$tmp/home/Bilder/Screenshots" "$file"

shoot STUB_SLURP_CANCEL=1 sh "$script" region >/dev/null || fail "region: canceling the selection should exit 0"
if grep -q '^grim' "$log"; then
	fail "region: canceling the selection should not take a screenshot"
fi

if shoot sh "$script" bogus >/dev/null 2>&1; then
	fail "an unknown mode should exit non-zero"
fi

echo "ok  screenshot modes"
