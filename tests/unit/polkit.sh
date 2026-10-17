#!/bin/sh
set -eu

repo="$(cd "$(dirname "$0")/../.." && pwd)"
readonly repo
tmp="$(mktemp -d)"
readonly tmp
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: polkit: $*" >&2
	cat "$tmp/out" >&2 2>/dev/null || :
	exit 1
}

mkdir "$tmp/session"
sed "s|/usr/|$tmp/root/usr/|g" "$repo/session/quark-de-polkit" >"$tmp/session/quark-de-polkit"
cp "$repo/session/quark-de" "$tmp/session/quark-de"
chmod +x "$tmp/session/quark-de-polkit" "$tmp/session/quark-de"
grep -q "$tmp/root/usr/libexec" "$tmp/session/quark-de-polkit" || fail "could not point the helper's libexec paths at the test root"

reset() {
	rm -rf "${tmp:?}/bin" "${tmp:?}/root" "${tmp:?}/calls"
	mkdir -p "$tmp/bin"
	ln -s "$(command -v dirname)" "$tmp/bin/dirname"
}

agent() {
	mkdir -p "$(dirname "$1")"
	printf '#!/bin/sh\necho "%s" >>"%s/calls"\n' "$1" "$tmp" >"$1"
	chmod +x "$1"
}

found() {
	PATH="$tmp/bin" "$tmp/session/quark-de-polkit" --find >"$tmp/out" 2>&1 || fail "--find found no agent, expected $1"
	[ "$(cat "$tmp/out")" = "$1" ] || fail "--find picked '$(cat "$tmp/out")', expected $1"
}

reset
if PATH="$tmp/bin" "$tmp/session/quark-de-polkit" --find >"$tmp/out" 2>&1; then
	fail "--find succeeded with no agent installed"
fi
if PATH="$tmp/bin" "$tmp/session/quark-de-polkit" >"$tmp/out" 2>&1; then
	fail "the helper exited zero with no agent installed"
fi
grep -q 'sudo apt install lxpolkit' "$tmp/out" || fail "a missing agent does not say how to install one"
PATH="$tmp/bin" /bin/sh "$tmp/session/quark-de" --check >"$tmp/out" 2>&1 || :
grep -q '^warning  polkit-agent — sudo apt install lxpolkit' "$tmp/out" || fail "quark-de --check does not warn about a missing polkit agent with an apt hint"

reset
agent "$tmp/bin/lxpolkit"
found "$tmp/bin/lxpolkit"
PATH="$tmp/bin" "$tmp/session/quark-de-polkit" >"$tmp/out" 2>&1 || fail "the helper did not start lxpolkit"
grep -qxF "$tmp/bin/lxpolkit" "$tmp/calls" || fail "the helper did not exec lxpolkit"
PATH="$tmp/bin" /bin/sh "$tmp/session/quark-de" --check >"$tmp/out" 2>&1 || :
grep -qx 'ok       polkit-agent' "$tmp/out" || fail "quark-de --check does not report an installed agent as ok"

reset
agent "$tmp/bin/lxpolkit"
agent "$tmp/root/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
found "$tmp/root/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"

reset
agent "$tmp/root/usr/libexec/polkit-gnome-authentication-agent-1"
found "$tmp/root/usr/libexec/polkit-gnome-authentication-agent-1"

reset
agent "$tmp/root/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
agent "$tmp/root/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1"
found "$tmp/root/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"

reset
agent "$tmp/bin/lxpolkit"
agent "$tmp/root/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1"
found "$tmp/bin/lxpolkit"

reset
agent "$tmp/root/usr/lib/aarch64-linux-gnu/libexec/polkit-kde-authentication-agent-1"
found "$tmp/root/usr/lib/aarch64-linux-gnu/libexec/polkit-kde-authentication-agent-1"
PATH="$tmp/bin" "$tmp/session/quark-de-polkit" >"$tmp/out" 2>&1 || fail "the helper did not start the kde agent"
grep -qxF "$tmp/root/usr/lib/aarch64-linux-gnu/libexec/polkit-kde-authentication-agent-1" "$tmp/calls" || fail "the helper did not exec the kde agent"

reset
agent "$tmp/root/usr/lib/polkit-kde-authentication-agent-1"
found "$tmp/root/usr/lib/polkit-kde-authentication-agent-1"

reset
agent "$tmp/root/usr/libexec/polkit-gnome-authentication-agent-1"
chmod -x "$tmp/root/usr/libexec/polkit-gnome-authentication-agent-1"
agent "$tmp/bin/lxpolkit"
found "$tmp/bin/lxpolkit"

grep -qx 'exec quark-de-polkit' "$repo/config/sway/config" || fail "the sway config does not start quark-de-polkit"
echo "ok  polkit"
