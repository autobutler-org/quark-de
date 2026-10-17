#!/bin/sh
set -eu

helper="$(cd "$(dirname "$0")/../.." && pwd)/session/quark-de-clipboard"
readonly helper
tmp="$(mktemp -d)"
readonly tmp
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

mkdir "$tmp/bin"
for tool in cat cmp grep mktemp rm; do
	ln -s "$(command -v "$tool")" "$tmp/bin/$tool"
done
printf '#!/bin/sh\ncat >>"%s/stored"\n' "$tmp" >"$tmp/bin/cliphist"
cat >"$tmp/bin/wl-paste" <<STUB
#!/bin/sh
case "\$1" in
--list-types) cat "$tmp/types" ;;
*) printf '%s' "\$(cat "$tmp/current")" ;;
esac
STUB
chmod +x "$tmp/bin/cliphist" "$tmp/bin/wl-paste"

store() {
	printf '%s\n' "$1" >"$tmp/types"
	printf '%s' "$2" >"$tmp/current"
	rm -f "$tmp/stored"
	printf '%s' "$3" | PATH="$tmp/bin" /bin/sh "$helper" store
}

store text/plain 'hello' 'hello'
[ "$(cat "$tmp/stored" 2>/dev/null)" = hello ] || fail "a plain copy was not stored"

store x-kde-passwordManagerHint 'secret' 'secret'
[ ! -e "$tmp/stored" ] || fail "a copy marked x-kde-passwordManagerHint was stored"

store text/plain 'copied after the secret' 'secret'
[ ! -e "$tmp/stored" ] || fail "a copy was stored after the clipboard had already changed, so its type could not be checked"

echo "ok  clipboard store"
