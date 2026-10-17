#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

doctor() {
	env -i HOME="$tmp/home" PATH="$bin" /bin/sh "$tmp/usr/bin/quark-de" --check >"$tmp/out.log" 2>&1
}

unit_setup
make -s -C "$repo" install PREFIX="$tmp/usr" WAYLAND_SESSIONS="$tmp/wayland-sessions" >/dev/null

stub_bin sway quark foot firefox-esr swayidle swaylock logger
doctor || fail "quark-de --check failed with firefox-esr in place of firefox: $(cat "$tmp/out.log")"
grep -q '^ok       firefox-esr$' "$tmp/out.log" || fail "quark-de --check did not list firefox-esr: $(cat "$tmp/out.log")"

run_session XDG_STATE_HOME="$tmp/state" || fail "quark-de failed with only firefox-esr: $(cat "$tmp/out.log")"
if grep -qs firefox "$tmp/logger.calls"; then
	fail "the launcher warned about the browser with firefox-esr installed: $(cat "$tmp/logger.calls")"
fi

env -i PATH="$bin" /bin/sh "$tmp/usr/bin/quark-de-browser" --new-window
grep -qx -- --new-window "$tmp/firefox-esr.calls" || fail "quark-de-browser did not start firefox-esr when firefox is missing"
printf '#!/bin/sh\n: >"%s/firefox.calls"\n' "$tmp" >"$bin/firefox"
chmod +x "$bin/firefox"
env -i PATH="$bin" /bin/sh "$tmp/usr/bin/quark-de-browser"
[ -e "$tmp/firefox.calls" ] || fail "quark-de-browser did not prefer firefox when both are installed"

rm "$bin/firefox" "$bin/firefox-esr"
if doctor; then
	fail "quark-de --check passed with no browser"
fi
grep -q '^missing  firefox — sudo apt install firefox' "$tmp/out.log" ||
	fail "quark-de --check did not report the missing browser: $(cat "$tmp/out.log")"
echo "ok  firefox-esr satisfies the browser check"
