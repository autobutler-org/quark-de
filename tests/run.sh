#!/bin/sh
set -u
failed=0
for t in "$1"/*.sh; do
	[ -e "$t" ] || continue
	if ! sh "$t"; then
		echo "FAIL $t" >&2
		failed=1
	fi
done
exit "$failed"
