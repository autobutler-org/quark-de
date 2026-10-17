#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

# Prints one line per duplicate bindsym key, workspace target that is not one of the
# $quark/$browser/$terminal names, or quark-de-* helper that make install does not ship.
binding_problems() {
	awk -v bin="$tmp/usr/bin" '
		function expand(s, n, parts, i, out) {
			n = split(s, parts, "+")
			out = ""
			for (i = 1; i <= n; i++) {
				if (parts[i] in vars) parts[i] = vars[parts[i]]
				out = out (i > 1 ? "+" : "") parts[i]
			}
			return out
		}
		function normalize(key, n, parts, i, j, t, out) {
			n = split(tolower(key), parts, "+")
			for (i = 1; i < n - 1; i++)
				for (j = i + 1; j < n; j++)
					if (parts[j] < parts[i]) { t = parts[i]; parts[i] = parts[j]; parts[j] = t }
			out = parts[1]
			for (i = 2; i <= n; i++) out = out "+" parts[i]
			return out
		}
		function check_target(ws) {
			if (!(ws in targets)) printf "line %d: unknown workspace %s in: %s\n", NR, ws, $0
		}
		$1 == "set" { vars[$2] = $3 }
		$1 == "bindsym" {
			if (!targets_set) {
				targets_set = 1
				targets["$quark"]; targets["$browser"]; targets["$terminal"]
				targets[vars["$quark"]]; targets[vars["$browser"]]; targets[vars["$terminal"]]
			}
			i = 2
			while ($i ~ /^--/) i++
			key = normalize(expand($i))
			if (key in seen) printf "line %d: %s is already bound on line %d\n", NR, key, seen[key]
			else seen[key] = NR
			for (j = i + 1; j <= NF; j++) {
				if ($j == "workspace" && $(j - 1) != "exec") {
					ws = $(j + 1) == "number" ? $(j + 2) : $(j + 1)
					check_target(ws)
				}
				if ($j == "exec" && $(j + 1) ~ /^quark-de-/) {
					if (system("test -x \"" bin "/" $(j + 1) "\"") != 0)
						printf "line %d: %s is not installed; add it to session/\n", NR, $(j + 1)
					if ($(j + 1) == "quark-de-focus") check_target($(j + 2))
				}
			}
		}
	' "$1"
}

harness_setup

bad="$(binding_problems "$repo/config/sway/config")"
[ -z "$bad" ] || fail "config/sway/config has broken keybindings; fix:
$bad"

cat >"$tmp/broken.config" <<'EOF'
set $mod Mod4
set $quark 1:quark
set $browser 2:browser
set $terminal 3:terminal
bindsym $mod+1 workspace $quark
bindsym --to-code Mod4+1 workspace 1:quark
bindsym $mod+Shift+e exec true
bindsym Shift+$mod+E exec true
bindsym $mod+2 workspace 2:browsr
bindsym $mod+3 exec quark-de-focus $termnal foot foot
bindsym $mod+4 exec quark-de-missing
EOF
problems="$(binding_problems "$tmp/broken.config")"
for want in 'line 6: mod4+1 is already bound on line 5' 'line 8: mod4+shift+e is already bound on line 7' \
	'line 9: unknown workspace 2:browsr' "line 10: unknown workspace \$termnal" 'line 11: quark-de-missing is not installed'; do
	printf '%s\n' "$problems" | grep -qF "$want" || fail "the keybinding check missed '$want'; it reported:
$problems"
done
[ "$(printf '%s\n' "$problems" | wc -l)" -eq 5 ] || fail "the keybinding check reported extra problems:
$problems"

sway_start
wait_for 10 views_up 3 || fail "the session did not map its three clients"

display=
for sock in "$runtime"/wayland-*; do
	case "$sock" in *.lock) continue ;; esac
	[ -S "$sock" ] && display="$sock"
done

# Refuses to send anything unless both sockets belong to the test sway, so a bad
# environment can never press keys or run commands on the desktop the test runs from.
guard_session() {
	kill -0 "$sway_pid" 2>/dev/null || fail "the test sway ($sway_pid) is gone; not sending keys"
	[ "$runtime" != "${XDG_RUNTIME_DIR:-}" ] || fail "the test runtime dir is the caller's XDG_RUNTIME_DIR; not sending keys"
	case "$display" in
	"$runtime"/wayland-*) [ -S "$display" ] || fail "$display is not a socket; not sending keys" ;;
	*) fail "WAYLAND_DISPLAY '$display' is not the test sway's socket in $runtime; not sending keys" ;;
	esac
	case "$SWAYSOCK" in
	"$runtime"/sway-ipc.*.sock) [ -S "$SWAYSOCK" ] || fail "$SWAYSOCK is not a socket; not sending keys" ;;
	*) fail "SWAYSOCK '$SWAYSOCK' is not the test sway's socket in $runtime; not sending keys" ;;
	esac
}

# Press keys through the virtual keyboard when wtype is installed, so config.d snippets and
# keymap issues show up; otherwise run the bound command from the installed config.
if command -v wtype >/dev/null; then
	press() {
		guard_session
		case "$1" in
		Shift+*) set -- -M shift -k "${1#Shift+}" -m shift ;;
		*) set -- -k "$1" ;;
		esac
		sway_env env WAYLAND_DISPLAY="$display" wtype -M logo "$@" -m logo
	}
else
	echo "note: wtype not found (sudo apt install wtype); running the bound commands instead of pressing keys" >&2
	press() {
		guard_session
		binding_run "$1"
	}
fi

workspace_is() {
	[ "$(focused_workspace)" = "$1" ]
}

for case in 1:1:quark 2:2:browser 3:3:terminal; do
	key="${case%%:*}" ws="${case#*:}"
	press "$key"
	wait_for 5 workspace_is "$ws" || fail "Super+$key focused $(focused_workspace), not $ws"
	press Tab
	wait_for 5 workspace_is 1:quark || fail "Super+Tab from $ws focused $(focused_workspace), not 1:quark"
done

nagged() {
	grep -qxF 'Log out of Quark?' "$tmp/swaynag.args" 2>/dev/null
}

press Shift+e
wait_for 5 nagged || fail "Super+Shift+E did not start swaynag with the logout message; log: $(cat "$tmp/sway.log")"
kill -0 "$sway_pid" 2>/dev/null || fail "Super+Shift+E exited sway instead of asking"
echo "ok  keybindings"
