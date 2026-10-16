#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

real_foot="$(command -v foot)"
readonly real_foot
printf '#!/bin/sh\nexec %s --app-id=org.autobutler.quark\n' "$real_foot" >"$tmp/shim/quark"
printf '#!/bin/sh\nsleep 1\nexec %s --app-id=firefox\n' "$real_foot" >"$tmp/shim/firefox"
printf '#!/bin/sh\nsleep 2\nexec %s "$@"\n' "$real_foot" >"$tmp/shim/foot"
chmod +x "$tmp/shim/foot"

sway_start
wait_for 15 views_up 3 || fail "the session did not map its three clients"

workspaces="$(swaymsg_ -t get_workspaces)"
echo "$workspaces" | jq -e '[.[] | select(.focused)] | length == 1' >/dev/null ||
	fail "expected exactly one focused workspace, got: $(echo "$workspaces" | jq -c '[.[] | select(.focused) | .name]')"
echo "$workspaces" | jq -e '.[] | select(.focused) | .name == "1:quark"' >/dev/null ||
	fail "the session started focused on $(echo "$workspaces" | jq -c '[.[] | select(.focused) | .name]'), not 1:quark; check that the first 'bindsym ... workspace' in config/sway/config is \$quark"
for ws in 2:browser 3:terminal; do
	echo "$workspaces" | jq -e --arg ws "$ws" 'any(.[]; .name == $ws and (.focused | not))' >/dev/null ||
		fail "workspace $ws is missing or focused: $(echo "$workspaces" | jq -c '[.[] | {name, focused}]')"
done
echo "ok  start workspace"
