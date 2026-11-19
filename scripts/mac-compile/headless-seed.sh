#!/bin/bash
# SPDX-License-Identifier: MIT
# Build seed for the merge-queue job native-headless (trusted-mac.yml). Runs from main's checkout (never PR code), with
# the job's workspace as the current directory.
#   headless-seed.sh restore   clone the runner's verified seed into the two scratch locations before the first build
#   headless-seed.sh publish   (trusted main dispatch only, after a green run) publish the finished build state
# State: desktop/native/.build and $RUNNER_TEMP/app-integration-tests, the two scratch paths the job builds in. A seed
# is only usable on the runner that built it (SwiftPM records absolute paths). Any error is a cold build, never a failure.
# It never fails the job: no seed, a hosted runner, or any error is a cold build.
set -u
mode=${1:-}
RUNNER_TEMP=${RUNNER_TEMP:?}
SEED_ROOT=${SEED_ROOT:-$HOME/headless-seed/${RUNNER_NAME:-runner}}
# Hosted runners start clean and have no seed: nothing to do.
[ "${RUNNER_ENVIRONMENT:-}" != github-hosted ] || { echo "hosted runner: cold build"; exit 0; }
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
    # A scratch path that survives cleanup is moved aside into a fresh mktemp directory; if even that fails the warm
    # path is abandoned for this entry (nothing is cloned onto a surviving path) and the build is cold.
    wipe "$dest"
    if [ -e "$dest" ]; then
      aside=$(mktemp -d "$dest.stale.XXXXXX" 2>/dev/null) && mv "$dest" "$aside/old" 2>/dev/null
      [ ! -e "$dest" ] || { echo "::warning::could not clear $dest: cold build, no seed"; continue; }
    fi
    seed_restore "$dir" "$name" "$dest" || true
  elif [ -d "$dest" ]; then
    seed_publish "$dir" "$name" "$dest" || echo "::warning::seed for $name not published"
  else
    echo "::warning::no build state at $dest: seed for $name not published"
  fi
done
exit 0
