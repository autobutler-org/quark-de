#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

unit_setup
make -s -C "$repo" install DESTDIR="$tmp/root" PREFIX=/usr >/dev/null
readonly launcher="$tmp/root/usr/bin/quark-de"
readonly home="$tmp/home"
readonly state="$home/.local/state/quark-de"
for tool in sh dirname mkdir mktemp date sed cat mv rm tar gzip; do
	ln -s "$(command -v "$tool")" "$tmp/shim/$tool"
done

run_report() {
	rm -rf "$state" "$tmp/out" "$tmp/x"
	mkdir -p "$state" "$tmp/x"
	printf 'started in %s/.config\nlogin token=hunter2abc\n' "$home" >"$state/session.log"
	printf 'quark: Authorization: Bearer abc.def.ghi\nopened /home/alice/photos\n' >"$state/quark.log"
	env -i HOME="$home" PATH="$tmp/shim" "$launcher" --report >"$tmp/out" 2>"$tmp/err" ||
		fail "quark-de --report failed: $(cat "$tmp/err")"
	tarball="$(cat "$tmp/out")"
	case "$tarball" in
	"$state"/quark-de-report-*.tar.gz) ;;
	*) fail "quark-de --report printed '$tarball', want a tarball in $state" ;;
	esac
	tar -xzf "$tarball" -C "$tmp/x"
	bundle="$(echo "$tmp/x"/quark-de-report-*)"
}

has() {
	[ -f "$bundle/$1" ] || fail "the report has no $1: $(ls "$bundle")"
	grep -qF -- "$2" "$bundle/$1" || fail "$1 in the report lacks '$2': $(cat "$bundle/$1")"
}

stub swaymsg "case \"\$2\" in get_version) echo 'sway version 1.9' ;; get_outputs) echo 'HEADLESS-1' ;; get_tree) echo '{\"app_id\": \"org.autobutler.quark\", \"cwd\": \"$home/docs\"}' ;; esac"
stub journalctl "echo \"journalctl \$*\"; echo 'quark-de: api_key=sk-12345 in $home'"
stub coredumpctl "echo \"coredumpctl \$*\"; exit 1"
run_report
has session.log 'started in ~/.config'
has session.log 'token=REDACTED'
has quark.log 'Authorization: REDACTED'
has quark.log '/home/USER/photos'
has check.txt 'sway'
has sway-version.txt 'sway version 1.9'
has sway-outputs.txt 'HEADLESS-1'
has sway-tree.txt '"cwd": "~/docs"'
has journal.txt 'journalctl --user -b -t quark-de --no-pager'
has journal.txt 'api_key=REDACTED in ~'
has coredumps.txt 'coredumpctl list quark --no-pager'
if grep -rqE "$home|hunter2|abc\.def|sk-12345|alice" "$bundle"; then
	fail "the report leaks a home path or a token: $(grep -rE "$home|hunter2|abc\.def|sk-12345|alice" "$bundle")"
fi
grep -q 'nothing was uploaded' "$tmp/err" || fail "quark-de --report did not say nothing was uploaded: $(cat "$tmp/err")"

rm "$tmp/shim/journalctl" "$tmp/shim/coredumpctl"
stub swaymsg 'exit 1'
run_report
has skipped.txt 'sway: swaymsg is missing or sway is not running'
has skipped.txt 'journal.txt: journalctl not found'
has skipped.txt 'coredumps.txt: coredumpctl not found'
has check.txt 'missing  sway'
for file in sway-version.txt journal.txt coredumps.txt; do
	[ ! -e "$bundle/$file" ] || fail "the report has $file although its source is unavailable"
done

rm "$state/session.log" "$state/quark.log"
env -i HOME="$home" PATH="$tmp/shim" "$launcher" --report >"$tmp/out" 2>"$tmp/err" ||
	fail "quark-de --report failed without logs: $(cat "$tmp/err")"
rm -rf "$tmp/x" && mkdir "$tmp/x" && tar -xzf "$(cat "$tmp/out")" -C "$tmp/x"
grep -q 'session.log: not found in ~/.local/state/quark-de' "$tmp/x"/quark-de-report-*/skipped.txt ||
	fail "the report does not say session.log was missing"
echo "ok  report"
