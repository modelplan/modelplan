#!/bin/bash
# SPDX-License-Identifier: MIT
# Build seed for the merge-queue job native-headless (trusted-mac.yml). Runs from main's checkout (never PR code), with
# the job's workspace as the current directory.
#   headless-seed.sh restore   clone the runner's verified seed into the two scratch locations before the first build
#   headless-seed.sh publish   (trusted main dispatch only, after a green run) publish the finished build state
# State: desktop/native/.build and $RUNNER_TEMP/app-integration-tests, the two scratch paths the job builds in. A seed
# is only usable on the runner that built it (SwiftPM records absolute paths). Any error is a cold build, never a failure.
set -u
mode=${1:-}
RUNNER_TEMP=${RUNNER_TEMP:?}
SEED_ROOT=${SEED_ROOT:-$HOME/headless-seed/${RUNNER_NAME:-runner}}
case $mode in restore) SEED_WRITE=0;; publish) SEED_WRITE=1;; *) echo "usage: headless-seed.sh restore|publish" >&2; exit 2;; esac
. "$(dirname "${BASH_SOURCE[0]}")/seedlib.sh"
ROOT=$PWD
# package dir, seed name, scratch location
ENTRIES=(
  "desktop/native|headless_native|$ROOT/desktop/native/.build"
  "desktop/native/ModelPlanAppIntegration|headless_app_integration|$RUNNER_TEMP/app-integration-tests"
)
for entry in "${ENTRIES[@]}"; do
  IFS='|' read -r dir name dest <<<"$entry"
  if [ "$mode" = restore ]; then
    # Start from nothing: a restore replaces whatever is there, a miss leaves a clean cold build.
    wipe "$dest"; [ ! -e "$dest" ] || { echo "::warning::could not clear $dest"; continue; }
    seed_restore "$dir" "$name" "$dest" || true
  elif [ -d "$dest" ]; then
    seed_publish "$dir" "$name" "$dest" || echo "::warning::seed for $name not published"
  else
    echo "::warning::no build state at $dest: seed for $name not published"
  fi
done
exit 0
