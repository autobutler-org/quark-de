#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

readonly primary=HEADLESS-2
readonly other=HEADLESS-1

harness_setup
mkdir -p "$tmp/config/quark-de/sway"
echo "set \$primary $primary" >"$tmp/config/quark-de/sway/outputs"
WLR_HEADLESS_OUTPUTS=2
export WLR_HEADLESS_OUTPUTS
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"
wait_for 5 quark_shown_on "$primary" ||
	fail "Quark is not fullscreen and visible on the primary output $primary: $(output_layout)"

workspaces="$(swaymsg_ -t get_workspaces)"
echo "$workspaces" | jq -e --arg out "$primary" '[.[] | select(.focused)] | length == 1 and .[0].name == "1:quark" and .[0].output == $out' >/dev/null ||
	fail "the session did not start focused on 1:quark on $primary: $(echo "$workspaces" | jq -c '[.[] | {name, output, focused}]')"
app_views_is org.autobutler.quark 1 || fail "expected exactly one Quark view: $(output_layout)"
swaymsg_ -t get_tree | jq -e --arg out "$other" '
	[.. | objects | select(.type? == "output" and .name == $out) | .. | objects | select(.pid? != null and (.fullscreen_mode == 1 or .app_id == "org.autobutler.quark"))]
	| length == 0' >/dev/null ||
	fail "the secondary output $other shows Quark or a fullscreen view: $(output_layout)"
echo "ok  primary output"
