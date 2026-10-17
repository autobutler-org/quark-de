#!/bin/sh
# quark-de-ctl's verbs through the socket Quark is handed: each allowlisted verb does its one job.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub firefox "printf '%s\\n' \"\$*\" >>'$tmp/firefox.args'; exec foot --app-id=firefox"
stub swaylock ": >'$tmp/swaylock.ran'"
stub quark-de-logout "printf '%s\\n' \"\${1:-logout}\" >>'$tmp/logout.args'"
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

quark_pid="$(swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "org.autobutler.quark") | .pid')"
quark_sock="$(tr '\0' '\n' <"/proc/$quark_pid/environ" | sed -n 's/^SWAYSOCK=//p')"
readonly quark_sock
[ -S "$quark_sock" ] && [ "$quark_sock" != "$SWAYSOCK" ] || fail "quark is not handed its own IPC socket (SWAYSOCK='$quark_sock')"

# quark_ctl <args>: run the CLI the way Quark would, with Quark's environment.
quark_ctl() {
	sway_env SWAYSOCK="$quark_sock" QUARK_DE_CTL="$quark_sock" "$tmp/usr/bin/quark-de-ctl" "$@"
}

file_has() {
	[ -e "$1" ] && grep -qxF "$2" "$1"
}

app_kill foot
wait_for 10 app_views_is foot 0 || fail "foot did not exit"
swaymsg -s "$quark_sock" launch terminal >/dev/null || fail "'launch terminal' over quark's socket was rejected"
wait_for 10 app_views_is foot 1 || fail "'launch terminal' did not start foot"
wait_for 5 app_on_workspace foot 3:terminal || fail "'launch terminal' did not put foot on 3:terminal"
[ "$(focused_workspace)" = 3:terminal ] || fail "'launch terminal' left $(focused_workspace) focused"
quark_ctl launch terminal || fail "'quark-de-ctl launch terminal' from quark failed"
sleep 1
app_views_is foot 1 || fail "'launch terminal' with foot running started a second one"

readonly url='https://example.org/a?b=1&c=two#frag'
quark_ctl workspace 1:quark || fail "'quark-de-ctl workspace 1:quark' from quark failed"
quark_ctl open-url "$url" || fail "'quark-de-ctl open-url' from quark failed"
wait_for 10 file_has "$tmp/firefox.args" "$url" || fail "open-url did not hand the browser the URL: $(cat "$tmp/firefox.args" 2>/dev/null)"
[ "$(focused_workspace)" = 2:browser ] || fail "open-url left $(focused_workspace) focused, not 2:browser"

quark_ctl lock || fail "'quark-de-ctl lock' failed"
wait_for 5 test -e "$tmp/swaylock.ran" || fail "lock did not start swaylock"
quark_ctl logout || fail "'quark-de-ctl logout' failed"
quark_ctl poweroff || fail "'quark-de-ctl poweroff' failed"
wait_for 5 file_has "$tmp/logout.args" poweroff || fail "poweroff did not run quark-de-logout poweroff"
file_has "$tmp/logout.args" logout || fail "logout did not run quark-de-logout"

for args in "launch xterm" "open-url javascript:alert(1)" "open-url" "workspace 4:other" "lock now" "exec foot" "reboot"; do
	# shellcheck disable=SC2086
	if quark_ctl $args 2>"$tmp/err"; then
		fail "'quark-de-ctl $args' was accepted"
	fi
	grep -q . "$tmp/err" || fail "'quark-de-ctl $args' was rejected without saying why"
done
if swaymsg -s "$quark_sock" "open-url https://example.org/; exec foot" >/dev/null 2>&1; then
	fail "quark's socket accepted a chained open-url"
fi
sleep 1
app_views_is foot 1 || fail "a rejected verb started foot"

out="$(env -u SWAYSOCK -u QUARK_DE_CTL PATH="$tmp/shim:$tmp/usr/bin:$PATH" "$tmp/usr/bin/quark-de-ctl" launch terminal 2>&1)" ||
	fail "quark-de-ctl outside quark-de failed instead of doing nothing: $out"
sleep 1
app_views_is foot 1 || fail "quark-de-ctl outside quark-de launched an app"
echo "ok  quark-de-ctl verbs work from quark and reject everything else"
