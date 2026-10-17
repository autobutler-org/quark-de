#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

quark_output() {
	swaymsg_ -t get_workspaces | jq -r '.[] | select(.name == "1:quark") | .output'
}

harness_setup
WLR_HEADLESS_OUTPUTS=2
export WLR_HEADLESS_OUTPUTS
sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

shown="$(quark_output)"
wait_for 5 quark_shown_on "$shown" ||
	fail "with no primary output connected, Quark is not fullscreen and visible: $(output_layout)"
case "$shown" in
HEADLESS-1) other=HEADLESS-2 ;;
*) other=HEADLESS-1 ;;
esac

swaymsg_ output "$shown" unplug >/dev/null
wait_for 5 quark_shown_on "$other" ||
	fail "after unplugging $shown, Quark is not fullscreen and visible on $other: $(output_layout)"
echo "ok  multi monitor fallback"
