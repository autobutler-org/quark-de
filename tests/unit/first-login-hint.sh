#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/shim" "$tmp/home"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >>"%s/swaynag.args"\necho --- >>"%s/swaynag.args"\n' "$tmp" "$tmp" >"$tmp/shim/swaynag"
chmod +x "$tmp/shim/swaynag"

hint() {
	env "$@" PATH="$tmp/shim:$PATH" HOME="$tmp/home" sh "$repo/session/quark-de-hint" --first-login
}

shows() {
	[ -e "$tmp/swaynag.args" ] && [ "$(grep -c '^---$' "$tmp/swaynag.args")" -eq "$1" ]
}

hint XDG_STATE_HOME="$tmp/state"
shows 1 || fail "the first login did not show the cheat sheet"
[ -e "$tmp/state/quark-de/first-login-hint-shown" ] || fail "the first login left no marker in XDG_STATE_HOME"
for key in 'Super+2 browser' 'Super+3 terminal' 'Super+Tab or Super+1 back to Quark' 'Super+/ or Super+F1'; do
	grep -qF "$key" "$tmp/swaynag.args" || fail "the cheat sheet does not say '$key': $(cat "$tmp/swaynag.args")"
done

hint XDG_STATE_HOME="$tmp/state"
shows 1 || fail "the second login showed the cheat sheet again"

hint -u XDG_STATE_HOME
shows 2 || fail "the first login without XDG_STATE_HOME did not show the cheat sheet"
[ -e "$tmp/home/.local/state/quark-de/first-login-hint-shown" ] ||
	fail "without XDG_STATE_HOME the marker is not under ~/.local/state"
hint -u XDG_STATE_HOME
shows 2 || fail "the second login without XDG_STATE_HOME showed the cheat sheet again"

env PATH="$tmp/shim:$PATH" HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" sh "$repo/session/quark-de-hint"
shows 3 || fail "quark-de-hint without arguments did not show the cheat sheet after the first login"

echo "ok  first-login hint"
