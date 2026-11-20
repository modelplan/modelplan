#!/bin/bash
# SPDX-License-Identifier: MIT
# Build seed for the merge-queue job native-headless (trusted-mac.yml). Runs from main's checkout (never PR code), with
# the job's workspace as the current directory.
#   headless-seed.sh restore   clone the runner's verified seed into the job's scratch path before the first build
#   headless-seed.sh publish   (trusted main dispatch only, as soon as both builds are green and before any test runs)
#                              publish the build state
# State: $RUNNER_TEMP/headless-build, the ONE scratch path the job builds both packages in (desktop/native and
# ModelPlanAppIntegration, which depends on it), so the shared modules compile once; trusted-mac.yml uses the same path.
# A seed is only usable on the runner that built it (SwiftPM records absolute paths). Any error is a cold build, never a failure.
# It never fails the job over the seed itself: no seed, a hosted runner, an unusable seed root or lock, or any publish
# error is a cold build and exit 0. The one exception is a scratch path that can be neither deleted nor moved aside:
# the build would run on unverified state, so restore exits 1 (fail closed) rather than let it be consumed.
set -u
mode=${1:-}
RUNNER_TEMP=${RUNNER_TEMP:?}
SEED_ROOT=${SEED_ROOT:-$HOME/headless-seed/${RUNNER_NAME:-runner}}
# Hosted runners start clean and have no seed: nothing to do.
[ "${RUNNER_ENVIRONMENT:-}" != github-hosted ] || { echo "hosted runner: cold build"; exit 0; }
case $mode in restore) SEED_WRITE=0;; publish) SEED_WRITE=1;; *) echo "usage: headless-seed.sh restore|publish" >&2; exit 2;; esac
. "$(dirname "${BASH_SOURCE[0]}")/seedlib.sh"
# An unusable seed root or lock is a cold build, never a red job.
seed_lock || { echo "::warning::seed root or lock unavailable: no seed used or published"; exit 0; }
# package dir (its Package.resolved keys the seed), seed name, scratch location
ENTRIES=(
  "desktop/native/ModelPlanAppIntegration|headless_build|$RUNNER_TEMP/headless-build"
)
# Seeds of the earlier two-scratch layout are never read again: a publish removes them.
RETIRED=(headless_native headless_app_integration)
[ "$mode" != publish ] || wipe "${RETIRED[@]/#/$SEED_ROOT/}"
for entry in "${ENTRIES[@]}"; do
  IFS='|' read -r dir name dest <<<"$entry"
  if [ "$mode" = restore ]; then
    # Start from nothing: a path that survives cleanup is moved aside into a fresh mktemp directory; if even that fails
    # the build path holds unverified state and the job must not use it.
    clear_path "$dest" || { echo "::error::cannot establish a clean $dest (delete and move-aside both failed)"; exit 1; }
    seed_restore "$dir" "$name" "$dest"; [ $? != 2 ] || { echo "::error::cannot establish a clean $dest"; exit 1; }
  elif [ -d "$dest" ]; then
    seed_publish "$dir" "$name" "$dest" || echo "::warning::seed for $name not published"
  else
    echo "::warning::no build state at $dest: seed for $name not published"
  fi
done
exit 0
