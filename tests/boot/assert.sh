#!/bin/sh
# Usage: assert.sh <dir>
# Judge what tests/boot/run.sh collected from a booted VM: tree.json (swaymsg -t get_tree),
# shot.ppm (grim -t ppm) and journal.txt (journalctl -b). Prints every failure, exits 1 if any.
set -eu

readonly dir="${1:?usage: assert.sh <dir with tree.json, shot.ppm and journal.txt>}"
readonly quark=org.autobutler.quark
failed=0

bad() {
	echo "FAIL: $*" >&2
	failed=1
}

# lit_pixels <ppm>: "<pixels with any nonzero channel> <total pixels>" for a binary (P6) PPM.
lit_pixels() {
	od -An -v -tu1 "$1" | awk '
		BEGIN { field = 0; tok = ""; data = 0; ch = 0; lit = 0; px = 0 }
		{
			for (i = 1; i <= NF; i++) {
				b = $i + 0
				if (data) {
					if (b > 0) any = 1
					if (++ch == 3) { px++; if (any) lit++; ch = 0; any = 0 }
					continue
				}
				if (b == 9 || b == 10 || b == 13 || b == 32) {
					if (tok != "") { hdr[field++] = tok; tok = "" }
					if (field == 4) data = 1
				} else {
					tok = tok sprintf("%c", b)
				}
			}
		}
		END {
			if (hdr[0] != "P6" || px != hdr[1] * hdr[2]) { print "bad"; exit }
			print lit, px
		}'
}

if [ ! -s "$dir/tree.json" ]; then
	bad "no sway session came up (no tree.json); see journal.txt and serial.log"
else
	jq -r --arg id "$quark" '
		[.. | objects | select(.type? == "workspace") | .name as $ws
		| .. | objects | select(.app_id? != null)
		| "\(.app_id) on \($ws) fullscreen=\(.fullscreen_mode) focused=\(.focused)"] | .[]' "$dir/tree.json" >"$dir/views.txt"
	if ! grep -qx "$quark on 1:quark fullscreen=1 focused=true" "$dir/views.txt"; then
		bad "expected $quark on 1:quark, fullscreen and focused; views:"
		sed 's/^/  /' "$dir/views.txt" >&2
	fi
fi

if [ ! -s "$dir/shot.ppm" ]; then
	bad "no screenshot (shot.ppm); grim failed or the session never came up"
else
	# shellcheck disable=SC2046
	set -- $(lit_pixels "$dir/shot.ppm")
	if [ "$1" = bad ]; then
		bad "shot.ppm is not a binary PPM that grim -t ppm writes"
	elif [ $(($1 * 100)) -le "$2" ]; then
		bad "the screen is black: $1 of $2 pixels are not black (need more than 1%)"
	fi
fi

if [ -e "$dir/journal.txt" ] && grep 'Error on line' "$dir/journal.txt" >"$dir/journal-errors.txt"; then
	bad "sway reported config errors in the journal:"
	sed 's/^/  /' "$dir/journal-errors.txt" >&2
fi

[ "$failed" = 0 ] && echo "ok  quark is fullscreen and focused on 1:quark, the screen is lit, the journal has no sway config errors"
exit "$failed"
