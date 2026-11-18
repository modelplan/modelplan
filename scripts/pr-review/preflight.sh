#!/bin/bash
# SPDX-License-Identifier: MIT
# Refuses to review unless this runner is the dedicated review identity and the Codex sandbox provably hides the
# login. Prints only pass/fail words: the job log of a public repository is public.
set -euo pipefail
fail() { echo "pr-review preflight: $*" >&2; exit 1; }
want=${MP_REVIEW_USER:-mpreview}
[ "$(id -u)" != 0 ] || fail "runs as root"
[ "$(id -un)" = "$want" ] || fail "runner user is not $want"
[ -n "${CODEX_HOME:-}" ] || fail "CODEX_HOME is not set in the runner .env"
home=$(cd "$HOME" && pwd -P)
codex_home=$(cd "$CODEX_HOME" && pwd -P) || fail "CODEX_HOME missing"
case "$codex_home/" in "$home"/*) ;; *) fail "CODEX_HOME must live inside the runner user's home";; esac
case "$(pwd -P)/" in "$home"/*) fail "the work directory must be outside the runner user's home";; esac
case "$RUNNER_TEMP/" in "$home"/*) fail "the runner temp must be outside the runner user's home";; esac
[ "$(stat -c %a "$home")" = 700 ] || fail "home must be mode 700"
[ -f "$codex_home/auth.json" ] || fail "no Codex login (run codex login --device-auth as $want)"
command -v codex >/dev/null || fail "codex not on PATH"
echo "codex: $(codex --version 2>/dev/null | head -1)"
status=$(codex login status 2>&1) || fail "codex is not logged in"
grep -qi chatgpt <<<"$status" || fail "codex must use the ChatGPT login, not an API key"
unset status
. "$(dirname "$0")/sandbox.sh"
probe=$(cd "$GITHUB_WORKSPACE" && timeout 60 codex sandbox "${CODEX_PERMISSION_ARGS[@]}" -- bash -c '
  head -c1 "$1/auth.json" >/dev/null 2>&1 && echo LOGIN_READABLE || echo login_denied
  ls "$2" >/dev/null 2>&1 && echo HOME_READABLE || echo home_denied
  head -c1 README.md >/dev/null 2>&1 && echo checkout_readable || echo CHECKOUT_DENIED
  touch .pr-review-probe 2>/dev/null && echo WRITABLE || echo write_denied
  (exec 3<>/dev/tcp/1.1.1.1/443) 2>/dev/null && echo NETWORK || echo network_denied
  [ "$PPID" -le 2 ] && echo pid_namespace || echo NO_PID_NAMESPACE
' probe "$codex_home" "$home" 2>/dev/null) || true
rm -f "$GITHUB_WORKSPACE/.pr-review-probe"
echo "sandbox probe:" $probe
[ "$(tr '\n' ' ' <<<"$probe")" = "login_denied home_denied checkout_readable write_denied network_denied pid_namespace " ] \
  || fail "the Codex sandbox does not isolate the login; refusing to review"
free=$(df -Pk "$RUNNER_TEMP" | awk 'NR==2{print $4}')
[ "${free:-0}" -ge 1048576 ] || fail "less than 1 GB free under the runner temp"
echo "pr-review preflight: ok"
