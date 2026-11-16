#!/bin/bash
# SPDX-License-Identifier: MIT
# Mac compile check (mac-compile.yml), run on the compile Mac in a checkout of the PR merge commit.
# Usage: run.sh <plan.tsv> <scratch root> <sha>
# For each plan row (from plan.mjs): swift build, then swift test on the selected classes (or the whole package
# minus the never-run classes, or only --build-tests). Each package gets at most PACKAGE_MINUTES (default 25) for
# build and test together. Writes the summary to $GITHUB_STEP_SUMMARY (first line "COMPILE ok|fail @ <sha8>")
# and exits non-zero on any failure.
set -u
PLAN=$1; SCRATCH_ROOT=$2; SHA=$3
LIMIT=$(( ${PACKAGE_MINUTES:-25} * 60 ))
LOGS=${RUNNER_TEMP:-/tmp}/mac-compile-logs; rm -rf "$LOGS"; mkdir -p "$LOGS" "$SCRATCH_ROOT"
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
ok=1; rows=; failed_tests=; errors=

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

while IFS=$'\t' read -r dir scratch mode filter skip; do
  [ -n "$dir" ] || continue
  sp="$SCRATCH_ROOT/$scratch"; blog="$LOGS/$scratch-build.log"; tlog="$LOGS/$scratch-test.log"
  deadline=$(( $(date +%s) + LIMIT ))
  echo "::group::$dir: swift build"
  limited swift build --package-path "$dir" --scratch-path "$sp" >"$blog" 2>&1; brc=$?
  tail -40 "$blog"; echo "::endgroup::"
  build=ok; test="not run"; : >"$tlog"
  if [ "$brc" != 0 ]; then
    build=fail; ok=0
  else
    echo "::group::$dir: tests ($mode)"
    case $mode in
      filter) limited swift test --package-path "$dir" --scratch-path "$sp" --filter "$filter" --skip "$skip" >"$tlog" 2>&1; trc=$? ;;
      skip) limited swift test --package-path "$dir" --scratch-path "$sp" --skip "$skip" >"$tlog" 2>&1; trc=$? ;;
      *) limited swift build --build-tests --package-path "$dir" --scratch-path "$sp" >"$tlog" 2>&1; trc=$? ;;
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
  rows="$rows- \`$dir\`: build $build; test $test"$'\n'
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
