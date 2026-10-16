#!/bin/sh
set -eu

config="$(dirname "$0")/../../config/sway/config"
readonly config

expect_bind() {
	grep -qxF "bindsym $1 exec quark-de-screenshot $2" "$config" ||
		{
			echo "FAIL: $config does not bind $1 to a $2 screenshot; add 'bindsym $1 exec quark-de-screenshot $2'" >&2
			exit 1
		}
}

expect_bind Print full
expect_bind Shift+Print region
expect_bind "\$mod+Print" window
echo "ok  screenshot keys"
