#!/bin/bash
# ModelPlan First Run (D164, owner test packages only).
# Quits ModelPlan, runs a true first run on a temporary profile folder and deletes that folder when
# the app quits. Your real ModelPlan settings, caches and login item are never touched. Real tool data
# (Codex, Claude, ...) is still detected and is read only after you consent, as for a new user.
# Sits next to "ModelPlan Community.app" in the test zip; production builds do not ship it.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
app="$here/ModelPlan Community.app"
bundle_id=org.modelplan.community.swift.scaffold
executable=ModelPlanCommunity

[ -d "$app" ] || { echo "ModelPlan Community.app must sit next to this file." >&2; exit 1; }
# Only an owner test package may run a fresh profile; a production app refuses here.
[ "$(defaults read "$app/Contents/Info" ModelPlanOwnerTestBuild 2>/dev/null)" = 1 ] || {
    echo "This is not an owner test build; ModelPlan First Run is not available." >&2; exit 1; }

quit_running() {
    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x "$executable" >/dev/null 2>&1 || return 0
        sleep 0.5
    done
    pkill -x "$executable" >/dev/null 2>&1 || true
}
stop_helper() { pkill -f -- "$app/Contents/Helpers/modelplan" >/dev/null 2>&1 || true; }

quit_running
stop_helper
base=$(cd "${TMPDIR:-/tmp}" && pwd -P) || exit 1
root=$(mktemp -d "$base/modelplan-first-run.XXXXXX") || exit 1
case "$root" in "$base"/modelplan-first-run.*) ;; *) echo "unexpected profile folder" >&2; exit 1 ;; esac
cleanup() {
    stop_helper
    rm -rf -- "$root"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

echo "Starting ModelPlan on a fresh profile. Quit ModelPlan to end the session and delete it."
# -W waits for the app to quit, -n a new instance, -F no window restoration from the real profile.
open -W -n -F --env "MODELPLAN_PROFILE_ROOT=$root" "$app" --args -ApplePersistenceIgnoreState YES
status=$?
cleanup
trap - EXIT
echo "Fresh profile deleted."
exit "$status"
