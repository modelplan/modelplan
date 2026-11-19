// SPDX-License-Identifier: MIT
// D314 item 2 (owner 2026-11-19): GitHub-hosted macOS legs no longer gate a merge. They waited 15-47 min for a runner,
// were cancelled and flaked on wall-clock timing (process review 11-19), stopping whole merge groups. They now run on
// every main commit and report through post-merge-hosted.yml (one `post-merge-red` issue), which never stops the line.
// Self-hosted legs (mac-compile, the native GUI leg, native-headless) and every Linux job stay required.
//
// Pure functions, no I/O; rules.mjs (ciState, queueCheckState) and post-merge.mjs use them.
//
// Why PR code cannot widen the exemption (a renamed or relabelled job stays required):
//  1. The table below is read from the default branch (merge-gates.yml checks out main), never from the PR.
//  2. A job is exempt only when ALL of these hold: its workflow path and job name are in the table, AND GitHub's own
//     job record says it ran (or is queued) on a GitHub-hosted macOS runner: runner group "GitHub Actions" and a
//     macos-* label, never a self-hosted label. So a table job that the owner's variables route to a self-hosted Mac
//     is required again, and a self-hosted job renamed to a table name is still on a self-hosted runner.
//  3. A PR (or any PR in a merge group) that changes a file under .github/workflows/ gets no exemption at all: the
//     job names, runner labels and needs: edges GitHub reports then come from main's workflow definitions. Without
//     this rule a PR could move native-headless into a table slot (rename + relabel to macos-latest) and pass.
//  4. No job may depend on a table job (tests/merge-gates-hosted.test.mjs reads main's workflows): a required job
//     that waited for a hosted leg could otherwise be not yet created when its run is judged.

export const HOSTED_RUNNER_GROUP = "GitHub Actions";

// Every GitHub-hosted macOS job that PRs or merge groups start, by workflow and display name (as the jobs and
// check-runs APIs name it; a reusable-workflow job is "<caller> / <called>"). `key` is the YAML job id, for the tests.
// Not here, so required whatever runner they get: desktop.yml native / native-hosted / native-owner-gui (the GUI leg),
// native-headless, and mac-compile.yml (a self-hosted check that reports as a commit status).
export const HOSTED_MAC_LEGS = Object.freeze([
  { workflow: ".github/workflows/ci.yml", key: "claude-code-macos", name: /^claude-code-macos$/ },
  { workflow: ".github/workflows/desktop.yml", key: "app-smoke", name: /^app-smoke$/ },
  { workflow: ".github/workflows/desktop.yml", key: "cockpit-spi-tests", name: /^cockpit-spi-tests$/ },
  { workflow: ".github/workflows/dock-host-port.yml", key: "contracts", name: /^contracts$/ },
  { workflow: ".github/workflows/e2e-journey.yml", key: "e2e-journey", name: /^e2e-journey$/ },
  { workflow: ".github/workflows/macos-distribution.yml", key: "neutral-build", name: /^neutral-build$/ },
  { workflow: ".github/workflows/official-dock.yml", key: "geometry", name: /^geometry$/ },
  { workflow: ".github/workflows/repo-checks.yml", key: "notices-macos", name: /^notices-macos$/ },
  { workflow: ".github/workflows/u10-candidate.yml", key: "candidate", name: /^candidate$/ },
  { workflow: ".github/workflows/u11-native.yml", key: "native", name: /^native \/ u11-native \(macos-15\)$/ },
  { workflow: ".github/workflows/u14-engine-drive.yml", key: "engine-drive", name: /^engine-drive \(macos-latest\)$/ },
  { workflow: ".github/workflows/u14-macos.yml", key: "macos-skeleton", name: /^macos-skeleton$/ },
  { workflow: ".github/workflows/u4-swift-wire.yml", key: "swift-decoder", name: /^swift-decoder$/ },
  { workflow: ".github/workflows/u4b-engine-client.yml", key: "transport", name: /^transport \(macos-latest\) \/ transport$/ },
  { workflow: ".github/workflows/u6-engine-store-core.yml", key: "sequences", name: /^sequences \(macos-latest\) \/ sequences$/ },
  { workflow: ".github/workflows/u7-credential-agent.yml", key: "fake-contract", name: /^fake-contract$/ },
  { workflow: ".github/workflows/u7-helper-producer.yml", key: "universal-helper", name: /^universal-helper$/ },
  { workflow: ".github/workflows/verification-pointer-helper.yml", key: "pointer-helper", name: /^pointer-helper$/ },
]);

export const HOSTED_WORKFLOWS = Object.freeze([...new Set(HOSTED_MAC_LEGS.map((l) => l.workflow))]);

// A path that can change job names, runner labels or needs: edges. Any workflow, not only the table's: reusable
// workflows (trusted-mac.yml) name the called jobs.
const WORKFLOW_RE = /^\.github\/workflows\//;
export const touchesWorkflows = (paths) => paths.some((p) => WORKFLOW_RE.test(p));

// GitHub's record of where a job runs. A started job carries its runner group; a queued one only the requested labels.
export function onHostedMac(job) {
  const labels = (job?.labels ?? []).map(String);
  if (!labels.length || labels.some((l) => /^self-hosted$/i.test(l))) return false;
  if (job.runner_group_name != null && job.runner_group_name !== HOSTED_RUNNER_GROUP) return false;
  return labels.some((l) => /^macos-/i.test(l));
}

// workflowPath: the run's `path` (a reusable call reports its caller's path); job: one jobs-API record.
export function isHostedMacLeg(workflowPath, job) {
  const path = String(workflowPath ?? "").split("@")[0];
  return !!job && HOSTED_MAC_LEGS.some((l) => l.workflow === path && l.name.test(String(job.name ?? ""))) && onHostedMac(job);
}

const OK = new Set(["success", "skipped", "neutral"]);

// The run's state with its hosted macOS legs set aside, or null when the jobs cannot decide it (no jobs read, an empty
// list, a startup failure, or no hosted leg involved at all): the caller then judges the whole run as before.
// Returns {state: "success"|"pending"|"failure", failed: [job names], waiting: [job names], hosted: [{name, state}]}.
export function runWithoutHostedLegs(run) {
  const jobs = run?.jobs;
  if (!Array.isArray(jobs) || !jobs.length || run.conclusion === "startup_failure") return null;
  const failed = [], waiting = [], hosted = [];
  for (const j of jobs) {
    if (isHostedMacLeg(run.path, j)) {
      const s = j.status !== "completed" ? "pending" : OK.has(j.conclusion) ? null : j.conclusion;
      if (s) hosted.push({ name: j.name, state: s });
      continue;
    }
    if (j.status !== "completed") waiting.push(j.name);
    else if (!OK.has(j.conclusion)) failed.push(`${j.name} ${j.conclusion}`);
  }
  if (!hosted.length) return null;
  // An unfinished run whose hosted leg has already finished is still running something else: wait for it.
  if (run.status !== "completed" && !hosted.some((h) => h.state === "pending")) return null;
  return { state: failed.length ? "failure" : waiting.length ? "pending" : "success", failed, waiting, hosted };
}

// The short "info:" phrase for set-aside legs (the status description holds 140 characters).
export function hostedInfo(hosted) {
  if (!hosted.length) return null;
  const shown = hosted.slice(0, 2).map((h) => `${h.name.split(" / ").pop()} ${h.state}`);
  return `post-merge only: ${shown.join(", ")}${hosted.length > 2 ? ` +${hosted.length - 2}` : ""}`;
}

// Check-run ids (= job ids) of the hosted legs among runs whose jobs were read; queueCheckState skips them.
export function hostedJobIds(runs) {
  const ids = new Set();
  for (const r of runs) for (const j of r.jobs ?? []) if (isHostedMacLeg(r.path, j)) ids.add(j.id);
  return ids;
}
