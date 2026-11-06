export const TRUSTED_MAC_ROUTE = "runs-on: ${{ ((inputs.task != 'native' || vars.MAC_CI_GUI == 'enabled') && (inputs.os == 'macos-latest' || inputs.os == 'macos-15') && (github.repository == 'modelplan/modelplan' && github.actor_id == '11829005' && github.actor == 'guanbear' && github.triggering_actor == 'guanbear') && (((github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.user.id == 11829005 && !github.event.pull_request.draft) || ((github.event_name == 'push' || github.event_name == 'workflow_dispatch') && startsWith(github.ref, 'refs/heads/')))) && (contains(fromJSON(vars.MAC_CI_RUNNER_V2 == 'self-hosted' && '[\"native\",\"native-headless\",\"transport\",\"sequences\"]' || vars.MAC_CI_RUNNER_V2 == 'split' && '[\"native\",\"native-headless\",\"transport\",\"sequences\",\"u11-native\",\"dock-host-port\",\"u14-drive\",\"u10-candidate\",\"distribution\"]' || '[]'), inputs.task) || ((inputs.task == 'probe' || inputs.task == 'gui-probe') && github.event_name == 'workflow_dispatch'))) && fromJSON((inputs.task == 'native' || inputs.task == 'gui-probe') && '[\"self-hosted\",\"macOS\",\"ARM64\",\"modelplan-mac\",\"modelplan-mac-gui\"]' || '[\"self-hosted\",\"macOS\",\"ARM64\",\"modelplan-mac\"]') || (inputs.os == 'ubuntu-latest' && 'ubuntu-24.04' || inputs.os == 'macos-14' && 'macos-14' || inputs.os == 'macos-15' && 'macos-15' || 'macos-latest') }}";
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

// macOS hosted-runner capacity (11-05, R6a/R8a; shape fixed per MACREV2 review of #579 at 0a3a4594,
// findings macrev2-579-1/2): every workflow that starts macOS jobs on pull_request/push must key its
// concurrency group on the workflow + PR number and cancel only pull_request heads. A non-PR run
// (main push, tag, candidate/manual dispatch) gets the run's own id in the group, so protected runs
// are alone in their group: GitHub can neither cancel them nor silently replace a queued one. The
// per-commit `github.sha` fallback is NOT accepted: a workflow_dispatch on the same commit shares
// the push run's group, and a ref-keyed group with cancel-in-progress:false still drops queued
// protected runs (GitHub keeps a single pending invocation). Workflows triggered only by
// workflow_dispatch or workflow_call are out of scope.
const CANCEL_PR_ONLY = /\$\{\{\s*github\.event_name\s*==\s*'pull_request'\s*\}\}/;
const PR_GROUP = "github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id";

function topLevelBlock(text, key) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => new RegExp(`^["']?${key}["']?:`).test(l));
  if (start === -1) return null;
  const end = lines.findIndex((l, i) => i > start && /^[A-Za-z_"'-]+:/.test(l));
  return lines.slice(start, end === -1 ? lines.length : end).join("\n");
}

// Every form a macOS job's runner selection takes in .github/workflows (macrevb-579-3):
// 1. a literal `runs-on: macos-*` (or any runs-on line naming macOS);
// 2. an inline os list naming macOS (`os: [ubuntu-latest, macos-latest]`);
// 3. block-sequence matrix entries naming macOS (`os:` followed by `- macos-latest`, desktop.yml);
// 4. a dynamic os/matrix expression of ANY shape — `fromJSON(` at the start of the expression
//    (notices/u4b/u6 collapse), leading conditions before it (`ci.yml`:
//    `os: ${{ (github.event_name == ...) && fromJSON('["ubuntu-latest"]') || fromJSON(..., "macos-latest") }}`),
//    either spelling (fromJSON/fromJson), or a matrix forwarded from a job output
//    (`matrix: ${{ needs.x.outputs.matrix }}`);
// 5. the reusable macOS lane (`uses: .../trusted-mac.yml`).
// The last line is fail-closed: a workflow that merely mentions macOS (even in a comment)
// requires the concurrency shape, so no future expression form can escape the policy.
function runsMacos(text) {
  if (/^\s*runs-on:[^\n]*macos/im.test(text)) return true;
  if (/^\s*(?:os|platform):[^\n]*macos/im.test(text)) return true;
  if (/^\s*-\s*[^\n]*macos/im.test(text) && /^\s*(?:os|platform|matrix):\s*$/im.test(text)) return true;
  if (/^\s*(?:os|platform|matrix):\s*\$\{/im.test(text)) return true;
  if (/matrix:\s*\$\{/im.test(text)) return true;
  if (/uses:[^\n]*workflows\/trusted-mac\.yml/.test(text)) return true;
  return /macos/i.test(text);
}

export function macConcurrencyProblems(text) {
  const problems = [];
  const on = topLevelBlock(text, "on");
  if (!on || !/\b(pull_request|push)\b/.test(on) || !runsMacos(text)) return problems;
  const conc = topLevelBlock(text, "concurrency");
  if (!conc || !/^\s+group:/m.test(conc)) {
    problems.push('macOS workflow has no concurrency group (group: <workflow>-${{ github.event.pull_request.number && format(\'pr-{0}\', github.event.pull_request.number) || github.run_id }})');
    return problems;
  }
  const groupLine = conc.split("\n").find((l) => /^\s+group:/.test(l)) ?? "";
  const cancelLine = conc.split("\n").find((l) => /^\s+cancel-in-progress:/.test(l)) ?? "";
  if (!groupLine.includes(PR_GROUP)) {
    problems.push('concurrency group must be "<workflow>-${{ github.event.pull_request.number && format(\'pr-{0}\', github.event.pull_request.number) || github.run_id }}": only PR heads share a group and every protected (main/tag/dispatch) run is unique, so it can neither be cancelled nor queued away');
  }
  if (!CANCEL_PR_ONLY.test(cancelLine)) {
    problems.push("cancel-in-progress must be exactly the pull_request-only expression (main and release runs are never cancelled and never queued behind each other)");
  }
  return problems;
}

// Draft PRs iterate locally (queue rule, 11-05 round 8): a workflow with a pull_request
// trigger must not start macOS jobs for a draft head. Every job that starts macOS jobs
// carries a draft guard (the standard `if: github.event_name != 'pull_request' ||
// !github.event.pull_request.draft`, a dispatch-only if, or a matrix that collapses to
// ubuntu on drafts — the u6-engine-store-core pattern), and the workflow keeps a
// `workflow_dispatch:` trigger so a lane can still request Mac CI for a draft head
// (a lane can still request Mac CI for a draft head through the workflow_dispatch trigger).
function jobBlocks(text) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => /^jobs:/.test(l));
  if (start === -1) return [];
  const jobs = [];
  let cur = null;
  for (const line of lines.slice(start + 1)) {
    if (/^[A-Za-z_"'-]+:/.test(line)) break;               // next top-level key: jobs section ended
    const job = /^  ([A-Za-z][\w-]*):\s*$/.exec(line);      // exactly 2-space indent: a job name
    if (job) { cur = { name: job[1], lines: [] }; jobs.push(cur); continue; }
    if (cur) cur.lines.push(line);
  }
  return jobs;
}

const STANDARD_GUARD = "github.event_name != 'pull_request' || !github.event.pull_request.draft";
const DISPATCH_OR_NOT_DRAFT = "github.event_name == 'workflow_dispatch' || !github.event.pull_request.draft";
const DISPATCH_ONLY_IF = /^\s*if:.*github\.event_name\s*==\s*'workflow_dispatch'/;  // a dispatch-only gate (extra owner conditions after it are fine)

function jobRunsMacos(lines) {
  // Same forms as runsMacos() above, scoped to one job's lines (macrevb-579-3); a
  // block-sequence matrix entry is recognised at the file level, and a trusted-mac
  // caller is always a macOS job regardless of its own runner lines.
  return lines.some((l) => /^\s*runs-on:[^\n]*macos/i.test(l))
    || lines.some((l) => /^\s*(?:os|platform):[^\n]*macos/i.test(l))
    || lines.some((l) => /^\s*(?:os|platform|matrix):\s*\$\{/i.test(l))
    || lines.some((l) => /uses:[^\n]*workflows\/trusted-mac\.yml/.test(l));
}

function jobDraftGuarded(lines) {
  // Meaning, not the presence of "draft" text: `github.event_name == 'pull_request' ||
  // !github.event.pull_request.draft` is always true on pull_request events (it would run drafts),
  // and a bare `if: github.event.pull_request.draft` runs ONLY drafts — both are rejections.
  return lines.some((l) => l.includes(STANDARD_GUARD))                              // the standard guard, also inside a larger conjunction
    || lines.some((l) => l.includes(DISPATCH_OR_NOT_DRAFT))                         // dispatch-or-ready (u14-macos shape)
    // a matrix collapse is a draft guard only when the DRAFT branch is ubuntu-only
    // (macrevb-579-3: a collapse whose both branches contain macOS runs macOS on drafts)
    || lines.some((l) => /^\s*os:[^\n]*github\.event\.pull_request\.draft[^\n]*&&\s*(?:fromJSON\(\s*)?'\["ubuntu-latest"\]'/i.test(l))
    || lines.some((l) => DISPATCH_ONLY_IF.test(l));                                  // dispatch-only job
}

export function draftGuardProblems(text) {
  const problems = [];
  const on = topLevelBlock(text, "on");
  if (!on || !/\bpull_request\b/.test(on) || !runsMacos(text)) return problems;
  if (!/\bworkflow_dispatch:/.test(on)) {
    problems.push("workflow_dispatch missing: without the manual trigger a lane cannot request Mac CI for a draft head");
  }
  for (const job of jobBlocks(text)) {
    if (!jobRunsMacos(job.lines)) continue;
    if (!jobDraftGuarded(job.lines)) {
      problems.push(`macOS job ${job.name} runs on draft PRs; add "if: github.event_name != 'pull_request' || !github.event.pull_request.draft" (or collapse the matrix to ubuntu on drafts)`);
    }
  }
  return problems;
}

// Actions cost control (R71, owner 11-06): hosted Mac minutes are capped and the dedicated
// pool is small, so the reusable-Mac callers must stay a single, reviewable population:
// every caller pins the SAME immutable trusted-mac.yml commit (a stale pin re-admits an old
// definition, as the merged-but-unpinned receipt change in #604 showed), every literal task
// selector a caller passes exists in trusted-mac.yml, and no workflow requests the same task
// twice — one PR run must never book the same Mac job on both pools.
export function trustedMacPins(text) {
  return [...text.matchAll(/uses:\s*modelplan\/modelplan\/\.github\/workflows\/trusted-mac\.yml@(\S+)/g)].map((m) => m[1]);
}

export function trustedMacTaskSelectors(text) {
  // Literal `task:` inputs only; expression-valued tasks (desktop's probe mode) carry no
  // static name and are checked by the reusable workflow itself.
  return [...text.matchAll(/^[ \t]*task:[ \t]*([a-z0-9-]+)[ \t]*$/gm)].map((m) => m[1]);
}

export function trustedMacCostProblems(files, trustedMacPath = ".github/workflows/trusted-mac.yml") {
  const problems = [];
  const trusted = files.get(trustedMacPath) ?? "";
  const defined = new Set([...trusted.matchAll(/inputs\.task == '([a-z0-9-]+)'/g)].map((m) => m[1]));
  const pins = new Set();
  for (const [path, text] of files) {
    const filePins = trustedMacPins(text);
    for (const pin of filePins) {
      pins.add(pin);
      if (!/^[0-9a-f]{40}$/.test(pin)) problems.push(`${path}: trusted-mac.yml pin "${pin}" is not an immutable 40-hex commit`);
    }
    if (path === trustedMacPath || filePins.length === 0) continue;
    const seen = new Set();
    for (const task of trustedMacTaskSelectors(text)) {
      if (!defined.has(task)) problems.push(`${path}: trusted-mac task "${task}" is not defined in ${trustedMacPath}`);
      if (seen.has(task)) problems.push(`${path}: requests trusted-mac task "${task}" twice — one run must never book the same Mac job on both pools`);
      seen.add(task);
    }
  }
  if (pins.size > 1) problems.push(`trusted-mac.yml callers pin ${pins.size} different commits (${[...pins].join(", ")}); all callers must move to the same reviewed pin together`);
  return problems;
}
