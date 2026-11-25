#!/bin/bash
# SPDX-License-Identifier: MIT
# Mac compile check (mac-compile.yml), run on the compile Mac in a checkout of the PR merge commit.
# Usage: run.sh <plan.tsv> <scratch root> <sha>
# Optional SEED_ROOT: a per-runner build seed. PR jobs only READ it (a clone of the matching seed becomes the job's own
# scratch, thrown away with the job); with SEED_WRITE=1 (trusted main runs only) a successful build is published to it.
# For each plan row (from plan.mjs): one `swift build --build-tests` (product and test targets, one compile), then `swift test --skip-build` on the selected classes (or the whole package
# minus the never-run classes, or only --build-tests; ModelPlanAppIntegration is never run whole, see plan.mjs). Each package gets at most PACKAGE_MINUTES (default 25) for
# build and test together. Writes the summary to $GITHUB_STEP_SUMMARY (first line "COMPILE ok|fail @ <sha8>")
# and exits non-zero on any failure.
set -u
PLAN=$1; SCRATCH_ROOT=$2; SHA=$3
LIMIT=$(( ${PACKAGE_MINUTES:-25} * 60 ))
LOGS=${RUNNER_TEMP:-/tmp}/mac-compile-logs; mkdir -p "$SCRATCH_ROOT"
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
ok=1; rows=; failed_tests=; errors=

SEED_ROOT=${SEED_ROOT:-}; SEED_WRITE=${SEED_WRITE:-0}
. "$(dirname "${BASH_SOURCE[0]}")/seedlib.sh"
wipe "$LOGS"; mkdir -p "$LOGS" || exit 1
seed_lock || exit 1

# Run "$@" until it exits or the package deadline passes (macOS has no timeout(1)); SwiftPM stops its children on TERM.
limited() {
  local left=$(( deadline - $(date +%s) ))
  [ "$left" -gt 0 ] || { echo "time limit reached before: $*"; return 124; }
  "$@" & local pid=$!
  ( sleep "$left"; kill -TERM "$pid" 2>/dev/null && { echo "::error::$(basename "$dir"): over ${PACKAGE_MINUTES:-25} minutes, stopped"; sleep 15; kill -KILL "$pid" 2>/dev/null; } ) &
  local watch=$!
  wait "$pid"; local rc=$?
  kill "$watch" 2>/dev/null; wait "$watch" 2>/dev/null
  return "$rc"
}

while IFS=$'\t' read -r dir scratch mode filter skip flags; do
  [ -n "$dir" ] || continue
  fl=(); [ -z "${flags:-}" ] || [ "$flags" = - ] || fl=(-Xswiftc "$flags") # only the fixed flags plan.mjs names
  sp="$SCRATCH_ROOT/$scratch"; blog="$LOGS/$scratch-build.log"; tlog="$LOGS/$scratch-test.log"
  deadline=$(( $(date +%s) + LIMIT ))
  clear_path "$sp" || { echo "::error::could not clear or move aside $sp"; exit 1; }
  if [ -n "$SEED_ROOT" ]; then seed_restore "$dir" "$scratch" "$sp"; [ $? != 2 ] || { echo "::error::could not clear or move aside $sp"; exit 1; }; fi
  echo "::group::$dir: swift build --build-tests"
  limited swift build --build-tests --package-path "$dir" --scratch-path "$sp" ${fl[@]+"${fl[@]}"} >"$blog" 2>&1; brc=$?
  tail -40 "$blog"; echo "::endgroup::"
  build=ok; test="not run"; : >"$tlog"
  if [ "$brc" != 0 ]; then
    build=fail; ok=0
  else
    echo "::group::$dir: tests ($mode)"
    case $mode in
      filter) limited swift test --skip-build --package-path "$dir" --scratch-path "$sp" --filter "$filter" --skip "$skip" ${fl[@]+"${fl[@]}"} >"$tlog" 2>&1; trc=$? ;;
      skip) limited swift test --skip-build --package-path "$dir" --scratch-path "$sp" --skip "$skip" ${fl[@]+"${fl[@]}"} >"$tlog" 2>&1; trc=$? ;;
      *) trc=0 ;; # the one build above already built the test targets
    esac
    tail -60 "$tlog"; echo "::endgroup::"
    if [ "$mode" = build-tests ]; then
      test="build-tests $([ "$trc" = 0 ] && echo ok || echo fail)"
    else
      pass=$(grep -cE "^Test Case '.*' passed" "$tlog"); fail=$(grep -cE "^Test Case '.*' failed" "$tlog")
      test="pass $pass / fail $fail"
      [ "$trc" = 0 ] || [ "$fail" != 0 ] || test="$test (swift test exit $trc)"
    fi
    [ "$trc" = 0 ] || ok=0
    while IFS= read -r name; do
      line=$(grep -F -m1 "error: $name" "$tlog")
      failed_tests="$failed_tests- \`$name\`${line:+: \`${line#"$PWD/"}\`}"$'\n'
    done < <(sed -nE "s/^Test Case '(.*)' failed.*/\1/p" "$tlog")
  fi
  if [ "$SEED_WRITE" = 1 ] && [ "$build" = ok ] && [ "$test" != "not run" ] && [ "$trc" = 0 ]; then
    seed_publish "$dir" "$scratch" "$sp" || exit 1
  fi
  rows="$rows- \`$dir\`${fl[*]:+ ($flags)}: build $build; test $test"$'\n'
  errors="$errors$(cat "$blog" "$tlog" | grep -E '^[^ :]+:[0-9]+:[0-9]+: error:' | sed "s#^$PWD/##")"$'\n'
done <"$PLAN"

{
  echo "COMPILE $([ "$ok" = 1 ] && echo ok || echo fail) @ ${SHA:0:8}"
  echo
  printf '%s' "$rows"
  if [ -n "$failed_tests" ]; then echo; echo "Failing tests (first 20):"; printf '%s' "$failed_tests" | head -20; fi
  e=$(printf '%s' "$errors" | grep . | awk '!seen[$0]++' | head -30)
  if [ -n "$e" ]; then echo; echo "Errors (first 30):"; echo '```'; echo "$e"; echo '```'; fi
} | tee -a "$SUMMARY"
[ "$ok" = 1 ]
