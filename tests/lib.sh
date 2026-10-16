#!/bin/sh

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

harness_setup() {
	tmp="$(mktemp -d)"
	repo="$(cd "$(dirname "$0")/../.." && pwd)"
	make -s -C "$repo" install PREFIX="$tmp/usr" WAYLAND_SESSIONS="$tmp/wayland-sessions" >/dev/null
	config="$tmp/usr/share/quark-de/sway/config"
	runtime="$tmp/run"
	mkdir -p "$runtime" "$tmp/shim"
	chmod 700 "$runtime"
	stub quark 'exec foot --app-id=org.autobutler.quark'
	stub firefox 'exec foot --app-id=firefox'
	stub swaynag "printf '%s\\n' \"\$@\" >>\"$tmp/swaynag.args\""
	stub quark-de-autostart ": >'$tmp/autostart.ran'"
	trap harness_teardown EXIT
}

unit_setup() {
	tmp="$(mktemp -d)"
	repo="$(cd "$(dirname "$0")/../.." && pwd)"
	mkdir -p "$tmp/shim"
	trap 'rm -rf "$tmp"' EXIT
}

stub() {
	printf '#!/bin/sh\n%s\n' "${2:-}" >"$tmp/shim/$1"
	chmod +x "$tmp/shim/$1"
}

harness_teardown() {
	if [ -n "${sway_pid:-}" ]; then
		pkill -TERM -P "$sway_pid" 2>/dev/null || :
		kill "$sway_pid" 2>/dev/null || :
		wait "$sway_pid" 2>/dev/null || :
	fi
	if [ -n "${dbus_pid:-}" ]; then
		kill "$dbus_pid" 2>/dev/null || :
	fi
	rm -rf "$tmp"
}

dbus_start() {
	dbus_pid="$(dbus-daemon --session --fork --nopidfile --print-pid --address="unix:path=$runtime/bus")"
	DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
	export DBUS_SESSION_BUS_ADDRESS
}

sway_env() {
	env PATH="$tmp/shim:$tmp/usr/bin:$PATH" \
		WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
		XDG_RUNTIME_DIR="$runtime" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" "$@"
}

sway_start() {
	sway_env sway --config "$config" >"$tmp/sway.log" 2>&1 &
	sway_pid=$!
	wait_for 10 sway_socket_ready || fail "sway did not start; log: $(cat "$tmp/sway.log")"
}

sway_socket_ready() {
	for sock in "$runtime"/sway-ipc.*.sock; do
		[ -S "$sock" ] && SWAYSOCK="$sock" && export SWAYSOCK && return 0
	done
	return 1
}

swaymsg_() {
	swaymsg -s "$SWAYSOCK" "$@"
}

wait_for() {
	deadline=$(($(date +%s) + $1))
	shift
	until "$@"; do
		[ "$(date +%s)" -ge "$deadline" ] && return 1
		sleep 0.2
	done
}

views_up() {
	[ "$(swaymsg_ -t get_tree | jq '[.. | objects | select(.app_id? != null)] | length')" -ge "$1" ]
}

app_views_is() {
	[ "$(swaymsg_ -t get_tree | jq --arg id "$1" '[.. | objects | select(.app_id? == $id)] | length')" -eq "$2" ]
}

app_on_workspace() {
	swaymsg_ -t get_tree | jq -e --arg id "$1" --arg ws "$2" \
		'[.. | objects | select(.type? == "workspace" and .name == $ws) | .. | objects | select(.app_id? == $id)] | length > 0' >/dev/null
}

app_kill() {
	swaymsg_ -t get_tree | jq -r --arg id "$1" '.. | objects | select(.app_id? == $id) | .pid' | xargs kill
}

binding_run() {
	swaymsg_ "$(sed -n "s/^bindsym \$mod+$1 //p" "$config")" >/dev/null
}

focused_workspace() {
	swaymsg_ -t get_workspaces | jq -r '.[] | select(.focused) | .name'
}

stub_bin() {
	bin="$tmp/bin"
	mkdir -p "$bin"
	for tool in dirname mkdir date; do
		ln -s "$(command -v "$tool")" "$bin/$tool"
	done
	for name in "$@"; do
		printf '#!/bin/sh\necho "$*" >>"%s/%s.calls"\n' "$tmp" "$name" >"$bin/$name"
		chmod +x "$bin/$name"
	done
}

run_session() {
	env -i HOME="$tmp/home" PATH="$bin" "$@" /bin/sh "$tmp/usr/bin/quark-de" >"$tmp/out.log" 2>&1
}
