#!/bin/sh
# @pending #17: Quark has no IPC guard yet, so it holds the raw sway socket and this test fails.
# Delete the skip below when the guard lands. QUARK_DE_PENDING=1 runs it now.
#
# Quark's IPC path is the SWAYSOCK in Quark's environment. The guard (a restricted socket or an
# allowlisting proxy) puts its own socket there. Known limit: other processes running as the same
# user can still reach the raw sway socket; this test covers only what Quark is handed.
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

if [ "${QUARK_DE_PENDING:-}" != 1 ]; then
	echo "skip ipc guard blocks arbitrary sway commands (@pending #17; QUARK_DE_PENDING=1 runs it)"
	exit 0
fi

harness_setup
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

quark_pid="$(swaymsg_ -t get_tree | jq -r '.. | objects | select(.app_id? == "org.autobutler.quark") | .pid')"
[ -n "$quark_pid" ] || fail "no quark window to inspect"
quark_sock="$(tr '\0' '\n' <"/proc/$quark_pid/environ" | sed -n 's/^SWAYSOCK=//p')"
readonly quark_sock
[ -S "$quark_sock" ] || fail "quark has no IPC socket in its environment (SWAYSOCK='$quark_sock')"

marker="$tmp/pwned"
readonly marker

quark_msg() {
	swaymsg -s "$quark_sock" "$@"
}

sway_env swaymsg -s "$SWAYSOCK" -m -t subscribe '["workspace","shutdown"]' >"$tmp/events" 2>&1 &
modes_before="$(swaymsg_ -t get_binding_modes)"
config_before="$(swaymsg_ -t get_config)"
outputs_before="$(swaymsg_ -t get_outputs | jq -c '[.[] | {name, active}]')"

for ws in 2:browser 3:terminal 1:quark; do
	quark_msg "workspace $ws" >/dev/null || fail "the allowlisted 'workspace $ws' was rejected"
	[ "$(focused_workspace)" = "$ws" ] || fail "'workspace $ws' through quark's socket left $(focused_workspace) focused"
done
quark_msg -t get_workspaces | jq -e 'length >= 3' >/dev/null || fail "the allowlisted get_workspaces query was rejected"

for cmd in \
	"exec touch $marker" \
	"exit" \
	"reload" \
	"output * disable" \
	"bindsym Mod4+1 exec touch $marker" \
	"workspace 2:browser; exec touch $marker" \
	"workspace 2:browser, exec touch $marker"; do
	if quark_msg "$cmd" >"$tmp/reply" 2>&1; then
		fail "quark's socket accepted '$cmd': $(cat "$tmp/reply")"
	fi
	if wait_for 1 test -e "$marker"; then
		fail "'$cmd' through quark's socket ran a command"
	fi
	kill -0 "$sway_pid" 2>/dev/null || fail "sway exited after '$cmd'"
	[ "$(focused_workspace)" = 1:quark ] || fail "'$cmd' through quark's socket moved focus to $(focused_workspace)"
done

[ "$(swaymsg_ -t get_outputs | jq -c '[.[] | {name, active}]')" = "$outputs_before" ] || fail "an output changed state"
[ "$(swaymsg_ -t get_binding_modes)" = "$modes_before" ] || fail "the binding modes changed"
[ "$(swaymsg_ -t get_config)" = "$config_before" ] || fail "the loaded config changed"
if grep -Eq '"change": *"(reload|exit)"' "$tmp/events"; then
	fail "sway reloaded or began exiting: $(cat "$tmp/events")"
fi
echo "ok  ipc guard blocks arbitrary sway commands from quark"
