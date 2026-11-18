#!/bin/bash
# SPDX-License-Identifier: MIT
# Mac compile check (mac-compile.yml), run on the compile Mac in a checkout of the PR merge commit.
# Usage: run.sh <plan.tsv> <scratch root> <sha>
# Optional SEED_ROOT: a per-runner build seed. PR jobs only READ it (a clone of the matching seed becomes the job's own
# scratch, thrown away with the job); with SEED_WRITE=1 (trusted main runs only) a successful build is published to it.
# For each plan row (from plan.mjs): swift build, then swift test on the selected classes (or the whole package
# minus the never-run classes, or only --build-tests; ModelPlanAppIntegration is never run whole, see plan.mjs). Each package gets at most PACKAGE_MINUTES (default 25) for
# build and test together. Writes the summary to $GITHUB_STEP_SUMMARY (first line "COMPILE ok|fail @ <sha8>")
# and exits non-zero on any failure.
set -u
PLAN=$1; SCRATCH_ROOT=$2; SHA=$3
LIMIT=$(( ${PACKAGE_MINUTES:-25} * 60 ))
LOGS=${RUNNER_TEMP:-/tmp}/mac-compile-logs; rm -rf "$LOGS"; mkdir -p "$LOGS" "$SCRATCH_ROOT"
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
ok=1; rows=; failed_tests=; errors=

SEED_ROOT=${SEED_ROOT:-}; SEED_WRITE=${SEED_WRITE:-0}
sha256() { if command -v shasum >/dev/null; then shasum -a 256; else sha256sum; fi | cut -d' ' -f1; }
wipe() { chmod -R u+w "$@" 2>/dev/null; rm -rf "$@"; }   # seeds are read-only: make them writable before removing
# Copy $1 to $2 through a temp name next to it and rename on success (APFS clonefile first, plain copy as fallback).
# A partial copy is removed, never renamed into place and never nested by a retry.
clone() {
  local tmp="$2.tmp.$$"
  wipe "$tmp"; mkdir -p "$(dirname "$2")" || return 1
  if ! cp -cR "$1" "$tmp" 2>/dev/null; then wipe "$tmp"; cp -R "$1" "$tmp" || { wipe "$tmp"; return 1; }; fi
  mv "$tmp" "$2" || { wipe "$tmp"; return 1; }
}
# Hash of every entry of a directory: type, size, nanosecond mtime, symlink target. Any error fails (cold build).
manifest() (
  set -o pipefail
  cd "$1" || exit 1
  find . -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
    if [ "$(uname)" = Darwin ]; then st=$(stat -f '%HT %z %Fm' -- "$f"); else st=$(stat -c '%F %s %.9Y' -- "$f"); fi || exit 1
    t=; if [ -L "$f" ]; then t=$(readlink -- "$f") || exit 1; fi
    printf '%s\t%s\t%s\n' "$f" "$st" "$t"
  done | sha256
)
# Seed key: toolchain plus the package's Package.resolved.
seedkey() { { swift --version 2>&1; cat "$1/Package.resolved" 2>/dev/null; } | sha256; }

# Only a seed WRITE needs exclusivity: mkdir is atomic and the pid goes into the directory right after; the trap is
# installed first and removes the lock only if the pid is ours. A dead owner, or a missing pid file on a lock older
# than a minute (an interrupted acquisition, or a plain directory in the way), is reclaimed.
lock="${SEED_ROOT:-/nonexistent}.lock"
release() { [ -f "$lock/pid" ] && [ "$(cat "$lock/pid" 2>/dev/null)" = "$$" ] && rm -rf "$lock"; return 0; }
trap release EXIT
if [ "$SEED_WRITE" = 1 ]; then
  [ -n "$SEED_ROOT" ] || { echo "::error::SEED_WRITE needs SEED_ROOT"; exit 1; }
  mkdir -p "$SEED_ROOT" || exit 1
  for _ in $(seq 1 120); do
    if mkdir "$lock" 2>/dev/null; then echo $$ >"$lock/pid"; break; fi
    p=$(cat "$lock/pid" 2>/dev/null || true)
    if [ -n "$p" ]; then
      kill -0 "$p" 2>/dev/null || { rm -rf "$lock"; continue; }
    elif [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then rm -rf "$lock"; continue; fi
    sleep 5
  done
  [ -f "$lock/pid" ] && [ "$(cat "$lock/pid")" = "$$" ] || { echo "::error::could not lock $SEED_ROOT"; exit 1; }
fi

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
  wipe "$sp"; [ ! -e "$sp" ] || { echo "::error::could not clear $sp"; exit 1; }
  key=; seed=
  if [ -n "$SEED_ROOT" ]; then
    key=$(seedkey "$dir"); seed="$SEED_ROOT/$scratch/$key"
    if [ "$SEED_WRITE" != 1 ] && [ -d "$seed" ] && m=$(manifest "$seed") && [ "$(cat "$seed.manifest" 2>/dev/null)" = "$m" ]; then
      echo "seed hit for $dir: cloning"
      if clone "$seed" "$sp" && chmod -R u+w "$sp"; then :; else wipe "$sp"; echo "seed clone failed: cold build"; fi
    else echo "no usable seed for $dir: cold build"; fi
  fi
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
  if [ "$SEED_WRITE" = 1 ] && [ "$build" = ok ] && [ "$test" != "not run" ] && [ "$trc" = 0 ]; then
    # Publish: remove every older key of this package (hidden entries included), then the new seed and its manifest.
    wipe "${SEED_ROOT:?}/$scratch"; [ ! -e "$SEED_ROOT/$scratch" ] || { echo "::error::could not clear seed for $scratch"; exit 1; }
    { clone "$sp" "$seed" && chmod -R a-w "$seed" && m=$(manifest "$seed") && printf '%s' "$m" >"$seed.manifest"; } || { echo "::error::could not publish seed for $scratch"; exit 1; }
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
