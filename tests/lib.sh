#!/bin/sh

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

harness_setup() {
	tmp="$(mktemp -d)"
	repo="$(cd "$(dirname "$0")/../.." && pwd)"
	make -s -C "$repo" install DESTDIR="$tmp" PREFIX=/usr >/dev/null
	config="$tmp/usr/share/quark-de/sway/config"
	runtime="$tmp/run"
	mkdir -p "$runtime" "$tmp/shim"
	chmod 700 "$runtime"
	printf '#!/bin/sh\nexec foot --app-id=org.autobutler.quark\n' >"$tmp/shim/quark"
	printf '#!/bin/sh\nexec foot --app-id=firefox\n' >"$tmp/shim/firefox"
	chmod +x "$tmp/shim/quark" "$tmp/shim/firefox"
	trap harness_teardown EXIT
}

harness_teardown() {
	if [ -n "${sway_pid:-}" ]; then
		kill "$sway_pid" 2>/dev/null || :
		wait "$sway_pid" 2>/dev/null || :
	fi
	rm -rf "$tmp"
}

sway_env() {
	env PATH="$tmp/shim:$tmp/usr/bin:$PATH" \
		WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
		XDG_RUNTIME_DIR="$runtime" "$@"
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
