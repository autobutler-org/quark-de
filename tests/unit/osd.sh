#!/bin/sh
# shellcheck disable=SC2016
set -eu

script="$(cd "$(dirname "$0")/../.." && pwd)/session/quark-de-osd"
readonly script
readonly notify='notify-send -a quark-de -u low -t 1500 -h string:x-canonical-private-synchronous:quark-de-osd'

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
ln -s "$(command -v awk)" "$tmp/bin/awk"

stub() {
	printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\n%s\n' "$1" "$tmp" "${2:-}" >"$tmp/bin/$1"
	chmod +x "$tmp/bin/$1"
}

stub_all() {
	stub wpctl 'case "$1 ${2:-}" in "get-volume @DEFAULT_AUDIO_SINK@") echo "Volume: 0.45" ;; "get-volume @DEFAULT_AUDIO_SOURCE@") echo "Volume: 1.00 [MUTED]" ;; esac'
	stub brightnessctl 'case "$*" in -m) echo "intel_backlight,backlight,400,40%,1000" ;; esac'
	stub playerctl
	stub notify-send
}

run() {
	: >"$tmp/calls"
	PATH="$tmp/bin" /bin/sh "$script" "$@" 2>"$tmp/stderr"
}

expect_call() {
	grep -qxF "$1" "$tmp/calls" || fail "quark-de-osd $2: expected '$1', got: $(cat "$tmp/calls")"
}

stub_all

run volume-up
expect_call 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+' volume-up
expect_call "$notify -h int:value:45 Volume 45%" volume-up

run volume-down
expect_call 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-' volume-down
expect_call "$notify -h int:value:45 Volume 45%" volume-down

run mute
expect_call 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' mute
expect_call "$notify -h int:value:45 Volume 45%" mute

run mic-mute
expect_call 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle' mic-mute
expect_call "$notify -h int:value:0 Microphone muted" mic-mute

stub wpctl 'case "$1" in get-volume) echo "Volume: 0.30 [MUTED]" ;; esac'
run mute
expect_call "$notify -h int:value:0 Volume muted" "mute (muted)"
stub_all

run brightness-up
expect_call 'brightnessctl -q set 5%+' brightness-up
expect_call "$notify -h int:value:40 Brightness 40%" brightness-up

run brightness-down
expect_call 'brightnessctl -q --min-value=1 set 5%-' brightness-down
expect_call "$notify -h int:value:40 Brightness 40%" brightness-down

for action in play-pause pause next previous; do
	run "$action"
	expect_call "playerctl $action" "$action"
done

rm "$tmp/bin/wpctl"
if run volume-up; then
	fail "quark-de-osd volume-up succeeded without wpctl"
fi
grep -q wpctl "$tmp/stderr" || fail "quark-de-osd volume-up without wpctl printed nothing naming wpctl"
grep -q '^notify-send .*wpctl' "$tmp/calls" || fail "quark-de-osd volume-up without wpctl did not notify the user"
stub_all

rm "$tmp/bin/notify-send"
run volume-up || fail "quark-de-osd volume-up failed without notify-send; the key should still change the volume"
expect_call 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+' "volume-up without notify-send"
stub_all

if run bogus; then
	fail "quark-de-osd accepted an unknown action"
fi

echo "ok  osd"
