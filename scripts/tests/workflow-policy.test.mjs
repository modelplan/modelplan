// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { ALLOWED_ROUTES, GUI_LEND_GUARD, MAC_COMPILE_IF, MAC_COMPILE_PATH, MAC_COMPILE_ROUTE, MAC_COMPILE_TRIGGER_PATH, NONGUI_JOBS, RUNNER_SMOKE_IF, RUNNER_SMOKE_PATH, RUNNER_SMOKE_ROUTE, runnerSmokeProblems, TRUSTED_MAC_ROUTE, draftGuardProblems, guiGuardProblems, isWorkflowFile, macCompileProblems, macCompileTriggerProblems, macConcurrencyProblems, macPathGateProblems, nonPrFilterProblems, parseWorkflowYaml, prCancelProblems, runnerSmokeNameLeakProblems, workflowProblems } from "../workflow-policy.mjs";
import { spawnSync } from "node:child_process";

// PyYAML is optional locally and on hosted images; repo-checks installs it and sets MODELPLAN_REQUIRE_YAML=1, where an
// unavailable parser is itself a failure. The structural (parsed) assertions run only when it is present.
const HAVE_YAML = !parseWorkflowYaml("a: 1").unavailable;

test("trusted Mac route is confined to the reviewed reusable workflow path", () => {
  const text = `jobs:\n  check:\n    ${TRUSTED_MAC_ROUTE}\n`;
  assert.deepEqual(workflowProblems(text, ".github/workflows/trusted-mac.yml"), []);
  assert.ok(workflowProblems(text, ".github/workflows/attacker.yml").length > 0);
  assert.ok(workflowProblems(text.replace("github.actor_id == '11829005'", "true"), ".github/workflows/trusted-mac.yml").length > 0);
  assert.ok(workflowProblems(text.replace("github.event.pull_request.head.repo.full_name == github.repository", "true"), ".github/workflows/trusted-mac.yml").length > 0);
  assert.ok(workflowProblems(text.replace("inputs.os == 'macos-latest'", "true"), ".github/workflows/trusted-mac.yml").length > 0);
});

const GUARD = "vars.MAC_CI_RUNNER == 'self-hosted' && github.event_name != 'pull_request_target' && (github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)";
const ROUTED = "jobs:\n" + [...ALLOWED_ROUTES].map((r, i) => `  j${i}:\n    ${r}\n`).join("");

test("accepts hosted runners and ordinary pull_request triggers", () => {
  assert.deepEqual(workflowProblems("on: pull_request\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  assert.deepEqual(workflowProblems("on:\n  push:\n  pull_request:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.ok(workflowProblems(`runs-on: \${{ (${GUARD}) && fromJSON('["self-hosted","macOS","ARM64","modelplan-mac"]') || 'macos-latest' }}`).length > 0);
});

test("rejects pull_request_target in every YAML form", () => {
  for (const on of ["on: pull_request_target", "on:\n  pull_request_target:", "on: { pull_request_target: {} }",
    "on: [push, pull_request_target]", "on:\n  - pull_request_target"]) {
    assert.ok(workflowProblems(on + "\njobs:\n  a:\n    runs-on: ubuntu-latest\n").includes("non-canonical self-hosted route or pull_request_target"), on);
  }
});

test("rejects unguarded self-hosted selection even with guard strings in a comment", () => {
  const sneaky = `jobs:\n  a:\n    runs-on: [self-hosted, macOS, ARM64, modelplan-mac] # ${GUARD} github.event.pull_request.head.repo.full_name == github.repository\n`;
  assert.ok(workflowProblems(sneaky).includes("non-canonical self-hosted route or pull_request_target"));
});

test("rejects private labels, literal or dynamically constructed", () => {
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: modelplans-publish\n").includes("private runner label"));
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: ${{ format('{0}{1}', 'modelplans-', 'publish') }}\n").includes("dynamically constructed runner label"));
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: ${{ join(fromJSON('[\"modelplans\",\"ci\"]'), '-') }}\n").includes("dynamically constructed runner label"));
});

test("rejects guard look-alikes: branch filters, OR-bypass, quoted keys", () => {
  const bad = [
    `on: { pull_request_target: { types: [opened], branches: [main, "github.event_name != 'pull_request_target'"] } }`,
    `on:\n  "pull_request_target":`,
    `jobs:\n  a:\n    runs-on: \${{ (${GUARD} || true) && fromJSON('["self-hosted","macOS","ARM64","modelplan-mac"]') || 'macos-latest' }}`,
  ];
  for (const t of bad) assert.ok(workflowProblems(t).includes("non-canonical self-hosted route or pull_request_target"), t);
});

test("rejects escaped spellings that a YAML parser decodes to the forbidden names", () => {
  for (const t of [
    'on:\n  "pull_request_tar\\u0067et":',
    'on:\n  "pull_request\\x5ftarget":',
    'on:\n  "pull_request_\\\n    target":',
    'jobs:\n  a:\n    runs-on: "self\\u002dhosted"',
    'jobs:\n  a:\n    runs-on: "modelplans\\u002dci"',
  ]) assert.ok(workflowProblems(t).length > 0, t);
});

test("ordinary shell and regex backslashes stay legal", () => {
  const run = 'jobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - run: |\n          go build -ldflags "-s -w" \\\n            ./cmd\n          python3 -c \'import re; re.findall(r"\\d+", "v1")\'\n';
  assert.deepEqual(workflowProblems(run), []);
});

test("both workflow extensions are checked", () => {
  assert.ok(isWorkflowFile(".github/workflows/ci.yml"));
  assert.ok(isWorkflowFile(".github/workflows/ci.yaml"));
  assert.ok(!isWorkflowFile(".github/workflows/nested/ci.yml"));
  assert.ok(!isWorkflowFile(".github/workflows/README.md"));
});

test("macOS workflows on pull_request/push cancel superseded PR heads but never main or release runs", () => {
  const group = "concurrency:\n  group: dist-${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n";
  // compliant: PR heads share the pr-N group and cancel the superseded run
  assert.deepEqual(macConcurrencyProblems(`on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: macos-latest\n`), []);
  // matrix os and trusted-mac callers count as macOS starters
  assert.deepEqual(macConcurrencyProblems(`on: pull_request\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: \${{ matrix.os }}\n    strategy:\n      matrix:\n        os: [ubuntu-latest, macos-latest]\n`), []);
  assert.deepEqual(macConcurrencyProblems(`on: pull_request\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    uses: modelplan/modelplan/.github/workflows/trusted-mac.yml@8a22050adc0cbcc85e4159e54cbd50647245b6c0\n`), []);
  // violations: no group at all, the queueing literal false, the cancelling literal true (either group
  // shape — a ref group cancels main runs; a sha group collides with a same-commit dispatch), and a
  // group without the unique run-id fallback
  for (const bad of ["on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: macos-latest\n",
                     `on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: false\njobs:\n  a:\n    runs-on: macos-latest\n`,
                     `on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: true\njobs:\n  a:\n    runs-on: macos-latest\n`,
                     "on:\n  pull_request:\n  push:\nconcurrency:\n  group: dist-${{ github.event.pull_request.number || github.sha }}\n  cancel-in-progress: true\njobs:\n  a:\n    runs-on: macos-latest\n",
                     "on:\n  pull_request:\n  push:\nconcurrency:\n  group: dist-${{ github.event.pull_request.number || github.ref }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: macos-latest\n"]) {
    assert.ok(macConcurrencyProblems(bad).length > 0, bad);
  }
});

test("a branch dispatch may dedupe per branch, but main, release and tag runs stay unique", () => {
  const D = "github.event_name == 'workflow_dispatch' && github.ref_type == 'branch' && github.ref != 'refs/heads/main' && !startsWith(github.ref, 'refs/heads/release')";
  const wf = (g, c) => `on:\n  pull_request:\n  push:\n  workflow_dispatch:\nconcurrency:\n  group: dist-\${{ ${g} }}\n  cancel-in-progress: \${{ ${c} }}\njobs:\n  a:\n    runs-on: macos-latest\n`;
  const pr = "github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number)";
  assert.deepEqual(macConcurrencyProblems(wf(`${pr} || (${D} && format('dispatch-{0}', github.ref)) || github.run_id`, `github.event_name == 'pull_request' || (${D})`)), []);
  // a dedupe that would also cancel main/tag dispatches is rejected
  const loose = "github.event_name == 'workflow_dispatch'";
  assert.ok(macConcurrencyProblems(wf(`${pr} || (${D} && format('dispatch-{0}', github.ref)) || github.run_id`, `github.event_name == 'pull_request' || (${loose})`)).length > 0);
  assert.ok(macConcurrencyProblems(wf(`${pr} || (${loose} && format('dispatch-{0}', github.ref)) || github.run_id`, `github.event_name == 'pull_request' || (${D})`)).length > 0);
});

test("non-macOS and non-PR/push workflows are outside the concurrency rule", () => {
  assert.deepEqual(macConcurrencyProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_dispatch:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
});

test("every macOS-running workflow in this repository carries the concurrency group", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of fs.readdirSync(dir)) {
    if (!/\.(ya?ml)$/.test(f)) continue;
    const text = fs.readFileSync(new URL(f, dir), "utf8");
    assert.deepEqual(macConcurrencyProblems(text), [], f);
  }
});

test("macOS jobs on pull_request are draft-guarded (or dispatch-only) and the workflow keeps workflow_dispatch", () => {
  const on = "on:\n  pull_request:\n  push:\n  workflow_dispatch:\n";
  const guarded = (job) => `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n${job}`;
  // compliant: the standard guard
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    if: github.event_name != 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n")), []);
  // compliant: dispatch-only job, and a matrix that collapses to ubuntu on drafts
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    if: github.event_name == 'workflow_dispatch'\n    runs-on: macos-latest\n")), []);
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    strategy:\n      matrix:\n        os: ${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '[\"ubuntu-latest\"]' || '[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n")), []);
  // violations: an unguarded macOS job, and a missing workflow_dispatch trigger
  assert.ok(draftGuardProblems(guarded("  a:\n    runs-on: macos-latest\n")).some((p) => p.includes("macOS job a")), "unguarded job");
  assert.ok(draftGuardProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    if: github.event_name != 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n").some((p) => p.includes("workflow_dispatch missing")), "missing dispatch trigger");
  // ubuntu-only and workflow_call-only workflows are outside the rule
  assert.deepEqual(draftGuardProblems("on:\n  pull_request:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.deepEqual(draftGuardProblems("on:\n  workflow_call:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
});

test("every macOS workflow in this repository draft-guards its jobs and keeps a dispatch trigger", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of fs.readdirSync(dir)) {
    if (!/\.(ya?ml)$/.test(f)) continue;
    const text = fs.readFileSync(new URL(f, dir), "utf8");
    assert.deepEqual(draftGuardProblems(text), [], f);
  }
});

test("macrev2-579-3 regressions: quoted on-keys, dynamic fromJSON matrices and reversed draft guards", () => {
  // a quoted "on" key must not escape the concurrency or draft checks
  const quoted = `"on":\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: macos-latest\n`;
  assert.ok(macConcurrencyProblems(quoted).length > 0, "quoted on key escaped the concurrency check");
  assert.ok(draftGuardProblems(quoted).length > 0, "quoted on key escaped the draft check");
  // a dynamic fromJSON matrix is a macOS starter even without a literal macos runs-on
  const dyn = `on:\n  pull_request:\n  push:\nconcurrency:\n  group: g-\${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    strategy:\n      matrix:\n        os: \${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '[\"ubuntu-latest\"]' || '[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: \${{ matrix.os }}\n`;
  assert.deepEqual(macConcurrencyProblems(dyn), []);
  // reversed polarity: runs only on drafts, and the OR form is always true on pull_request events
  const rev1 = `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    if: github.event.pull_request.draft\n    runs-on: macos-latest\n`;
  const rev2 = `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    if: github.event_name == 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n`;
  for (const bad of [rev1, rev2]) {
    assert.ok(draftGuardProblems(bad).some((p) => p.includes("macOS job a")), bad);
  }
});

test("macrevb-579-3 regressions: every matrix/runs-on expression form is recognised as macOS", () => {
  const group = "concurrency:\n  group: g-\${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\n";
  const compliant = (jobs) => macConcurrencyProblems(`on:\n  pull_request:\n  push:\n${group}jobs:\n${jobs}`);
  // form 3: block-sequence matrix entries (desktop.yml's native caller)
  assert.deepEqual(compliant("  a:\n    strategy:\n      fail-fast: false\n      matrix:\n        os:\n        - macos-latest\n    uses: modelplan/modelplan/.github/workflows/trusted-mac.yml@8a22050adc0cbcc85e4159e54cbd50647245b6c0\n    with:\n      task: native\n      os: ${{ matrix.os }}\n"), []);
  // form 4a: a dynamic os expression with leading conditions BEFORE fromJSON (ci.yml's collapse) is
  // recognised — with the correct group it is compliant, and without any group it is flagged
  const ciCollapse = "  a:\n    strategy:\n      matrix:\n        os: ${{ (github.event_name == 'merge_group' || (github.event_name == 'pull_request' && github.event.pull_request.draft)) && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n";
  assert.deepEqual(compliant(ciCollapse), []);
  assert.ok(macConcurrencyProblems(`on:\n  pull_request:\n  push:\njobs:\n${ciCollapse}`).length > 0, "ci.yml's collapse form escaped the concurrency policy");
  // form 4b: a matrix forwarded from a job output, and the lowercase fromJson spelling
  assert.deepEqual(compliant("  a:\n    strategy:\n      matrix: ${{ needs.wf.outputs.matrix }}\n    runs-on: ${{ matrix.os }}\n"), []);
  assert.deepEqual(compliant("  a:\n    strategy:\n      matrix:\n        os: ${{ fromJson(needs.wf.outputs.matrix) }}\n    runs-on: ${{ matrix.os }}\n"), []);
  // fail-closed backstop: a macOS mention anywhere (even only in a comment) requires the group
  assert.ok(macConcurrencyProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: ubuntu-latest # macOS runners are scarce\n").length > 0, "a macOS mention escaped the policy");
  // workflow_call-only and workflow_dispatch-only files stay outside the rule even when they mention macOS
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_call:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_dispatch:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  // a collapse whose both branches contain macOS is NOT a draft guard (macrevb-579-3's draft
  // control flips the Linux branch to Mac); only an ubuntu-only draft branch counts, and a
  // collapse without any draft clause (e.g. merge_group-only ubuntu) still runs macOS on drafts
  // and is flagged
  const allMac = "on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ github.event.pull_request.draft && fromJSON('[\"macos-latest\"]') || fromJSON('[\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n";
  assert.ok(draftGuardProblems(allMac).length > 0, "an all-Mac collapse escaped the draft guard");
  assert.deepEqual(draftGuardProblems("on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ github.event.pull_request.draft && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n"), []);
  assert.ok(draftGuardProblems("on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ (github.event_name == 'merge_group') && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n").length > 0, "a merge_group-only ubuntu branch still runs macOS on drafts");
});
test("v1 install guide matches the supported package and update policy", async () => {
  const { readFile } = await import("node:fs/promises");
  const guide = await readFile(new URL("../../docs/install-beta.md", import.meta.url), "utf8");
  const obsolete = /\buniversal\b|\bmacOS\s*14\b|\bSparkle\b|\bappcast\b/i;
  for (const stale of ["universal", "macOS 14", "Sparkle", "appcast"]) {
    assert.match(stale, obsolete);
  }
  assert.doesNotMatch(guide, obsolete);
  assert.match(guide, /Apple silicon only/i);
  assert.match(guide, /macOS 15 or later/i);
  assert.match(guide, /no automatic updates/i);
  assert.match(guide, /no update feed/i);
});

test("U11 may use the ordinary owner Macs, never the GUI Mac, with the same owner gate and a hosted macos-15 fallback (D62)", () => {
  const route = TRUSTED_MAC_ROUTE;
  const branch = /\(inputs\.task == 'u11-native' && inputs\.os == 'macos-15' && vars\.MAC_CI_NONGUI == 'enabled' && (.*?)\) && fromJSON\('(\[[^\]]*\])'\)/.exec(route);
  assert.ok(branch, "the non-GUI branch is selected by the MAC_CI_NONGUI variable");
  assert.deepEqual(JSON.parse(branch[2]), ["self-hosted", "macOS", "ARM64", "modelplan-mac-nongui"], "only the non-GUI label, which the GUI Mac does not carry");
  for (const gate of ["github.actor_id == '11829005'", "github.triggering_actor == 'guanbear'", "github.event.pull_request.head.repo.full_name == github.repository",
    "!github.event.pull_request.draft", "startsWith(github.ref, 'refs/heads/')"]) assert.ok(branch[1].includes(gate), gate);
  assert.ok(route.includes("inputs.os == 'macos-15' && 'macos-15'"), "hosted fallback keeps macos-15, the oldest supported macOS");
  // The GUI branch still needs inputs.os == 'macos-latest', which the U11 caller never passes.
  const caller = fs.readFileSync(new URL("../../.github/workflows/u11-native.yml", import.meta.url), "utf8");
  assert.match(caller, /uses: modelplan\/modelplan\/\.github\/workflows\/trusted-mac\.yml@[0-9a-f]{40}\n/);
  assert.match(caller, /task: u11-native\n/);
  assert.match(caller, /os: macos-15\n/);
  assert.doesNotMatch(caller, /runs-on:/);
  const reusable = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  const job = reusable.split("\n  u11-native:\n")[1].split("\n  probe:\n")[0];
  assert.match(job, /\*gui\*\) echo "::error::/, "the job refuses a GUI runner even if a label is misassigned");
  assert.match(job, /persist-credentials: false/);
  assert.match(job, /echo "HOME=\$base\/home"/, "home and caches live in the job's runner temp");
  assert.match(job, /if: always\(\)\n\s+shell: bash\n\s+run: \|\n(?:\s+#.*\n)?\s+chmod -R u\+w -- "\$RUNNER_TEMP\/u11-isolated".*\n\s+rm -rf -- \.tmp /, "Go's read-only module cache is made writable before removal");
});

test("every owner-Mac route that is not a GUI task needs modelplan-mac-nongui, so the GUI Mac only runs GUI jobs", () => {
  const arrays = [...TRUSTED_MAC_ROUTE.matchAll(/'(\["self-hosted"[^\]]*\])'/g)].map((m) => JSON.parse(m[1]));
  assert.ok(arrays.length >= 3);
  for (const labels of arrays) {
    const gui = labels.includes("modelplan-mac-gui");
    assert.ok(gui || labels.includes("modelplan-mac-nongui"), JSON.stringify(labels));
    if (gui) assert.ok(!labels.includes("modelplan-mac-nongui"));
  }
  const gui = /\(inputs\.task == 'native' \|\| inputs\.task == 'native-owner-gui' \|\| inputs\.task == 'gui-probe'\) && '(\[[^\]]*\])'/.exec(TRUSTED_MAC_ROUTE);
  assert.ok(gui && JSON.parse(gui[1]).includes("modelplan-mac-gui"), "only native, native-owner-gui and gui-probe take the GUI label");
  // The hosted GUI split never reaches an owner Mac: it is excluded from the owner branch, and its caller passes macos-15.
  assert.ok(TRUSTED_MAC_ROUTE.includes("inputs.os == 'macos-latest' && inputs.task != 'native-hosted-gui' && (inputs.task != 'native-headless' || (github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main')) &&"));
  // D198 for every event but the main-dispatch seed publish; D246 (merge queue on the owner Macs) was reverted.

  const headless = TRUSTED_MAC_ROUTE.split("|| (inputs.os == 'ubuntu-latest'")[0].split("native-headless").length - 1;
  assert.equal(headless, 1, "native-headless appears only in the main-dispatch exception");
  assert.ok(TRUSTED_MAC_ROUTE.includes("(inputs.task != 'native-headless' || (github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'))"));
  assert.ok(TRUSTED_MAC_ROUTE.includes("((inputs.task != 'native' && inputs.task != 'native-owner-gui') || vars.MAC_CI_GUI == 'enabled')"), "owner GUI tasks still need MAC_CI_GUI");
  const reusable = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  assert.deepEqual(guiGuardProblems(reusable), [], "every non-GUI job opens with the D94 GUI guard");
  // Every caller uses one pin, the one that carries this route.
  const dir = new URL("../../.github/workflows/", import.meta.url);
  const pins = new Set();
  for (const f of fs.readdirSync(dir)) for (const m of fs.readFileSync(new URL(f, dir), "utf8").matchAll(/trusted-mac\.yml@([0-9a-f]{40})/g)) pins.add(m[1]);
  assert.equal(pins.size, 1, [...pins].join(" "));
});

test("native GUI gets 70 minutes, native-headless a temporary 90, and other trusted Mac jobs retain their limits", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  const jobs = [...text.matchAll(/^  ([a-z][a-z0-9-]*):\n([\s\S]*?)(?=^  [a-z][a-z0-9-]*:\n|$(?![\s\S]))/gm)];
  const limits = Object.fromEntries(jobs.map(([, name, body]) => [name, Number(/^    timeout-minutes: (\d+)$/m.exec(body)?.[1])]));
  assert.deepEqual(limits, { native: 70, "native-headless": 90, transport: 30, sequences: 30, "u11-native": 30, probe: 5, "gui-probe": 5 });
  const xcodeSteps = text.match(/Select Xcode \(26\.6 17F113 on our Macs/g) || [];
  assert.equal(xcodeSteps.length, 2, "both Swift-building jobs pin Xcode 26.6");
  assert.match(text, /version == \(26, 6\) and build == "17F113"/);
  assert.match(text, /xcodebuild -version/);
  // The 90 is a stopgap with a recorded way back to 60.
  const headless = text.split("\n  native-headless:\n")[1].split("\n  transport:\n")[0];
  assert.match(headless, /temporary until the seed and the Mini concurrency fixes land; revert to 60/i);
  assert.match(headless, /TODO\(headless-cap\): set back to 60/);
});

test("D94: non-GUI jobs refuse GUI runners unless gui-2 is lent; the V1 host is never lent", () => {
  const reusable = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  assert.deepEqual(guiGuardProblems(reusable), []);
  assert.deepEqual(NONGUI_JOBS.slice().sort(), ["native-headless", "probe", "sequences", "transport", "u11-native"]);
  // The guard as shell: run the step's script for each runner and switch value.
  const script = GUI_LEND_GUARD.split("run: |\n")[1].split("\n").map((l) => l.replace(/^ {8}/, "")).join("\n");
  const run = (name, lend) => spawnSync("bash", ["-c", script], { env: { PATH: process.env.PATH, RUNNER_NAME: name, ...(lend === undefined ? {} : { MAC_GUI_LEND: lend }) } }).status;
  for (const lend of [undefined, "", "disabled", "Enabled", "enabled "]) assert.equal(run("modelplan-mac-gui-2", lend), 1, `gui-2 refused with MAC_GUI_LEND=${JSON.stringify(lend)}`);
  assert.equal(run("modelplan-mac-gui-2", "enabled"), 0, "gui-2 accepted while lent");
  for (const name of ["modelplan-mac-arm64-1", "modelplan-mac-gui-3", "modelplan-mac-gui-2x", "x-modelplan-mac-gui-2", "modelplan-mac-gui"])
    assert.equal(run(name, "enabled"), 1, `${name} refused even while lending`);
  for (const name of ["modelplan-mac-arm64-2", "modelplan-mac-arm64-3", "GitHub Actions 12"]) assert.equal(run(name, undefined), 0, `${name} accepted`);

  // Looser or moved guards fail the policy.
  const loose = [
    ["modelplan-mac-gui-2) if", "*gui-2*) if"],                                    // wildcard exception
    ['"${MAC_GUI_LEND:-}" != enabled', '"${MAC_GUI_LEND:-enabled}" != enabled'],   // default-on switch
    ['"${MAC_GUI_LEND:-}" != enabled', '"${MAC_GUI_LEND:-}" = disabled'],          // anything but disabled lends
    ["MAC_GUI_LEND: ${{ vars.MAC_GUI_LEND }}", "MAC_GUI_LEND: ${{ inputs.lend }}"], // switch from the caller
    ['          modelplan-mac-arm64-1) echo "::error::this job must not run on the V1 host ($RUNNER_NAME)"; exit 1;;\n', ""], // V1 refusal dropped
    ['          *gui*) echo "::error::this job must not run on the GUI Mac ($RUNNER_NAME)"; exit 1;;\n', ""],                 // no general refusal
  ];
  for (const [from, to] of loose) {
    assert.ok(reusable.includes(from), from);
    assert.ok(guiGuardProblems(reusable.replace(from, to)).length > 0, `accepted a looser guard: ${from} -> ${to}`);
  }
  // A guard that is not the first step, or a step that keeps going after it, fails.
  const job = reusable.split("\n  probe:\n")[1].split(/\n  [a-z0-9-]+:\n/)[0];
  const moved = job.replace(GUI_LEND_GUARD + "\n", "").replace("    - name: Validate native runner execution", GUI_LEND_GUARD + "\n    - name: Validate native runner execution");
  assert.ok(guiGuardProblems(reusable.replace(job, moved)).length > 0, "guard after another step");
  const extended = reusable.replace(GUI_LEND_GUARD + "\n", GUI_LEND_GUARD + "\n        export MAC_GUI_LEND=enabled\n");
  assert.ok(guiGuardProblems(extended).length > 0, "extra commands in the guard step");
  // The switch is only read by the non-GUI guards: not by the GUI job, not by another workflow.
  assert.ok(guiGuardProblems(reusable.replace("  gui-probe:\n", "  gui-probe:\n    env:\n      MAC_GUI_LEND: ${{ vars.MAC_GUI_LEND }}\n")).length > 0);
  assert.ok(workflowProblems("on: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    env:\n      X: ${{ vars.MAC_GUI_LEND }}\n", ".github/workflows/other.yml").includes("GUI lending switch outside trusted-mac.yml"));
  assert.deepEqual(workflowProblems(reusable, ".github/workflows/trusted-mac.yml"), []);
});

test("desktop.yml pr=<N> dispatch builds refs/pull/<N>/merge in every job it owns (D112)", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  assert.match(text, /^      pr:\n        description: .*\n        type: string\n        default: ""$/m, "workflow_dispatch input pr");
  assert.match(text, /^run-name: "\$\{\{ inputs\.pr && inputs\.sha && format\('desktop PR GUI #\{0\} @ \{1\}', inputs\.pr, inputs\.sha\) \|\| inputs\.pr && format\('desktop PR #\{0\} merged with main', inputs\.pr\) \|\| '' \}\}"$/m,
    "the coordinator finds a pr dispatch by its title (D481: a PR GUI run by 'desktop PR GUI #<n> @ <sha>'); other runs keep GitHub's default title");
  const job = (name) => new RegExp(`^  ${name}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(text)?.[1] ?? "";
  const resolver = job("pr-ref");
  assert.match(resolver, /if: \$\{\{ github\.event_name == 'workflow_dispatch' && inputs\.pr != '' && inputs\.sha == '' /, "a PR GUI run (D481) resolves no merge");
  assert.match(resolver, /refs\/pull\/\$PR\/merge/);
  assert.match(resolver, /\.base\.ref <<<"\$j"\)" = main/, "a PR whose base is not main must be rejected");
  {
    // Execute the real resolver against a stubbed gh/git: non-main base fails with no SHA; main base succeeds.
    const sh = /run: \|\n((?:          .*\n)+)/.exec(resolver)[1].replace(/^          /gm, "");
    const dir = fs.mkdtempSync(new URL("file:///tmp/pr-ref-").pathname);
    const head = "a".repeat(40), merge = "b".repeat(40);
    fs.writeFileSync(`${dir}/gh`, `#!/bin/bash\ncase "$2" in\n repos/*/commits/*) echo ${head};;\n *) echo "{\\"state\\":\\"open\\",\\"mergeable\\":true,\\"base\\":{\\"ref\\":\\"$BASE\\"},\\"head\\":{\\"sha\\":\\"${head}\\"}}";;\nesac\n`, { mode: 0o755 });
    fs.writeFileSync(`${dir}/git`, `#!/bin/bash\nprintf '${merge}\\trefs/pull/9/merge\\n'\n`, { mode: 0o755 });
    const go = (base) => { const out = `${dir}/out-${base}`; fs.writeFileSync(out, "");
      const r = spawnSync("bash", ["-c", sh], { env: { PATH: `${dir}:${process.env.PATH}`, BASE: base, GH_TOKEN: "x", REPO: "o/r", PR: "9", DISPATCHED: merge, GITHUB_OUTPUT: out, GITHUB_STEP_SUMMARY: `${dir}/sum` } });
      return { status: r.status, out: fs.readFileSync(out, "utf8") }; };
    const bad = go("qa-feature"), good = go("main");
    fs.rmSync(dir, { recursive: true, force: true });
    assert.notEqual(bad.status, 0); assert.equal(bad.out, "", "no SHA for a non-main PR");
    assert.equal(good.status, 0); assert.match(good.out, new RegExp(`sha=${merge}`));
  }
  assert.match(resolver, /grep -qx "\$head"/, "the merge must contain the PR's current head");
  for (const name of ["app", "shell", "native-partition", "cockpit-pins", "app-smoke"]) {
    const body = job(name);
    assert.match(body, /needs: \[queue-scope, pr-ref(?:, pr-scope)?\]/, `${name} needs pr-ref`);
    assert.match(body, /if: \$\{\{ !cancelled\(\) && \(!inputs\.pr \|\| needs\.pr-ref\.result == 'success'\) && /, `${name} never falls back to the dispatched ref`);
    assert.match(body, /- uses: actions\/checkout@v4\n        with:\n(?:          .*\n)*?          ref: \$\{\{ inputs\.pr && needs\.pr-ref\.outputs\.sha \|\| /, `${name} checks out the merge`);
  }
  // trusted-mac.yml is SHA-pinned and takes no ref: its callers stay unchanged and test the dispatched commit.
  for (const name of ["native", "native-hosted", "native-owner-gui", "native-headless"]) assert.doesNotMatch(job(name), /pr-ref|inputs\.pr/, name);
});

// D169 (owner 2026-11-11): a branch dispatch runs only the GUI classes related to its change; the merge queue and the
// nightly main run always run the whole GUI share, and pull_request events never start a GUI leg.
const stepScript = (block, name) => {
  const at = block.indexOf(`- name: ${name}`);
  assert.ok(at >= 0, name);
  const m = /\n(\s+)run: \|\n((?:\1  .*\n|\n)+)/.exec(block.slice(at));
  return m[2].replace(new RegExp(`^${m[1]}  `, "gm"), "");
};

test("D169: trusted-mac.yml narrows the GUI share only on an ordinary branch dispatch, with a validated class list", () => {
  const reusable = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  assert.match(reusable, /\n      gui_classes:\n(?:        #.*\n)*        required: false\n        type: string\n        default: full\n/);
  const job = reusable.split("\n  native:\n")[1].split("\n  native-headless:\n")[0];
  const sh = stepScript(job, "GUI test selection (D169; full except on a branch dispatch)");
  assert.match(job, /GUI_CLASSES_INPUT: \$\{\{ inputs\.gui_classes \}\}/, "the input reaches the shell only through env");
  assert.doesNotMatch(sh, /\$\{\{/, "no expression is interpolated into the script");
  const dir = fs.mkdtempSync("/tmp/d169-select-");
  const run = (event, ref, input) => {
    const env = `${dir}/env`; fs.writeFileSync(env, "");
    const r = spawnSync("bash", ["-c", sh], { env: { PATH: process.env.PATH, GITHUB_EVENT_NAME: event, GITHUB_REF: ref,
      GITHUB_ENV: env, GITHUB_STEP_SUMMARY: `${dir}/summary`, ...(input === undefined ? {} : { GUI_CLASSES_INPUT: input }) } });
    return r.status === 0 ? fs.readFileSync(env, "utf8").trim() : `exit ${r.status}`;
  };
  try {
    assert.equal(run("workflow_dispatch", "refs/heads/claude/x", "WidgetTests,DockTests"), "GUI_ONLY=WidgetTests,DockTests");
    assert.equal(run("workflow_dispatch", "refs/heads/claude/x", "none"), "GUI_ONLY=none");
    assert.equal(run("workflow_dispatch", "refs/heads/claude/x", ""), "GUI_ONLY=full");
    assert.equal(run("workflow_dispatch", "refs/heads/claude/x", undefined), "GUI_ONLY=full");
    // Whatever the caller passes, every other run gets the whole share.
    for (const [event, ref] of [["merge_group", "refs/heads/gh-readonly-queue/main/pr-1-abc"], ["schedule", "refs/heads/main"],
      ["push", "refs/heads/main"], ["pull_request", "refs/pull/1/merge"], ["workflow_dispatch", "refs/heads/main"],
      ["workflow_dispatch", "refs/heads/release/v1"], ["workflow_dispatch", "refs/tags/v1.0.0"]])
      assert.equal(run(event, ref, "WidgetTests"), "GUI_ONLY=full", `${event} ${ref}`);
    for (const bad of ["A;touch /tmp/d169-x", "A\nGUI_ONLY=none", "A,", "^Mod\\.", "A|B", "$(id)", "A B"])
      assert.equal(run("workflow_dispatch", "refs/heads/claude/x", bad), "exit 1", JSON.stringify(bad));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  // The narrowed share is planned and verified with the same selection; an empty plan is legal only when narrowed.
  const tests = stepScript(job, "App integration tests, GUI leg (window-server classes; the rest run in native-headless)");
  assert.match(tests, /plan --package app-integration --leg "\$LEG" --only "\$GUI_ONLY" /);
  assert.match(tests, /verify --package app-integration --leg "\$LEG" --only "\$GUI_ONLY" /);
  assert.match(tests, /\[ "\$GUI_ONLY" != full \] \|\| \{ echo "::error::the full GUI share planned no tests"; exit 1; \}/);
});

test("D169/D246 reverted: the owner Macs admit the merge queue for the GUI tasks only (native-headless is hosted there), the nightly for the GUI tasks only", () => {
  const extra = "((inputs.task == 'native' || inputs.task == 'native-owner-gui') && github.event_name == 'merge_group' && startsWith(github.ref, 'refs/heads/gh-readonly-queue/main/')) || ((inputs.task == 'native' || inputs.task == 'native-owner-gui') && github.event_name == 'schedule' && github.ref == 'refs/heads/main')";
  assert.equal(TRUSTED_MAC_ROUTE.split(extra).length, 2, "exactly one merge_group/schedule clause");
  // merge_group: only the queue clause; native-headless is hosted in the queue.
  assert.equal(TRUSTED_MAC_ROUTE.split("merge_group").length, 2);
  assert.equal(TRUSTED_MAC_ROUTE.split("'schedule'").length, 3, "the schedule-on-main bypass of the actor gate and the GUI-task clause");
  // It sits behind the owner identity gate (or the schedule-on-main bypass), next to the push/dispatch clause.
  const owner = "|| (github.repository == 'modelplan/modelplan' && github.event_name == 'schedule' && github.ref == 'refs/heads/main' && github.workflow_ref == 'modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main' && github.event.schedule == '23 9 * * *' && (inputs.task == 'native' || inputs.task == 'native-owner-gui'))) && (((github.event_name == 'pull_request'";
  const second = TRUSTED_MAC_ROUTE.lastIndexOf(owner);
  assert.ok(second > 0 && TRUSTED_MAC_ROUTE.indexOf(extra) > second);
});

test("D169: desktop.yml starts GUI legs only on dispatch, in the merge queue and on the nightly, and passes the selection", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  const job = (name) => new RegExp(`^  ${name}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(text)?.[1] ?? "";
  assert.match(text, /^  schedule:\n    - cron: "[0-9]+ [0-9]+ \* \* \*"\n/m, "a nightly schedule");
  assert.doesNotMatch(text, /gui-ci/, "no label starts a GUI leg on pull_request");
  const scope = job("gui-scope");
  assert.match(scope, /if: \$\{\{ !cancelled\(\) && !inputs\.mac_ci_probe && !inputs\.perf && \(\(github\.event_name == 'workflow_dispatch' && \(inputs\.gui \|\| inputs\.sha != ''\)\) \|\| \(github\.event_name == 'merge_group' && needs\.queue-scope\.outputs\.gui == 'true'\) \|\| github\.event_name == 'schedule'\) \}\}/);
  for (const name of ["native", "native-hosted", "native-owner-gui"]) {
    const body = job(name);
    assert.match(body, /needs: gui-scope\n/, name);
    assert.match(body, /if: \$\{\{ !cancelled\(\) && github\.event_name != 'pull_request' && .*needs\.gui-scope\.result == 'success' && needs\.gui-scope\.outputs\.run == 'true'/, name);
    assert.match(body, /\n      gui_classes: \$\{\{ needs\.gui-scope\.outputs\.classes \}\}\n/, name);
  }
  // The queue's GUI flag is computed before, and independently of, the tree-reuse shortcut.
  const queue = job("queue-scope");
  assert.ok(queue.indexOf('echo "gui=true"') > 0 && queue.indexOf('echo "gui=true"') < queue.indexOf("rev-list --parents"));
  assert.match(queue, /gui: \$\{\{ steps\.scope\.outputs\.gui \}\}/);
  // The nightly runs only the GUI legs: every other job skips the schedule.
  for (const name of ["app", "shell", "native-partition", "cockpit-pins", "cockpit-spi-tests", "app-smoke", "native-headless"])
    assert.match(job(name), /github\.event_name != 'schedule'/, name);

  // Execute the selection step against stubs.
  const sh = /run: \|\n((?:          .*\n|\n)+)/.exec(scope)[1].replace(/^          /gm, "");
  const dir = fs.mkdtempSync("/tmp/d169-scope-");
  fs.mkdirSync(`${dir}/desktop/native/tools/ci`, { recursive: true });
  // gh answers the runs query with $RUNS and a run's jobs query with $JOBS_<id>, filtered by the step's own --jq
  // expression (real jq).
  fs.writeFileSync(`${dir}/gh`, '#!/bin/bash\n[ -n "${GH_FAIL:-}" ] && exit 1\nurl="$2"\nwhile [ $# -gt 0 ]; do [ "$1" = --jq ] && f="$2"; shift; done\n' +
    'if [[ $url =~ /runs/([0-9]+)/jobs ]]; then [ -n "${JOBS_FAIL:-}" ] && exit 1; v="JOBS_${BASH_REMATCH[1]}"; d="${!v:-null}"; else d="${RUNS:-null}"; fi\n' +
    'printf "%s" "$d" | jq -r "$f"\n', { mode: 0o755 });
  fs.writeFileSync(`${dir}/git`, '#!/bin/bash\ncase "$1" in fetch) [ -z "${NO_BASE:-}" ];; merge-base) echo base;; diff) printf %s desktop/native/x.swift; printf "\\\\0";; esac\n', { mode: 0o755 });
  fs.writeFileSync(`${dir}/python3`, '#!/bin/bash\n[ -n "${SEL_FAIL:-}" ] && exit 1\nprintf "%s\\n" "${SELECTED:-WidgetTests}"\n', { mode: 0o755 });
  const go = (env) => {
    const out = `${dir}/out`; fs.writeFileSync(out, "");
    const r = spawnSync("bash", ["-c", sh], { cwd: dir, env: { PATH: `${dir}:${process.env.PATH}`, RUNNER_TEMP: dir, GITHUB_OUTPUT: out,
      GITHUB_STEP_SUMMARY: `${dir}/summary`, GITHUB_SHA: "a".repeat(40), REPO: "o/r", GH_TOKEN: "x", GUI_FULL: "false", ...env } });
    assert.equal(r.status, 0, r.stderr.toString());
    return fs.readFileSync(out, "utf8").trim().split("\n").join(" ");
  };
  const branch = { EVENT: "workflow_dispatch", REF: "refs/heads/claude/x" };
  try {
    assert.equal(go(branch), "run=true classes=WidgetTests");
    assert.equal(go({ ...branch, SELECTED: "none" }), "run=true classes=none");
    assert.equal(go({ ...branch, SEL_FAIL: "1" }), "run=true classes=full", "selector failure -> full");
    assert.equal(go({ ...branch, SELECTED: "A;B" }), "run=true classes=full", "malformed output -> full");
    assert.equal(go({ ...branch, NO_BASE: "1" }), "run=true classes=full", "no merge base -> full");
    assert.equal(go({ ...branch, GUI_FULL: "true" }), "run=true classes=full");
    for (const REF of ["refs/heads/main", "refs/heads/release/v1", "refs/tags/v1"]) assert.equal(go({ ...branch, REF }), "run=true classes=full", REF);
    assert.equal(go({ EVENT: "merge_group", REF: "refs/heads/gh-readonly-queue/main/pr-1-a" }), "run=true classes=full");
    assert.equal(go({ EVENT: "schedule", REF: "refs/heads/main" }), "run=true classes=full");
    const runs = (...r) => JSON.stringify({ workflow_runs: r });
    const self = { id: 7, status: "in_progress", conclusion: null };
    const night = (RUNS, jobs = {}) => go({ EVENT: "schedule", REF: "refs/heads/main", GITHUB_RUN_ID: "7", RUNS, ...jobs });
    const jobs = (...j) => JSON.stringify({ jobs: j.map(([name, conclusion]) => ({ name, conclusion })) });
    const guiPassed = jobs(["gui-scope", "success"], ["native (macos-latest) / native (macos-latest)", "success"]);
    const guiSkipped = jobs(["gui-scope", "success"], ["native (macos-latest) / native (macos-latest)", "skipped"], ["native-owner-gui (macos-latest)", "skipped"]);
    assert.equal(night(runs(self)), "run=true classes=full", "only this run at the head");
    const ok5 = { id: 5, status: "completed", conclusion: "success" };
    assert.equal(night(runs(self, ok5), { JOBS_5: guiPassed }), "run=false classes=full", "same main head already passed its GUI leg");
    // macrevb-866-1 / glm-866-3: a successful nightly whose GUI legs were skipped (it saw another nightly running) is
    // not a GUI pass. A active -> B skipped (success) -> A failed: C must run.
    const a = { id: 4, status: "completed", conclusion: "failure" };
    assert.equal(night(runs(self, a, ok5), { JOBS_5: guiSkipped }), "run=true classes=full", "a skipped-GUI success does not count");
    assert.equal(night(runs(self, ok5)), "run=true classes=full", "unreadable jobs -> run");
    assert.equal(night(runs(self, ok5), { JOBS_5: guiPassed, JOBS_FAIL: "1" }), "run=true classes=full", "jobs query fails -> run");
    // The hosted pool's GUI leg is the pair native-hosted + native-owner-gui; one of them alone is not a pass.
    const hosted = ["native-hosted (macos-15) / native-hosted-gui (macos-15)", "success"], owner = ["native-owner-gui (macos-latest) / native-owner-gui (macos-latest)", "success"];
    assert.equal(night(runs(self, ok5), { JOBS_5: jobs(hosted, owner) }), "run=false classes=full", "hosted pair passed");
    assert.equal(night(runs(self, ok5), { JOBS_5: jobs(hosted, [owner[0], "failure"]) }), "run=true classes=full", "only half the pair");
    assert.equal(night(runs(self, ok5), { JOBS_5: jobs(["native (macos-latest) / native-headless (macos-latest)", "success"]) }), "run=true classes=full", "a non-GUI task is not a GUI pass");
    // An older GUI pass still counts when a newer skipped success sits next to it.
    assert.equal(night(runs(self, ok5, { id: 6, status: "completed", conclusion: "success" }), { JOBS_5: guiSkipped, JOBS_6: guiPassed }), "run=false classes=full");
    assert.equal(night(runs(self, { id: 5, status: "completed", conclusion: "failure" })), "run=true classes=full", "a failed nightly is retried");
    // glm-866-2: an earlier nightly still queued or running at the same head already holds the GUI Mac for it.
    for (const status of ["queued", "in_progress", "waiting"])
      assert.equal(night(runs(self, { id: 5, status, conclusion: null })), "run=false classes=full", status);
    assert.equal(go({ EVENT: "schedule", REF: "refs/heads/main", GH_FAIL: "1" }), "run=true classes=full", "unreadable -> run");
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

// D481 (owner 2026-11-27): a PR whose paths map to GUI classes needs an exact-head PR GUI run of those classes before
// modelplan-gates passes. The run is a desktop dispatch of the PR's own head branch with pr=<n> and sha=<head>.
test("D481: a pr+sha dispatch is the PR GUI leg: exact head on its own branch, mapped classes only, nothing else runs", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  const job = (name) => new RegExp(`^  ${name}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(text)?.[1] ?? "";
  assert.match(text, /^      sha:\n        description: .*\n        type: string\n        default: ""$/m, "workflow_dispatch input sha");
  // Only gui-scope and the GUI legs run: pr-ref resolves no merge, so every job that needs it skips; native-headless skips.
  for (const name of ["app", "shell", "native-partition", "cockpit-pins", "cockpit-spi-tests", "app-smoke"])
    assert.match(job(name), /\(!inputs\.pr \|\| needs\.pr-ref\.result == 'success'\)/, name);
  assert.match(job("native-headless"), /if: \$\{\{ !cancelled\(\) && !inputs\.mac_ci_probe && !inputs\.perf && !inputs\.sha && /);
  for (const name of ["native", "native-hosted", "native-owner-gui"])
    assert.match(job(name), /\n      gui_classes: \$\{\{ needs\.gui-scope\.outputs\.classes \}\}\n/, name);
  const scope = job("gui-scope");
  assert.match(scope, /\n      pull-requests: read\n/);
  assert.match(scope, /\n          PR: \$\{\{ inputs\.pr \}\}\n          PR_SHA: \$\{\{ inputs\.sha \}\}\n          GUI_MAP: desktop\/native\/tools\/ci\/gui-test-map\.json\n/);
  const sh = /run: \|\n((?:          .*\n|\n)+)/.exec(scope)[1].replace(/^          /gm, "");
  assert.doesNotMatch(sh, /\$\{\{/, "no expression is interpolated into the script");
  const dir = fs.mkdtempSync("/tmp/d481-scope-");
  const head = "a".repeat(40), other = "b".repeat(40);
  // gh: the PR (or $PRJSON) and its file rows ($FILES, already in the --jq shape); git: fetch, cat-file and show of main's map.
  fs.writeFileSync(`${dir}/gh`, '#!/bin/bash\ncase "$*" in\n *pulls/*/files*) printf "%s" "$FILES";;\n *pulls/*) printf "%s" "$PRJSON";;\n *) exit 1;;\nesac\n', { mode: 0o755 });
  fs.writeFileSync(`${dir}/git`, '#!/bin/bash\ncase "$1" in fetch) [ -z "${NO_FETCH:-}" ];; cat-file) [ -n "${MAIN_MAP:-}" ];; show) cat "$MAIN_MAP";; *) exit 1;; esac\n', { mode: 0o755 });
  const prJson = (over = {}) => JSON.stringify({ state: "open", draft: false, base: { ref: "main" }, head: { sha: head, ref: "claude/x", repo: { full_name: "o/r" } }, ...over });
  const rows = (...names) => names.map((n) => JSON.stringify({ filename: n, previous_filename: null })).join("\n") + "\n";
  const go = (env = {}) => {
    const out = `${dir}/out`; fs.writeFileSync(out, "");
    const r = spawnSync("bash", ["-c", sh], { cwd: new URL("../..", import.meta.url).pathname, env: { PATH: `${dir}:${process.env.PATH}`, RUNNER_TEMP: dir,
      GITHUB_OUTPUT: out, GITHUB_STEP_SUMMARY: `${dir}/summary`, GITHUB_SHA: head, REPO: "o/r", GH_TOKEN: "x", GUI_FULL: "false",
      EVENT: "workflow_dispatch", REF: "refs/heads/claude/x", PR: "9", PR_SHA: head, GUI_MAP: "desktop/native/tools/ci/gui-test-map.json",
      PRJSON: prJson(), FILES: rows("desktop/native/ModelPlanDock/Native/DockInstrumentRenderer.swift"), ...env } });
    return { status: r.status, out: fs.readFileSync(out, "utf8").trim().split("\n").join(" "), err: r.stderr.toString() + r.stdout.toString() };
  };
  try {
    const ring = go();
    assert.equal(ring.status, 0, `exit ${ring.status}: ${ring.err}`);
    assert.match(ring.out, /^run=true classes=[A-Za-z0-9_,]*\bD65ZeroQuotaTests\b/, "#1208's ring renderer runs D65ZeroQuotaTests");
    assert.doesNotMatch(ring.out, /full/, "never the full share");
    // macrev2-1310-1: the selected set is recorded for the gate as a notice annotation, exactly as gui-map.mjs reads it.
    const rec = /^::notice title=D481 PR GUI classes::(.+)$/m.exec(ring.err)?.[1] ?? "";
    assert.match(rec, /^app-integration:[A-Za-z0-9_]+(,[a-z-]+:[A-Za-z0-9_]+)*$/);
    assert.ok(rec.split(",").includes("app-integration:D65ZeroQuotaTests"));
    assert.match(go({ FILES: rows("docs/mac-ci.md") }).err, /^::notice title=D481 PR GUI classes::none$/m, "no class: recorded as none");
    assert.equal(go({ FILES: rows("docs/mac-ci.md", "cli/main.go") }).out, "run=false classes=none", "no mapped class: nothing runs");
    // main's map is unioned in; classes of a whole-run package only (settings) still run the leg, narrowed to none.
    fs.writeFileSync(`${dir}/main-map.json`, JSON.stringify({ schemaVersion: 1, packages: { "app-integration": "x", settings: "y" },
      areas: [{ area: "cli", paths: ["cli/**"], classes: { settings: ["SettingsB5GridTests"] } }] }));
    assert.equal(go({ FILES: rows("cli/main.go"), MAIN_MAP: `${dir}/main-map.json` }).out, "run=true classes=none");
    fs.writeFileSync(`${dir}/bad-map.json`, "{}");
    // Every mismatch fails the run (no output, nonzero): the gate then sees a failed PR GUI run, never a pass.
    for (const [why, env] of [
      ["the branch moved", { GITHUB_SHA: other }],
      ["the PR moved", { PRJSON: prJson({ head: { sha: other, ref: "claude/x", repo: { full_name: "o/r" } } }) }],
      ["another branch", { PRJSON: prJson({ head: { sha: head, ref: "claude/y", repo: { full_name: "o/r" } } }) }],
      ["a fork", { PRJSON: prJson({ head: { sha: head, ref: "claude/x", repo: { full_name: "fork/r" } } }) }],
      ["a draft", { PRJSON: prJson({ draft: true }) }],
      ["closed", { PRJSON: prJson({ state: "closed" }) }],
      ["not on main", { PRJSON: prJson({ base: { ref: "release" } }) }],
      ["main dispatch", { REF: "refs/heads/main" }],
      ["release dispatch", { REF: "refs/heads/release/v1" }],
      ["tag dispatch", { REF: "refs/tags/v1" }],
      ["short sha", { PR_SHA: "abc", GITHUB_SHA: "abc" }],
      ["bad pr", { PR: "9;id" }],
      ["main unreadable", { NO_FETCH: "1" }],
      ["invalid main map", { MAIN_MAP: `${dir}/bad-map.json` }],
      ["unreadable PR", { PRJSON: "" }],
    ]) {
      const r = go(env);
      assert.notEqual(r.status, 0, why);
      assert.equal(r.out, "", `${why}: no outputs`);
    }
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test("the compile runner is confined to mac-compile.yml, started only through workflow_run/dispatch (main's definition)", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/mac-compile.yml", import.meta.url), "utf8");
  assert.deepEqual(workflowProblems(text, MAC_COMPILE_PATH), []);
  // the gate names the checks that keep fork, stale and non-owner runs off the Macs
  for (const part of ["github.ref == 'refs/heads/main'", "github.event.workflow_run.event == 'pull_request'", "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.head_repository.full_name == github.repository", "github.actor_id == '11829005'", "needs.plan.outputs.run == 'true'"]) assert.ok(MAC_COMPILE_IF.includes(part), part);
  // the route elsewhere, or the label in any other form, fails
  assert.ok(workflowProblems(text, ".github/workflows/other.yml").length > 0);
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: modelplan-compile\n", ".github/workflows/other.yml").includes("compile runner label outside mac-compile.yml"));
  const bad = [
    [MAC_COMPILE_IF, MAC_COMPILE_IF.replace(" && github.event.workflow_run.head_repository.full_name == github.repository", "")], // forks admitted
    [MAC_COMPILE_IF, MAC_COMPILE_IF.replace(" && github.ref == 'refs/heads/main'", "")],                                         // a branch's copy
    ["on:\n  workflow_run:\n", "on:\n  pull_request:\n  workflow_run:\n"],                                                       // the PR's own copy
    ["    workflows: [mac-compile trigger]\n", "    workflows: [ci]\n"],                                                         // another workflow
    ["permissions:\n  contents: read\n#", "permissions:\n  contents: write\n#"],                                                 // write token
    ["      statuses: write\n", "      statuses: write\n      pull-requests: write\n"],                                         // more write scopes
    ["      statuses: write\n    steps:\n", "      statuses: write\n    steps:\n      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\n        with:\n          persist-credentials: false\n"], // writer runs code
    ["    permissions:\n      contents: read\n    steps:\n      - name: Check out main's", "    permissions:\n      contents: read\n      statuses: write\n    steps:\n      - name: Check out main's"], // Mac job writes
    ["          path: pr\n          persist-credentials: false\n", "          path: pr\n"],                                         // persisted credentials
    ["          PR: ${{ needs.plan.outputs.pr }}\n", "          PR: ${{ needs.plan.outputs.pr }}\n          T: ${{ secrets.X }}\n"], // a secret
    ["  compile:\n", "  compile2:\n    needs: plan\n    " + MAC_COMPILE_IF + "\n    " + MAC_COMPILE_ROUTE + "\n    steps: []\n  compile:\n"], // a second Mac job
  ];
  for (const [from, to] of bad) {
    assert.ok(text.includes(from), from);
    assert.ok(workflowProblems(text.replace(from, to), MAC_COMPILE_PATH).length > 0, `accepted: ${from} -> ${to}`);
  }
  assert.ok(macCompileProblems(text.replace("    if: ${{ needs.plan.outputs.run == 'true' && github.repository", "    if: ${{ true || github.repository")).length > 0);
});

test("the smoke label is confined to runner-smoke.yml: dispatch-only, owner on main, read-only, 40 minutes", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/runner-smoke.yml", import.meta.url), "utf8");
  assert.deepEqual(workflowProblems(text, RUNNER_SMOKE_PATH), []);
  assert.ok(text.includes(RUNNER_SMOKE_ROUTE) && text.includes(RUNNER_SMOKE_IF));
  for (const part of ["github.actor_id == '11829005'", "github.actor == 'guanbear'", "github.triggering_actor == 'guanbear'", "github.ref == 'refs/heads/main'", "startsWith(inputs.ref, 'refs/tags/')"]) assert.ok(RUNNER_SMOKE_IF.includes(part), part);
  assert.ok(text.startsWith("# SPDX-License-Identifier: MIT\n"));
  const mutations = [
    ["  workflow_dispatch:\n", "  pull_request:\n  workflow_dispatch:\n"],
    ["  contents: read\n", "  contents: write\n"],
    ["persist-credentials: false", "persist-credentials: true"],
    ["          - smoke-arm64-5\n", "          - smoke-arm64-5\n          - modelplan-mac\n"],
    ["          - smoke-arm64-5\n", "          - smoke-arm64-5\n          - modelplan-mac-nongui # standby\n"],
    ["          - smoke-arm64-5\n", "          - smoke-arm64-5\n          - 'modelplan-mac-nongui'\n"],
    ["        ref: ${{ startsWith(inputs.ref, 'refs/tags/') && inputs.ref || github.sha }}", "        # ref: ${{ startsWith(inputs.ref, 'refs/tags/') && inputs.ref || github.sha }}\n        ref: refs/heads/main"],
    ["        ref: ${{ startsWith(inputs.ref, 'refs/tags/') && inputs.ref || github.sha }}", "        ref: ${{ inputs.ref }}"],
    ["          - smoke-arm64-5\n", "          - smoke-arm64-5\n          -\n            fixture-label\n"],
    ["          - smoke-arm64-5\n", "          - smoke-arm64-5\u00a0# note\n"],
    ["        default: main\n", "        default: main\n          - smoke-arm64-6\n"],
    ["        ref: ${{ startsWith(inputs.ref, 'refs/tags/') && inputs.ref || github.sha }}\n", "        ref: ${{ startsWith(inputs.ref, 'refs/tags/') && inputs.ref || github.sha }}\n          fixture suffix\n"],
    ["        # GitHub compares", "        #\u00a0GitHub compares"],
    [" && github.actor == 'guanbear'", ""],
    [" && github.ref == 'refs/heads/main'", ""],
    ["timeout-minutes: 40", "timeout-minutes: 400"],
    ["      MACOSX_DEPLOYMENT_TARGET: '14.0'\n", "      MACOSX_DEPLOYMENT_TARGET: '14.0'\n      T: ${{ secrets['EXAMPLE'] }}\n"],
    ["      MACOSX_DEPLOYMENT_TARGET: '14.0'\n", "      MACOSX_DEPLOYMENT_TARGET: '14.0'\n      T: ${{ toJSON(secrets) }}\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    permissions:\n      contents: write\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    permissions: { contents: write }\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    permissions: write-all\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    permissions:\n      contents: read\n"],
    ["          smoke-arm64-[0-9]|smoke-arm64-[0-9][0-9]) ;;", "          smoke-arm64-[0-9]*|*) ;;"],
    ["          smoke-arm64-[0-9]|smoke-arm64-[0-9][0-9]) ;;", "          smoke-arm64-[0-9]|smoke-arm64-[0-9][0-9]|modelplan-mac-*) ;;"],
    ["    - name: Refuse a runner without an opaque name\n", "    - name: Refuse a runner without an opaque name\n      if: ${{ always() && false }}\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    \"permissions\": {contents: \"write\"}\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    'permissions': {contents: 'write'}\n"],
    ["    timeout-minutes: 40\n", "    timeout-minutes: 40\n    ? permissions\n    : {contents: write}\n"],
    ["permissions:\n  contents: read\n", "permissions:\n  contents: read\npermissions:\n  contents: write\n"],
    ["    steps:\n    - name: Refuse", "    steps:\n    - permissions: {contents: write}\n      run: echo x\n    - name: Refuse"],
    ["        echo \"ModelPlanCommunityApp linked\"", "        ls -l \"$bin/ModelPlanCommunityApp\""],
    ["          echo \"runner: $RUNNER_NAME, label", "          echo \"${{ runner.name }}\"\n          echo \"runner: label"],
    ["jobs:\n", "jobs:\n  extra:\n    runs-on: [self-hosted, macOS, ARM64, modelplan-mac-nongui]\n    steps: []\n"],
  ];
  for (const [from, to] of mutations) {
    assert.ok(text.includes(from), from);
    assert.ok(HAVE_YAML ? workflowProblems(text.replace(from, to), RUNNER_SMOKE_PATH).length > 0 : true, `accepted: ${from} -> ${to}`);
  }
  assert.deepEqual(runnerSmokeProblems(text.replace("          - smoke-arm64-5\n", "          - smoke-arm64-5 # first\n          - smoke-arm64-6\n")), []);
  assert.ok(runnerSmokeProblems(text.replace("      MACOSX_DEPLOYMENT_TARGET: '14.0'\n", "      MACOSX_DEPLOYMENT_TARGET: '14.0'\n      T: ${{ secrets.X }}\n")).some((p) => p.includes("secrets")));
  // The smoke label and route are refused in any other workflow.
  assert.ok(workflowProblems(text, ".github/workflows/other.yml").length > 0);
  assert.ok(workflowProblems("runs-on: [self-hosted, macOS, ARM64, smoke-arm64-5]\n", ".github/workflows/other.yml").length > 0);
  // Case variants and input-driven routes cannot reach the label from another workflow (labels match case-insensitively).
  for (const route of ["runs-on: [self-hosted, macOS, ARM64, SMOKE-ARM64-5]", "runs-on: ubuntu-latest\n    env:\n      L: Smoke-Arm64-5", "runs-on: ${{ inputs.runner }}", "runs-on: ${{ github.event.inputs.runner }}",
    "runs-on: [${{ vars.R }}]", "runs-on:\n      - ${{ inputs.runner }}", "runs-on:\n      - macOS\n      - ${{ inputs.label }}", "runs-on: [ubuntu-latest, \"${{ inputs.label }}\"]"])
    assert.ok(workflowProblems(`jobs:\n  a:\n    ${route}\n`, ".github/workflows/other.yml").length > 0, route);
  // Safe hosted routes stay legal, including a static matrix (the existing u14 workflow) and the smoke route in its own file.
  for (const route of ["runs-on: ubuntu-24.04", "runs-on: [ubuntu-latest]"]) assert.deepEqual(workflowProblems(`jobs:\n  a:\n    ${route}\n`, ".github/workflows/other.yml"), [], route);
  const staticMatrix = "jobs:\n  a:\n    strategy:\n      matrix:\n        os: [ubuntu-latest, macos-15]\n    runs-on: ${{ matrix.os }}\n";
  assert.deepEqual(workflowProblems(staticMatrix, ".github/workflows/other.yml"), []);
  assert.deepEqual(workflowProblems("jobs:\n  a:\n    strategy:\n      matrix:\n        include:\n          - os: ubuntu-latest\n    runs-on: ${{ matrix.os }}\n", ".github/workflows/other.yml"), []);
  const evMatrix = (e) => `jobs:\n  a:\n    strategy:\n      matrix:\n        os: ${e}\n    runs-on: \${{ matrix.os }}\n`;
  assert.deepEqual(workflowProblems(evMatrix("${{ fromJSON(!contains(fromJSON('[\"pull_request\"]'), github.event_name) && '[\"ubuntu-latest\",\"macos-latest\"]' || '[\"ubuntu-latest\"]') }}"), ".github/workflows/other.yml"), []);
  for (const e of ["${{ fromJSON(github.event_name == 'push' && '[\"a\"]' || inputs.rows) }}", "${{ fromJSON(github.event_name == 'push' && '[\"smoke-arm64-5\"]' || '[\"b\"]') }}", "${{ fromJSON(github.event_name == 'push' && '[\"a b\"]' || '[\"b\"]') }}", "${{ github.ref_name }}"])
    assert.ok(workflowProblems(evMatrix(e), ".github/workflows/other.yml").length > 0 || !HAVE_YAML, e);
  // macrevc-1107-1: a matrix that comes from an input or any expression, or a key it does not define, cannot be resolved statically.
  for (const bad of [
    "on:\n  workflow_dispatch:\n    inputs:\n      matrix:\n        type: string\njobs:\n  a:\n    strategy:\n      matrix: ${{ fromJSON(inputs.matrix) }}\n    runs-on: ${{ matrix.os }}\n",
    "jobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ fromJSON(inputs.os) }}\n    runs-on: ${{ matrix.os }}\n",
    "jobs:\n  a:\n    strategy:\n      matrix:\n        include: ${{ fromJSON(inputs.rows) }}\n    runs-on: ${{ matrix.os }}\n",
    "jobs:\n  a:\n    strategy:\n      matrix:\n        os: [\"${{ inputs.os }}\"]\n    runs-on: ${{ matrix.os }}\n",
    "jobs:\n  a:\n    runs-on: ${{ matrix.os }}\n",
    "jobs:\n  a:\n    strategy:\n      matrix:\n        os: [ubuntu-latest]\n    runs-on: ${{ matrix.other }}\n",
    "jobs:\n  a:\n    runs-on: ${{ github.event_name == 'push' && 'ubuntu-latest' || 'macos-15' }}\n",
    "jobs:\n  a:\n    \"runs-on\": ${{ fromJSON(inputs.r) }}\n",
    "jobs:\n  a:\n    runs-on: { group: g, labels: \"${{ inputs.l }}\" }\n",
    "jobs:\n  a:\n    runs-on: [self-hosted, \"${{ needs.p.outputs.l }}\"]\n",
  ]) assert.ok(workflowProblems(bad, ".github/workflows/other.yml").length > 0 || !HAVE_YAML, bad);
  // macrevc-1107-2: quoted keys, YAML complex keys and duplicate keys are read as the parser reads them.
  const ruleSmoke = (extra) => workflowProblems(text.replace("    timeout-minutes: 40\n", `    timeout-minutes: 40\n${extra}`), RUNNER_SMOKE_PATH);
  for (const extra of ['    "permissions": {contents: "write"}\n', "    'permissions': { 'contents': 'write' }\n", '    "permissions": "write-all"\n', '    "permissions": {"contents": "read"}\n']) assert.ok(ruleSmoke(extra).length > 0, extra);
  // macrevc-1107-3: only an opaque smoke-arm64-N runner name is accepted, and it is refused unprinted.
  const guard = text.slice(text.indexOf("        case \"${RUNNER_NAME:-}\""), text.indexOf("        echo \"HEADLESS_SCRATCH"));
  const sh = (name) => spawnSync("bash", ["-c", guard.replace(/^ {8}/gm, "")], { env: { RUNNER_NAME: name, PATH: process.env.PATH }, encoding: "utf8" });
  for (const ok of ["smoke-arm64-5", "smoke-arm64-12"]) assert.equal(sh(ok).status, 0, ok);
  for (const bad of ["", "Guans-Mac-mini", "guan-macbook.local", "modelplan-mac-arm64-1", "smoke-arm64-5x", "SMOKE-ARM64-5", "smoke-arm64-", "smoke-arm64-123", "x-smoke-arm64-5"]) {
    const r = sh(bad);
    assert.equal(r.status, 1, bad);
    assert.ok(!bad || bad === "smoke-arm64-" || !(r.stdout + r.stderr).includes(bad), `printed ${bad}`);
  }
  assert.ok(text.includes('echo "runner: $RUNNER_NAME, label $SMOKE_LABEL'));
});

test("macrevc-1107-3: after a rejected runner name no step runs, so the name never reaches a log, summary or artifact (parser independent)", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/runner-smoke.yml", import.meta.url), "utf8");
  assert.deepEqual(runnerSmokeNameLeakProblems(text), []);
  const reportIf = "      if: ${{ always() && steps.guard.outcome == 'success' }}\n";
  for (const [from, to] of [
    [reportIf, "      if: ${{ always() }}\n"],                                              // the original leak
    [reportIf, "      if: ${{ always() && steps.guard.outcome != 'cancelled' }}\n"],       // runs after a failed guard
    [reportIf, "      if: ${{ steps.guard.outcome == 'success' }}\n"],                      // not the reviewed condition
    [reportIf, ""],
    ["      id: guard\n", "      id: other\n"],
    ["    - name: Start the clock", "    - if: ${{ failure() }}\n      run: echo \"$RUNNER_NAME\"\n    - name: Start the clock"],
    ["    - name: Start the clock", "    - if: ${{ always() }}\n      run: echo hi\n    - name: Start the clock"],
    ["    - name: Start the clock", "    - run: echo \"${{ runner.name }}\"\n    - name: Start the clock"],
    ["        echo \"ModelPlanCommunityApp linked\"", "        echo \"$RUNNER_NAME\""],
  ]) {
    assert.ok(text.includes(from), from);
    assert.ok(runnerSmokeNameLeakProblems(text.replace(from, to)).length > 0, `accepted: ${from} -> ${to}`);
    if (HAVE_YAML) assert.ok(workflowProblems(text.replace(from, to), RUNNER_SMOKE_PATH).length > 0, `workflowProblems accepted: ${from}`);
  }
  // Behaviour on a synthetic host-like name: the guard is the only step that can run, and it does not print the name.
  const guardOut = spawnSync("bash", ["-c", text.slice(text.indexOf("        case \"${RUNNER_NAME:-}\""), text.indexOf("        echo \"HEADLESS_SCRATCH")).replace(/^ {8}/gm, "")], { env: { RUNNER_NAME: "Synthetic-Host-Mini", PATH: process.env.PATH }, encoding: "utf8" });
  assert.equal(guardOut.status, 1);
  assert.ok(!(guardOut.stdout + guardOut.stderr).includes("Synthetic-Host"));
});

test("the mac-compile trigger is a no-permission, no-action pull_request run", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/mac-compile-trigger.yml", import.meta.url), "utf8");
  assert.deepEqual(workflowProblems(text, MAC_COMPILE_TRIGGER_PATH), []);
  assert.deepEqual(macConcurrencyProblems(text), []);
  assert.deepEqual(draftGuardProblems(text), []);
  for (const [from, to] of [
    ["permissions: {}", "permissions:\n  contents: read"],
    ["    steps:\n", "    steps:\n      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\n"],
    ["    steps:\n", "    permissions:\n      statuses: write\n    steps:\n"],
    ["on:\n  pull_request:\n", "on:\n  pull_request:\n  push:\n"],
    ["    steps:\n", "    env:\n      T: ${{ secrets.X }}\n    steps:\n"],
  ]) {
    assert.ok(text.includes(from), from);
    assert.ok(macCompileTriggerProblems(text.replace(from, to)).length > 0, `accepted: ${from} -> ${to}`);
  }
});

test("desktop.yml queue-scope declares 'GUI share not needed' for the merge gate, as valid YAML", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  const m = /^      - name: GUI share not needed\n        if: \$\{\{ steps\.scope\.outputs\.gui != 'true' \}\}\n        run: (.*)\n/m.exec(text);
  assert.ok(m, "the step rules.mjs guiLegState relies on must exist in queue-scope, gated on gui != 'true'");
  assert.ok(text.indexOf(m[0]) > text.indexOf("\n  queue-scope:") && text.indexOf(m[0]) < text.indexOf("\n  gui-scope:"), "inside queue-scope");
  assert.ok(!/: /.test(m[1]) && !/ #/.test(m[1]), "a plain scalar with ': ' is a YAML error (this broke desktop.yml at 7df3cedc)");
});

test("native-headless warms from a seed script read from main, and only a main dispatch publishes", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  const job = text.split("\n  native-headless:\n")[1].split("\n  transport:\n")[0];
  // The script never comes from the workspace (the merge-queue commit): it is a separate sparse checkout of main.
  assert.match(job, /uses: actions\/checkout@[0-9a-f]{40}[^\n]*\n {6}with:\n {8}ref: main\n {8}path: \.trusted-main\n {8}sparse-checkout: scripts\/mac-compile\n {8}persist-credentials: false/);
  const calls = [...job.matchAll(/run: bash "([^"]+)" (\w+)/g)].map((m) => [m[1], m[2]]);
  assert.deepEqual(calls, [["$GITHUB_WORKSPACE/.trusted-main/scripts/mac-compile/headless-seed.sh", "restore"], ["$GITHUB_WORKSPACE/.trusted-main/scripts/mac-compile/headless-seed.sh", "publish"]]);
  assert.ok(!/bash scripts\//.test(job) && !/bash "?\$GITHUB_WORKSPACE\/scripts/.test(job), "no seed script from the workspace");
  const publish = job.split("name: Publish the build seed")[1].split("run:")[0];
  assert.ok(publish.includes("github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'") && publish.includes("success()"));
  // restore comes before the first build; publish right after the last build and before any test runs, so a later
  // cap or cancel cannot lose the seed.
  const at = (needle) => { const i = job.indexOf(needle); assert.ok(i >= 0, needle); return i; };
  const publishAt = at("headless-seed.sh\" publish");
  assert.ok(at("headless-seed.sh\" restore") < at("swift build --package-path desktop/native --scratch-path \"$HEADLESS_SCRATCH\""));
  assert.ok(publishAt > at("--scratch-path \"$HEADLESS_SCRATCH\" --jobs 2 --build-tests"));
  for (const later of ["swift test --package-path", "swift run --package-path", "Synthetic fixture integrity"]) assert.ok(publishAt < at(later), later);
  assert.equal((job.replace(/^\s*#.*$/gm, "").match(/--build-tests/g) ?? []).length, 1);
});

test("native-headless builds once into one scratch path and starts SwiftPM only where it must", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  // Commands only: comment lines may name what the job no longer does.
  const job = text.split("\n  native-headless:\n")[1].split("\n  transport:\n")[0].replace(/^\s*#.*$/gm, "");
  const seed = fs.readFileSync(new URL("../mac-compile/headless-seed.sh", import.meta.url), "utf8");
  // One scratch path, the one the seed script restores and publishes.
  assert.match(job, /echo "HEADLESS_SCRATCH=\$RUNNER_TEMP\/headless-build" >> "\$GITHUB_ENV"/);
  assert.match(seed, /\|headless_build\|\$RUNNER_TEMP\/headless-build"/);
  const swift = [...job.matchAll(/swift (build|run|test)( list)? [^\n]*/g)].map((m) => m[0]);
  for (const call of swift) assert.ok(call.includes('--scratch-path "$HEADLESS_SCRATCH"'), call);
  assert.doesNotMatch(job, /app-integration-tests|swift test list|--product ModelPlanCommunityApp/);
  // Builds: the native package once, the app integration package (tests and every product) once.
  assert.equal(swift.filter((c) => c.startsWith("swift build") && !c.includes("--show-bin-path")).length, 2);
  // The headless share comes from the sources and is verified against what actually ran.
  assert.match(job, /"\$partition" static-list --package app-integration > /);
  assert.match(job, /"\$partition" plan --static --package app-integration --leg headless/);
  assert.match(job, /"\$partition" verify --static --package app-integration --leg headless/);
  // The GUI leg (job native) keeps its own build and `swift test list`: its share is "everything else".
  const gui = text.split("\n  native:\n")[1].split("\n  native-headless:\n")[0];
  assert.match(gui, /swift test list --package-path "\$pkg" --scratch-path "\$scratch" --skip-build/);
});

const WF_DIR = new URL("../../.github/workflows/", import.meta.url);
const workflows = () => fs.readdirSync(WF_DIR).filter((f) => /\.ya?ml$/.test(f)).map((f) => [f, fs.readFileSync(new URL(f, WF_DIR), "utf8")]);

test("D254: every macOS PR leg has a path gate (workflow-level list excluding markdown, or a scope-output if)", () => {
  for (const [f, text] of workflows()) assert.deepEqual(macPathGateProblems(text, `.github/workflows/${f}`), [], f);
  const pr = "on:\n  pull_request:\n  push:\n  workflow_dispatch:\n";
  const job = (iff) => `jobs:\n  a:\n${iff}    runs-on: macos-latest\n`;
  assert.ok(macPathGateProblems(pr + job("")).some((p) => p.includes("macOS job a")), "ungated job");
  assert.ok(macPathGateProblems(pr + job("    if: github.event_name != 'pull_request' || !github.event.pull_request.draft\n")).length > 0, "draft guard is not a path gate");
  assert.deepEqual(macPathGateProblems(pr + job("    if: ${{ github.event_name != 'pull_request' || needs.checks.outputs.mac == 'true' }}\n")), []);
  assert.deepEqual(macPathGateProblems("on:\n  pull_request:\n    paths:\n      - 'a/**'\n      - '!**/*.md'\n  push:\n" + job("")), []);
  assert.ok(macPathGateProblems("on:\n  pull_request:\n    paths:\n      - 'a/**'\n  push:\n" + job("")).length > 0, "paths list without the markdown exclusion");
  assert.deepEqual(macPathGateProblems("on:\n  workflow_dispatch:\n" + job("")), []);
});

test("D254: desktop.yml Mac jobs are narrowed by pr-scope; the GUI leg stays label/dispatch only", () => {
  const text = fs.readFileSync(new URL("desktop.yml", WF_DIR), "utf8");
  for (const name of ["cockpit-spi-tests", "app-smoke", "native-headless"]) {
    const block = text.slice(text.indexOf(`\n  ${name}:\n`)).split(/\n  [a-z][\w-]*:\n/)[1] ?? "";
    assert.match(block, /needs\.pr-scope\.outputs\.mac == 'true'/, name);
    assert.match(block, /github\.event_name != 'pull_request' \|\|/, `${name} keeps merge_group, push and dispatch unfiltered`);
  }
});

test("D254: merge_group, push, schedule and dispatch are never path-filtered or cancelled", () => {
  for (const [f, text] of workflows()) {
    assert.deepEqual(nonPrFilterProblems(text), [], f);
    assert.deepEqual(prCancelProblems(text), [], f);
    const conc = text.match(/^concurrency:\n(?:[ \t]+.*\n)+/m)?.[0] ?? "";
    if (/^\s+cancel-in-progress:\s*\$\{\{.*pull_request/m.test(conc)) assert.doesNotMatch(conc, /github\.sha/, f);
  }
  assert.deepEqual(prCancelProblems("on:\n  pull_request:\nconcurrency:\n  group: g-${{ github.event.pull_request.number }}\n  cancel-in-progress: true\n"), [], "pull_request-only workflow");
  assert.ok(prCancelProblems("on:\n  pull_request:\n  push:\nconcurrency:\n  group: g-${{ github.event.pull_request.number || github.sha }}\n  cancel-in-progress: true\n").length > 0);
  assert.ok(nonPrFilterProblems("on:\n  merge_group:\n    paths: [a]\n").length > 0);
  assert.ok(nonPrFilterProblems("on:\n  push:\n    paths: ['a', '!**/*.md']\n").length > 0);
});

test("D254: the PR-triggered Mac workflows carry the PR-only cancel and the shared-Mac legs call the pinned trusted-mac", () => {
  for (const f of ["desktop.yml", "u6-engine-store-core.yml", "u11-cockpit.yml", "official-visuals.yml", "transport-fuzz.yml", "u11a-aggregate.yml", "u14-harness.yml"]) {
    const text = fs.readFileSync(new URL(f, WF_DIR), "utf8");
    assert.match(text, /cancel-in-progress: \$\{\{ github\.event_name == 'pull_request'/, f);
  }
});

test("D254: trusted-mac.yml changes only together with a pin to exactly that content (callers and the runner group pin its SHA)", () => {
  const r = spawnSync("git", ["diff", "--quiet", "origin/main", "--", ".github/workflows/trusted-mac.yml"], { encoding: "utf8" });
  const callers = workflows().flatMap(([, t]) => [...t.matchAll(/workflows\/trusted-mac\.yml@([0-9a-f]{40})/g)].map((m) => m[1]));
  assert.ok(callers.length > 0 && callers.every((s) => /^[0-9a-f]{40}$/.test(s)), "every caller pins trusted-mac.yml by full SHA");
  // Outside a checkout with origin/main the diff cannot run; a status of 128 is not a failure of this rule.
  if (r.status !== 1) return;
  // An edit nobody pins does nothing (the callers keep running the old SHA): a change must move every pin to a commit
  // whose trusted-mac.yml is exactly this file, and the owner adds that ref to the runner group before it merges.
  const current = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  for (const sha of new Set(callers)) {
    const pinned = spawnSync("git", ["show", `${sha}:.github/workflows/trusted-mac.yml`], { encoding: "utf8" });
    assert.equal(pinned.status, 0, `pinned commit ${sha} is not in this checkout`);
    assert.equal(pinned.stdout, current, `trusted-mac.yml differs from origin/main but the pin ${sha} does not carry this content`);
  }
});

test("D254 pr-scope reads NUL-separated paths: tab, quote, newline and unicode names under desktop/native still run the Macs; failures fail closed", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  const block = text.slice(text.indexOf("\n  pr-scope:\n"));
  const sh = /run: \|\n((?:          .*\n|\n)+)/.exec(block.slice(block.indexOf("- id: scope")))[1].replace(/^          /gm, "");
  const macPaths = /MAC_PATHS: (.*)\n/.exec(block)[1];
  assert.doesNotMatch(text, /tr '\\0' '\\n'/, "no NUL-to-newline conversion of a path list");
  assert.match(text, /gui_test_selection\.py select --nul --changed/, "the GUI selector splits the NUL list itself");
  assert.doesNotMatch(sh, /name-only(?![^\n]*-z)/, "every name-only list is NUL-separated");
  const dir = fs.mkdtempSync("/tmp/d254-scope-"), tmp = fs.mkdtempSync("/tmp/d254-tmp-");
  const git = (...a) => spawnSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false", ...a], { cwd: dir, encoding: "utf8" });
  try {
    git("init", "-q", "-b", "main");
    fs.writeFileSync(`${dir}/README.md`, "x\n"); git("add", "-A"); git("commit", "-qm", "base");
    const scope = (files, extraEnv = {}) => {
      git("checkout", "-q", "-B", "pr", "main");
      for (const f of files) { fs.mkdirSync(`${dir}/${f.split("/").slice(0, -1).join("/")}`, { recursive: true }); fs.writeFileSync(`${dir}/${f}`, "y\n"); }
      git("add", "-A"); git("commit", "-qm", "pr");
      git("checkout", "-q", "-B", "merge", "main"); git("merge", "-q", "--no-ff", "-m", "m", "pr");
      const out = `${dir}.out`; fs.writeFileSync(out, "");
      const r = spawnSync("bash", ["-c", sh], { cwd: dir, env: { PATH: process.env.PATH, MAC_PATHS: macPaths, RUNNER_TEMP: tmp, GITHUB_OUTPUT: out, ...extraEnv }, encoding: "utf8" });
      return { status: r.status, out: fs.readFileSync(out, "utf8").trim() };
    };
    for (const name of ["desktop/native/with\ttab.swift", 'desktop/native/with"quote.swift', "desktop/native/with\nnewline.swift", "desktop/native/\u00fcn\u00efcode-\u4e2d.swift"])
      assert.deepEqual(scope([name]), { status: 0, out: "mac=true" }, JSON.stringify(name));
    assert.deepEqual(scope(["docs/a.txt", "desktop/native/only.md"]), { status: 0, out: "mac=false" }, "no Mac path, markdown only");
    assert.deepEqual(scope(["docs/with\ttab.txt"]), { status: 0, out: "mac=false" });
    // A failing diff stops the step instead of emitting mac=false.
    const bad = scope(["desktop/native/a.swift"], { GIT_DIR: `${dir}/nowhere` });
    assert.notEqual(bad.status, 0);
    assert.doesNotMatch(bad.out, /mac=false/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); fs.rmSync(`${dir}.out`, { force: true }); fs.rmSync(tmp, { recursive: true, force: true }); }
});

test("no workflow step asserts with a bare '! command' (bash exempts it from set -e, so a failure stays green)", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of fs.readdirSync(dir)) {
    if (!/\.(ya?ml)$/.test(f)) continue;
    const lines = fs.readFileSync(new URL(f, dir), "utf8").split("\n");
    lines.forEach((l, i) => assert.doesNotMatch(l, /^\s+!\s+(grep|test|\[)/, `${f}:${i + 1} use an explicit if ...; then exit 1; fi`));
  }
});

test("Xcode selector: self-hosted needs 26.6 build 17F113, hosted keeps the image's newest", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  const scripts = [...text.matchAll(/python3 - <<'PYCODE'\n([\s\S]*?)\n *PYCODE/g)].map((m) => m[1].replace(/^ {8}/gm, ""));
  assert.equal(scripts.length, 2);
  const run = (apps, runnerEnv) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "xcode-"));
    for (const [name, version, build] of apps) {
      fs.mkdirSync(path.join(dir, name, "Contents"), { recursive: true });
      const plist = (k, v) => `<?xml version="1.0"?><plist version="1.0"><dict><key>${k}</key><string>${v}</string></dict></plist>`;
      fs.writeFileSync(path.join(dir, name, "Contents/Info.plist"), plist("CFBundleShortVersionString", version));
      if (build) fs.writeFileSync(path.join(dir, name, "Contents/version.plist"), plist("ProductBuildVersion", build));
    }
    const out = path.join(dir, "env");
    return { r: scripts.map((code) => spawnSync("python3", ["-I", "-c", code], { encoding: "utf8", env: { PATH: process.env.PATH, XCODE_APPS_DIR: dir, GITHUB_ENV: out, RUNNER_ENVIRONMENT: runnerEnv } })), out, dir };
  };
  const good = run([["Xcode_26.6.app", "26.6", "17F113"], ["Xcode_26.3.app", "26.3", "17C529"]], "self-hosted");
  for (const r of good.r) assert.equal(r.status, 0, r.stderr);
  assert.match(fs.readFileSync(good.out, "utf8"), /Xcode_26\.6\.app\/Contents\/Developer/);
  for (const r of run([["Xcode_26.6.app", "26.6", "17F999"]], "self-hosted").r) assert.match(r.stderr, /Xcode 26\.6 \(17F113\) is not installed/);
  for (const r of run([["Xcode_26.6.app", "26.6", ""]], "self-hosted").r) assert.notEqual(r.status, 0);
  for (const r of run([["Xcode_26.3.app", "26.3", "17C529"]], "self-hosted").r) assert.notEqual(r.status, 0);
  const hosted = run([["Xcode_26.3.app", "26.3", "17C529"]], "github-hosted");
  for (const r of hosted.r) assert.equal(r.status, 0, r.stderr);
  assert.match(fs.readFileSync(hosted.out, "utf8"), /Xcode_26\.3\.app/);
});

test("packaging workflows pin Xcode 26.6 (17F113) instead of selecting the newest installed Xcode", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of ["desktop.yml", "e2e-journey.yml", "u10-candidate.yml", "macos-distribution.yml"]) {
    const text = fs.readFileSync(new URL(f, dir), "utf8");
    assert.doesNotMatch(text, /Select (the )?newest installed Xcode/i, `${f} selects the newest Xcode`);
    assert.doesNotMatch(text, /max\(candidates\)/, `${f} picks the max Xcode version`);
    assert.match(text, /WANT_VERSION, WANT_BUILD = '26\.6', '17F113'/, `${f} must pin Xcode 26.6 (17F113)`);
    assert.match(text, /is not installed on this runner/, `${f} must fail when the pinned Xcode is absent`);
    assert.match(text, /'xcodebuild', '-version'/, `${f} must log xcodebuild -version`);
  }
});

test("the merge-queue native-headless leg is hosted and a hosted merge-queue run requires Xcode 26.6 (17F113)", () => {
  const text = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  const job = text.slice(text.indexOf("\n  native-headless:\n"));
  const guard = job.slice(job.indexOf("- name: Require Xcode 26.6 (17F113) on a hosted merge-queue run"));
  assert.ok(guard.length < job.length, "the guard step exists in native-headless");
  assert.match(guard, /if: \$\{\{ github\.event_name == 'merge_group' && runner\.environment == 'github-hosted' \}\}/);
  assert.match(guard, /Xcode 26\\\.6\$/);
  assert.match(guard, /17F113/);
  assert.doesNotMatch(TRUSTED_MAC_ROUTE, /native-headless'\) && github\.event_name == 'merge_group'/);
});

test("the nightly schedule reaches the GUI Mac without the actor gate only from desktop.yml on main with the nightly cron, for the GUI tasks (D169, D193)", () => {
  // A scheduled run's actor is whoever last changed the cron (the merge-queue bot), so the owner-actor gate would
  // send the nightly to hosted macOS. github.workflow_ref is the caller's identity, github.event.schedule the cron.
  const bypass = "(github.repository == 'modelplan/modelplan' && github.event_name == 'schedule' && github.ref == 'refs/heads/main' && github.workflow_ref == 'modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main' && github.event.schedule == '23 9 * * *' && (inputs.task == 'native' || inputs.task == 'native-owner-gui'))";
  const ownerGate = "(github.repository == 'modelplan/modelplan' && github.actor_id == '11829005' && github.actor == 'guanbear' && github.triggering_actor == 'guanbear')";
  const gui = TRUSTED_MAC_ROUTE.split("|| (inputs.os == 'ubuntu-latest'")[0].split("&& (inputs.task != 'native-headless'")[1];
  assert.ok(gui.includes(`(${ownerGate} || ${bypass}) && (((github.event_name == 'pull_request'`), "owner gate OR the narrow nightly bypass, then the event list");
  assert.equal(TRUSTED_MAC_ROUTE.split(bypass).length - 1, 1, "one bypass only");
  assert.ok(gui.includes("((inputs.task == 'native' || inputs.task == 'native-owner-gui') && github.event_name == 'schedule' && github.ref == 'refs/heads/main')"));
  assert.equal(gui.split("github.event_name == 'schedule'").length - 1, 2, "schedule appears in the bypass and the GUI-task clause only");
  // The cron the route names is exactly the one desktop.yml declares, and desktop.yml declares only that one.
  const desktop = fs.readFileSync(new URL("../../.github/workflows/desktop.yml", import.meta.url), "utf8");
  assert.deepEqual([...desktop.matchAll(/^\s+- cron: "([^"]+)"/gm)].map((m) => m[1]), ["23 9 * * *"]);
  assert.equal(workflows().filter(([, t]) => /^\s+- cron:/m.test(t) && /trusted-mac\.yml@/.test(t)).length, 1, "desktop.yml is the only scheduled caller of trusted-mac.yml");
  // Evaluate the bypass for synthetic events: only the nightly passes.
  const base = { repo: "modelplan/modelplan", event: "schedule", ref: "refs/heads/main", wf: "modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main", cron: "23 9 * * *", task: "native" };
  const pass = (e) => e.repo === "modelplan/modelplan" && e.event === "schedule" && e.ref === "refs/heads/main" && e.wf === "modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main" && e.cron === "23 9 * * *" && (e.task === "native" || e.task === "native-owner-gui");
  assert.ok(pass(base) && pass({ ...base, task: "native-owner-gui" }));
  for (const bad of [{ cron: "0 3 * * *" }, { wf: "modelplan/modelplan/.github/workflows/other.yml@refs/heads/main" }, { wf: "modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/x" }, { event: "workflow_dispatch" }, { event: "push" }, { event: "pull_request" }, { repo: "fork/modelplan" }, { ref: "refs/heads/x" }, { task: "native-headless" }, { task: "probe" }, { task: "u11-native" }]) assert.ok(!pass({ ...base, ...bad }), JSON.stringify(bad));
  for (const part of ["github.event_name == 'schedule'", "github.workflow_ref == 'modelplan/modelplan/.github/workflows/desktop.yml@refs/heads/main'", "github.event.schedule == '23 9 * * *'", "github.ref == 'refs/heads/main'", "github.repository == 'modelplan/modelplan'", "inputs.task == 'native-owner-gui'"]) assert.ok(bypass.includes(part), part);
});
