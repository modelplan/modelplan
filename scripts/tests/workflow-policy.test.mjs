// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { ALLOWED_ROUTES, GUI_LEND_GUARD, NONGUI_JOBS, TRUSTED_MAC_ROUTE, draftGuardProblems, guiGuardProblems, isWorkflowFile, macConcurrencyProblems, workflowProblems } from "../workflow-policy.mjs";
import { spawnSync } from "node:child_process";

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
  assert.ok(TRUSTED_MAC_ROUTE.includes("inputs.os == 'macos-latest' && inputs.task != 'native-hosted-gui' &&"));
  assert.ok(TRUSTED_MAC_ROUTE.includes("((inputs.task != 'native' && inputs.task != 'native-owner-gui') || vars.MAC_CI_GUI == 'enabled')"), "owner GUI tasks still need MAC_CI_GUI");
  const reusable = fs.readFileSync(new URL("../../.github/workflows/trusted-mac.yml", import.meta.url), "utf8");
  assert.deepEqual(guiGuardProblems(reusable), [], "every non-GUI job opens with the D94 GUI guard");
  // Every caller uses one pin, the one that carries this route.
  const dir = new URL("../../.github/workflows/", import.meta.url);
  const pins = new Set();
  for (const f of fs.readdirSync(dir)) for (const m of fs.readFileSync(new URL(f, dir), "utf8").matchAll(/trusted-mac\.yml@([0-9a-f]{40})/g)) pins.add(m[1]);
  assert.equal(pins.size, 1, [...pins].join(" "));
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
