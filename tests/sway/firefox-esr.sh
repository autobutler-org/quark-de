#!/bin/sh
set -eu
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

harness_setup
stub quark-de-browser 'exec foot --app-id=firefox-esr'
sway_start
wait_for 10 app_views_is firefox-esr 1 || fail "the session did not start the browser with quark-de-browser"
app_on_workspace firefox-esr 2:browser || fail "firefox-esr did not open on 2:browser"

app_kill firefox-esr
wait_for 10 app_views_is firefox-esr 0 || fail "firefox-esr did not exit"
binding_run 1
binding_run 2
wait_for 10 app_views_is firefox-esr 1 || fail "Super+2 did not relaunch firefox-esr"
app_on_workspace firefox-esr 2:browser || fail "the relaunched firefox-esr is not on 2:browser"
binding_run 1
binding_run 2
sleep 2
app_views_is firefox-esr 1 || fail "Super+2 started a second firefox-esr while one was running"
[ "$(focused_workspace)" = 2:browser ] || fail "Super+2 did not switch to 2:browser with firefox-esr running"
echo "ok  firefox-esr"
