#!/bin/sh
set -eu

script="$(cd "$(dirname "$0")/../.." && pwd)/session/quark-de-autostart"
readonly script
tmp="$(mktemp -d)"
readonly tmp
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: autostart: $*" >&2
	echo "--- calls:" >&2
	cat "$tmp/calls" >&2 2>/dev/null || :
	exit 1
}

stub() {
	printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\n%s\n' "$1" "$tmp" "$2" >"$tmp/bin/$1"
	chmod +x "$tmp/bin/$1"
}

stub_systemd() {
	# shellcheck disable=SC2016
	stub systemctl 'case "$2" in
cat) exit 0 ;;
start) exit "${STUB_START_EXIT:-0}" ;;
list-units) [ -n "${STUB_FAILED:-}" ] && echo "$STUB_FAILED loaded failed failed Stub app" ;;
esac
exit 0'
}

stub_no_systemd() {
	# shellcheck disable=SC2016
	stub systemctl 'echo "Failed to connect to bus" >&2; exit 1'
}

reset() {
	rm -rf "${tmp:?}/bin" "${tmp:?}/home" "${tmp:?}/calls"
	mkdir -p "$tmp/bin" "$tmp/home"
	: >"$tmp/calls"
	stub notify-send 'exit 0'
}

run() {
	env -i PATH="$tmp/bin" HOME="$tmp/home" "$@" /bin/sh "$script" 2>"$tmp/stderr"
}

called() {
	grep -qxF "$1" "$tmp/calls"
}

notified() {
	grep -q '^notify-send ' "$tmp/calls"
}

reset
stub_systemd
stub dex 'exit 0'
run XDG_CURRENT_DESKTOP=Quark:sway WAYLAND_DISPLAY=wayland-1 || fail "systemd path exited non-zero"
called "systemctl --user import-environment XDG_CURRENT_DESKTOP WAYLAND_DISPLAY" ||
	fail "systemd path did not import XDG_CURRENT_DESKTOP and WAYLAND_DISPLAY into the user manager"
called "systemctl --user start xdg-desktop-autostart.target" || fail "systemd path did not start xdg-desktop-autostart.target"
grep -q '^dex ' "$tmp/calls" && fail "systemd path also ran dex, which would start every app twice"
notified && fail "systemd path notified on success"

reset
stub_systemd
run STUB_START_EXIT=1 XDG_CURRENT_DESKTOP=Quark:sway && fail "a failed target start exited zero"
notified || fail "a failed target start did not notify"

reset
stub_systemd
run STUB_FAILED=app-nextcloud@autostart.service XDG_CURRENT_DESKTOP=Quark:sway && fail "a failed autostart unit exited zero"
grep -q '^notify-send .*app-nextcloud@autostart.service' "$tmp/calls" || fail "a failed autostart unit was not named in a notification"

reset
stub_no_systemd
stub dex 'exit 0'
run XDG_CURRENT_DESKTOP=Quark:sway || fail "dex fallback exited non-zero"
called "dex -a -e Quark" || fail "dex fallback did not run 'dex -a -e Quark' for XDG_CURRENT_DESKTOP=Quark:sway"
notified && fail "dex fallback notified on success"

reset
stub_no_systemd
stub dex 'exit 0'
run || fail "dex fallback without XDG_CURRENT_DESKTOP exited non-zero"
called "dex -a" || fail "dex fallback without XDG_CURRENT_DESKTOP did not run plain 'dex -a'"

reset
stub_no_systemd
stub dex 'exit 1'
run XDG_CURRENT_DESKTOP=Quark:sway && fail "a failed dex run exited zero"
notified || fail "a failed dex run did not notify"

reset
stub_no_systemd
run XDG_CURRENT_DESKTOP=Quark:sway || fail "no autostart tool and no user entries exited non-zero"
notified && fail "no autostart tool and no user entries notified"

reset
stub_no_systemd
mkdir -p "$tmp/home/.config/autostart"
: >"$tmp/home/.config/autostart/app.desktop"
run XDG_CURRENT_DESKTOP=Quark:sway && fail "user entries with no autostart tool exited zero"
grep -q '^notify-send .*dex' "$tmp/calls" || fail "user entries with no autostart tool did not notify how to install dex"

echo "ok  autostart"
