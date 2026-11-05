export const TRUSTED_MAC_ROUTE = "runs-on: ${{ ((inputs.task != 'native' || vars.MAC_CI_GUI == 'enabled') && inputs.os == 'macos-latest' && (github.repository == 'modelplan/modelplan' && github.actor_id == '11829005' && github.actor == 'guanbear' && github.triggering_actor == 'guanbear') && (((github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.user.id == 11829005 && !github.event.pull_request.draft) || ((github.event_name == 'push' || github.event_name == 'workflow_dispatch') && startsWith(github.ref, 'refs/heads/')))) && (vars.MAC_CI_RUNNER_V2 == 'self-hosted' || ((inputs.task == 'probe' || inputs.task == 'gui-probe') && github.event_name == 'workflow_dispatch'))) && fromJSON((inputs.task == 'native' || inputs.task == 'gui-probe') && '[\"self-hosted\",\"macOS\",\"ARM64\",\"modelplan-mac\",\"modelplan-mac-gui\"]' || '[\"self-hosted\",\"macOS\",\"ARM64\",\"modelplan-mac\"]') || (inputs.os == 'ubuntu-latest' && 'ubuntu-24.04' || inputs.os == 'macos-14' && 'macos-14' || 'macos-latest') }}";
// SPDX-License-Identifier: MIT
// Runner and trigger rules for public workflows. Defence in depth only: the enforced boundaries
// are the immutable reusable workflow selected by the runner group and the owner-only pre-job gate.
//
// Exact routing allow-list, scoped to the trusted reusable workflow. Callers cannot
// select these runners directly. Other triggers, OR bypasses and constructed
// selectors fail; escaped YAML spellings are checked too.
export const ALLOWED_ROUTES = new Set();

// GitHub runs top-level .yml and .yaml files under .github/workflows/.
export function isWorkflowFile(path) {
  return /^\.github\/workflows\/[^/]+\.ya?ml$/.test(path);
}

// YAML double-quoted scalars may spell a key with escapes ("pull_request_tar\u0067et") or split it
// over an escaped line break. Checking the decoded text as well closes that gap without a YAML
// parser; decoding only ever adds lines to check, so ordinary shell and regex backslashes stay legal.
function decodedVariant(text) {
  return text
    .replace(/\\\r?\n[ \t]*/g, "")
    .replace(/\\(?:x([0-9a-fA-F]{2})|u([0-9a-fA-F]{4})|U([0-9a-fA-F]{8}))/g,
      (_, x, u, U) => String.fromCodePoint(parseInt(x || u || U, 16)));
}

function lineProblems(raw, problems) {
  const line = raw.trim();
  if (/modelplans-(publish|ci)/.test(line)) problems.add("private runner label");
  if (/^runs-on:.*\b(format|join)\(/.test(line)) problems.add("dynamically constructed runner label");
  if ((line.includes("self-hosted") || line.includes("pull_request_target")) && !ALLOWED_ROUTES.has(line))
    problems.add("non-canonical self-hosted route or pull_request_target");
}

export function workflowProblems(text, path = "") {
  const problems = new Set();
  const check = (raw) => {
    if (path === ".github/workflows/trusted-mac.yml" && raw.trim() === TRUSTED_MAC_ROUTE) return;
    lineProblems(raw, problems);
  };
  for (const raw of text.split("\n")) check(raw);
  if (text.includes("\\")) for (const raw of decodedVariant(text).split("\n")) check(raw);
  return [...problems];
}

// macOS hosted-runner capacity (11-05): every workflow that starts macOS jobs on pull_request/push
// must keep a concurrency group keyed on the workflow + PR number/ref so a newer head cancels the
// superseded run instead of queueing it behind it in the hosted macOS queue. Main and release runs
// are never cancelled: either cancel-in-progress is the pull_request-only expression, or it is a
// literal true with a group that falls back to a per-commit `github.sha` (so main/tag runs each get
// their own group and nothing cancels them). Workflows triggered only by workflow_dispatch or
// workflow_call are out of scope.
const CANCEL_PR_ONLY = /\$\{\{\s*github\.event_name\s*==\s*'pull_request'\s*\}\}/;

function topLevelBlock(text, key) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => new RegExp(`^${key}:`).test(l));
  if (start === -1) return null;
  const end = lines.findIndex((l, i) => i > start && /^[A-Za-z_"'-]+:/.test(l));
  return lines.slice(start, end === -1 ? lines.length : end).join("\n");
}

function runsMacos(text) {
  if (/^\s*runs-on:.*macos/m.test(text)) return true;
  if (/^\s*(?:os|platform):\s*\[[^\]]*macos/m.test(text)) return true;
  if (/uses:.*workflows\/trusted-mac\.yml/.test(text)) return true;
  return false;
}

export function macConcurrencyProblems(text) {
  const problems = [];
  const on = topLevelBlock(text, "on");
  if (!on || !/\b(pull_request|push)\b/.test(on) || !runsMacos(text)) return problems;
  const conc = topLevelBlock(text, "concurrency");
  if (!conc || !/^\s+group:/m.test(conc)) {
    problems.push("macOS workflow has no concurrency group (group: <workflow>-${{ github.event.pull_request.number || github.ref }})");
    return problems;
  }
  const groupLine = conc.split("\n").find((l) => /^\s+group:/.test(l)) ?? "";
  const cancelLine = conc.split("\n").find((l) => /^\s+cancel-in-progress:/.test(l)) ?? "";
  if (!groupLine.includes("github.event.pull_request.number")) {
    problems.push("concurrency group must be keyed on the PR number (or per-commit sha for main/release)");
  }
  const prOnly = CANCEL_PR_ONLY.test(cancelLine);
  const shaScoped = /cancel-in-progress:\s*true\s*$/.test(cancelLine) && groupLine.includes("|| github.sha");
  if (!prOnly && !shaScoped) {
    problems.push("cancel-in-progress must be true only for pull_request heads (main and release runs are never cancelled)");
  }
  return problems;
}
