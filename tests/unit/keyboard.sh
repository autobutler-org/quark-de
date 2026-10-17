#!/bin/sh
set -eu

root="$(cd "$(dirname "$0")/../.." && pwd)"
readonly script="$root/session/quark-de-keyboard"
readonly fixtures="$root/tests/fixtures/keyboard"
tmp="$(mktemp -d)"
readonly tmp
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: keyboard: $*" >&2
	echo "--- swaymsg calls:" >&2
	cat "$tmp/calls" >&2 2>/dev/null || :
	exit 1
}

reset() {
	rm -rf "${tmp:?}/bin" "${tmp:?}/calls"
	mkdir -p "$tmp/bin"
	: >"$tmp/calls"
	for tool in sed grep tail cat; do
		ln -s "$(command -v "$tool")" "$tmp/bin/$tool"
	done
	cat >"$tmp/bin/swaymsg" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >>"$tmp/calls"
exit "\${STUB_SWAYMSG_EXIT:-0}"
STUB
	chmod +x "$tmp/bin/swaymsg"
}

stub_localectl() {
	printf '#!/bin/sh\ncat "%s"\n' "$1" >"$tmp/bin/localectl"
	chmod +x "$tmp/bin/localectl"
}

run() {
	env -i PATH="$tmp/bin" "$@" /bin/sh "$script" "$file" 2>"$tmp/stderr"
}

expect_calls() {
	printf '%s\n' "$@" >"$tmp/expected"
	diff -u "$tmp/expected" "$tmp/calls" >&2 || fail "$label: unexpected swaymsg calls"
}

reset
stub_localectl "$fixtures/localectl-status"
label="/etc/default/keyboard"
file="$fixtures/default-keyboard"
run || fail "$label: exited non-zero"
expect_calls \
	'input type:keyboard xkb_model "pc105"' \
	'input type:keyboard xkb_layout "de,us"' \
	'input type:keyboard xkb_variant "nodeadkeys,"' \
	'input type:keyboard xkb_options "grp:alt_shift_toggle,ctrl:nocaps"'

reset
stub_localectl "$fixtures/localectl-status"
label="empty /etc/default/keyboard"
file="$fixtures/default-keyboard-unset"
run || fail "$label: exited non-zero"
[ -s "$tmp/calls" ] && fail "$label: changed sway's default layout though nothing is configured"

reset
stub_localectl "$fixtures/localectl-status"
label="localectl fallback"
file="$tmp/missing"
run || fail "$label: exited non-zero"
expect_calls \
	'input type:keyboard xkb_layout "fr"' \
	'input type:keyboard xkb_variant "azerty"'

reset
label="no file and no localectl"
file="$tmp/missing"
run || fail "$label: exited non-zero"
[ -s "$tmp/calls" ] && fail "$label: changed sway's default layout though nothing is configured"

reset
label="rejected layout"
file="$fixtures/default-keyboard"
run STUB_SWAYMSG_EXIT=1 && fail "$label: exited zero though sway rejected the layout"
grep -q 'localectl set-x11-keymap' "$tmp/stderr" || fail "$label: did not say how to fix the layout: $(cat "$tmp/stderr")"

echo "ok  keyboard"
