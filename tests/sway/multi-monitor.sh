#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

workspaces_on() {
	swaymsg_ -t get_workspaces | jq -e --arg out "$1" '[.[] | select(.output == $out) | .name] | contains(["1:quark", "2:browser", "3:terminal"])' >/dev/null
}

harness_setup
mkdir -p "$tmp/config/quark-de/sway"
echo "set \$primary HEADLESS-3 HEADLESS-2" >"$tmp/config/quark-de/sway/outputs"
WLR_HEADLESS_OUTPUTS=2
export WLR_HEADLESS_OUTPUTS
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

wait_for 5 quark_shown_on HEADLESS-2 ||
	fail "Quark is not fullscreen and visible on the primary output HEADLESS-2: $(output_layout)"
workspaces_on HEADLESS-2 || fail "the browser and terminal workspaces are not on the primary output: $(output_layout)"

swaymsg_ output HEADLESS-2 unplug >/dev/null
wait_for 5 quark_shown_on HEADLESS-1 ||
	fail "after unplugging HEADLESS-2, Quark is not fullscreen and visible on HEADLESS-1: $(output_layout)"
workspaces_on HEADLESS-1 || fail "the workspaces did not follow Quark to HEADLESS-1: $(output_layout)"

swaymsg_ create_output >/dev/null
wait_for 5 quark_shown_on HEADLESS-3 ||
	fail "after plugging in the preferred output HEADLESS-3, Quark is not fullscreen and visible on it: $(output_layout)"
workspaces_on HEADLESS-3 || fail "the workspaces did not follow Quark to HEADLESS-3: $(output_layout)"
echo "ok  multi monitor"
