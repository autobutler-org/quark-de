#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup

printf '#!/bin/sh\nenv\n' >"$tmp/shim/sway"
chmod +x "$tmp/shim/sway"

env -u XDG_DATA_DIRS PATH="$tmp/shim:$PATH" XDG_RUNTIME_DIR="$runtime" \
	"$tmp/usr/bin/quark-de" >"$tmp/env" 2>"$tmp/err" ||
	fail "quark-de did not reach sway: $(cat "$tmp/err")"
grep -qx 'XDG_DATA_DIRS=/usr/local/share:/usr/share' "$tmp/env" ||
	fail "quark-de must export XDG_DATA_DIRS=/usr/local/share:/usr/share before exec sway when it is unset, or the Quark AppImage cannot find the system MIME database and aborts in GTK"

env XDG_DATA_DIRS=/home/me/.local/share/flatpak/exports/share:/usr/share PATH="$tmp/shim:$PATH" XDG_RUNTIME_DIR="$runtime" \
	"$tmp/usr/bin/quark-de" >"$tmp/env" 2>"$tmp/err" ||
	fail "quark-de did not reach sway: $(cat "$tmp/err")"
grep -qx 'XDG_DATA_DIRS=/home/me/.local/share/flatpak/exports/share:/usr/share' "$tmp/env" ||
	fail "quark-de must leave an existing XDG_DATA_DIRS alone"
echo "ok  launcher defaults XDG_DATA_DIRS"
