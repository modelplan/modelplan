#!/bin/bash
# SPDX-License-Identifier: MIT
# Shared build-seed helpers (sourced by run.sh and headless-seed.sh). A seed is a per-runner read-only copy of SwiftPM
# build state, published only by a trusted main run; a job clones it into its own scratch and builds on top, and any
# error means a cold build. Callers set SEED_ROOT and SEED_WRITE before sourcing; sourcing has no side effects.
SEED_ROOT=${SEED_ROOT:-}; SEED_WRITE=${SEED_WRITE:-0}
sha256() { if command -v shasum >/dev/null; then shasum -a 256; else sha256sum; fi | cut -d' ' -f1; }
# Seeds and their clones are read-only, and a read-only directory blocks unlinking its entries: make every target
# owner-writable first (find, so one unreadable entry cannot stop the walk), clear immutable flags on macOS, then remove.
wipe() {
  local p
  for p in "$@"; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    find "$p" ! -type l -exec chmod u+rwx {} + 2>/dev/null
    [ "$(uname)" = Darwin ] && chflags -R nouchg,noschg "$p" 2>/dev/null
    rm -rf "$p" 2>/dev/null || { find "$p" ! -type l -exec chmod u+rwx {} + 2>/dev/null; rm -rf "$p"; }
  done
  return 0
}
# Like wipe, but never fatal: a path that still cannot be removed is moved aside into a fresh mktemp directory (logged),
# so the caller finds it gone and builds cold instead of failing the job.
clear_path() {
  local aside
  wipe "$1"
  [ -e "$1" ] || [ -L "$1" ] || return 0
  aside=$(mktemp -d "$1.aside.XXXXXX") && mv "$1" "$aside/old" 2>/dev/null && [ ! -e "$1" ] && { echo "could not delete $1: moved aside to $aside, building cold"; return 0; }
  return 1
}
# Copy $1 to $2 (must not exist): each attempt (APFS clonefile, then plain copy) gets a FRESH mktemp directory next to
# it, copies to <tmp>/c, and renames on success. A failed attempt is wiped; if the wipe fails nothing is retried and the
# caller builds cold. A path is never reused, so a partial copy can neither be renamed into place nor nested.
clone() {
  local flag tmp
  [ ! -e "$2" ] || return 1
  mkdir -p "$(dirname "$2")" || return 1
  for flag in -cR -R; do
    tmp=$(mktemp -d "$2.tmp.XXXXXX") || return 1
    if cp "$flag" "$1" "$tmp/c" 2>/dev/null; then
      if [ ! -e "$2" ] && chmod -R u+w "$tmp/c" && mv "$tmp/c" "$2"; then rmdir "$tmp" 2>/dev/null; return 0; fi
      wipe "$tmp"; return 1
    fi
    wipe "$tmp"; [ ! -e "$tmp" ] || return 1
  done
  return 1
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
# seed_lock: acquire the write lock (SEED_WRITE=1 only). Returns 1 instead of exiting, so each caller decides.
seed_lock() {
  [ "$SEED_WRITE" = 1 ] || return 0
  trap release EXIT
  [ -n "$SEED_ROOT" ] || { echo "::error::SEED_WRITE needs SEED_ROOT"; return 1; }
  mkdir -p "$SEED_ROOT" || { echo "::error::cannot create $SEED_ROOT"; return 1; }
  for _ in $(seq 1 120); do
    if mkdir "$lock" 2>/dev/null; then echo $$ >"$lock/pid"; break; fi
    p=$(cat "$lock/pid" 2>/dev/null || true)
    if [ -n "$p" ]; then
      kill -0 "$p" 2>/dev/null || { rm -rf "$lock"; continue; }
    elif [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then rm -rf "$lock"; continue; fi
    sleep 5
  done
  [ -f "$lock/pid" ] && [ "$(cat "$lock/pid")" = "$$" ] || { echo "::error::could not lock $SEED_ROOT"; return 1; }
}


# seed_restore <package dir> <scratch name> <dest>: clone the matching verified seed to <dest> (which must not exist
# afterwards unless the clone succeeded). Returns 0 on a hit, 1 otherwise; the caller then builds cold.
seed_restore() {
  local key seed m
  [ -n "$SEED_ROOT" ] && [ "$SEED_WRITE" != 1 ] || return 1
  key=$(seedkey "$1"); seed="$SEED_ROOT/$2/$key"
  if [ -d "$seed" ] && m=$(manifest "$seed") && [ "$(cat "$seed.manifest" 2>/dev/null)" = "$m" ]; then
    echo "seed hit for $1: cloning"
    if clone "$seed" "$3" && chmod -R u+w "$3"; then return 0; fi
    clear_path "$3" || return 2
    echo "seed clone failed: cold build"; return 1
  fi
  echo "no usable seed for $1: cold build"; return 1
}
# seed_publish <package dir> <scratch name> <built scratch>: replace every older key of the package by the new seed.
seed_publish() {
  local key seed m
  key=$(seedkey "$1"); seed="$SEED_ROOT/$2/$key"
  # Publish: remove every older key of this package (hidden entries included), then the new seed and its manifest.
  wipe "${SEED_ROOT:?}/$2"; [ ! -e "$SEED_ROOT/$2" ] || { echo "::error::could not clear seed for $2"; return 1; }
  { clone "$3" "$seed" && chmod -R a-w "$seed" && m=$(manifest "$seed") && printf '%s' "$m" >"$seed.manifest"; } || { echo "::error::could not publish seed for $2"; return 1; }
}
