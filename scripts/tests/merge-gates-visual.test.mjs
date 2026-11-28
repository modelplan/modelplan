// SPDX-License-Identifier: MIT
// D489: the full-cockpit visual check in modelplan-gates (scripts/merge-gates/visual.mjs and its rules.mjs wiring).
import test from "node:test";
import assert from "node:assert/strict";
import * as V from "../merge-gates/visual.mjs";
import * as R from "../merge-gates/rules.mjs";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const H = "a".repeat(40), OLD = "b".repeat(40), BASE = "c".repeat(40);
const ME = { login: "guanbear", id: 11829005 };
const comment = (body, user = ME) => ({ user, body, created_at: "2026-11-28T00:00:00Z" });
const AREAS = { canopy: ["window"], grip: ["levers"], band: [], hull: [], mfd: ["big-screen"] };
const note = (title, message) => ({ title, annotation_level: "notice", message: typeof message === "string" ? message : JSON.stringify(message) });
const meta = (over = {}) => note(V.META_TITLE, { v: 1, base: BASE, subject: H, head: H, areas: AREAS, ...over });
const box = (x, y, w, h, cover) => [x, y, w, h, Object.values(cover).reduce((s, n) => s + n, 0), cover];
const scene = (name, boxes = []) => note(V.SCENE_TITLE, { v: 1, scene: name, size: [636, 951], pixels: boxes.reduce((s, b) => s + b[4], 0), boxes });
const record = (boxesByScene = {}) => [meta(), ...V.SCENES.map((s) => scene(s, boxesByScene[s] ?? []))];

test("Visual-change lines: names and aliases, commas or spaces, bold, several lines, none", () => {
  assert.deepEqual(V.parseVisualChange("Decision: D489\nVisual-change: grip, band\n"), { present: true, areas: ["grip", "band"] });
  assert.deepEqual(V.parseVisualChange("**Visual-change:** Levers  Canopy"), { present: true, areas: ["levers", "canopy"] });
  assert.deepEqual(V.parseVisualChange("Visual-change: grip\r\nvisual-change: `tape`"), { present: true, areas: ["grip", "tape"] });
  assert.deepEqual(V.parseVisualChange("Visual-change: none"), { present: true, areas: [] });
  assert.deepEqual(V.parseVisualChange("Visual change: grip\nsee Visual-change: grip in text"), { present: false, areas: [] }, "the key starts the line, hyphenated");
  assert.deepEqual(V.parseVisualChange(null), { present: false, areas: [] });
});

test("VISUAL-ACCEPT counts only from the trusted feed, on its own line, at the exact head", () => {
  const items = (body, user) => R.feed([comment(body, user)], []);
  assert.ok(V.visualAccepted(items(`ok\nVISUAL-ACCEPT @ ${H}\n`), H));
  assert.ok(!V.visualAccepted(items(`VISUAL-ACCEPT @ ${OLD}`), H), "another head");
  assert.ok(!V.visualAccepted(items(`VISUAL-ACCEPT @ ${H}`, { login: "someone", id: 2 }), H), "untrusted author");
  assert.ok(!V.visualAccepted(items(`please VISUAL-ACCEPT @ ${H}`), H), "not on its own line");
  assert.ok(!V.visualAccepted(items(`VISUAL-ACCEPT @ ${H.slice(0, 12)}`), H), "short sha");
});

test("records: exactly one meta, one valid record per scene; anything else is unreadable", () => {
  assert.ok(V.parseVisualRecord(record()).ok);
  assert.equal(V.parseVisualRecord(undefined).ok, false);
  assert.match(V.parseVisualRecord(record().slice(0, 4)).why, /no record for full-night-zh-CN/);
  assert.match(V.parseVisualRecord([meta(), ...record()]).why, /2 D489 cockpit visual records/);
  assert.match(V.parseVisualRecord([...record(), scene("full-day-en")]).why, /invalid scene record full-day-en/, "duplicate scene");
  assert.match(V.parseVisualRecord([meta({ base: "x" }), ...record().slice(1)]).why, /invalid meta/);
  const badSum = record(); badSum[1] = note(V.SCENE_TITLE, { v: 1, scene: "full-day-en", size: [636, 951], pixels: 9, boxes: [[1, 1, 2, 2, 9, { grip: 3 }]] });
  assert.match(V.parseVisualRecord(badSum).why, /invalid scene record/, "cover must sum to the box pixels");
  const warn = record(); warn[2] = { ...warn[2], annotation_level: "warning" };
  assert.equal(V.parseVisualRecord(warn).ok, false, "only notice annotations count");
});

test("box classification: every key of a box must share an area with the declaration", () => {
  const rec = V.parseVisualRecord(record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })], "full-night-en": [box(50, 640, 20, 30, { grip: 100, "grip+hull": 4 })] }));
  const no = V.judgeVisual(rec, { declared: [], present: false });
  assert.equal(no.state, "failure");
  assert.match(no.why, /\(no Visual-change line\): full-day-en 50,660 20x40 \(300 px\) in grip; full-night-en 50,640 20x30 \(104 px\) in grip\+hull/);
  assert.equal(V.judgeVisual(rec, { declared: ["grip"], present: true }).state, "success");
  assert.equal(V.judgeVisual(rec, { declared: ["levers"], present: true }).state, "success", "alias");
  assert.equal(V.judgeVisual(rec, { declared: ["hull"], present: true }).outside.length, 2, "pixels only in grip stay outside");
  const none = V.judgeVisual(rec, { declared: [], present: true });
  assert.match(none.why, /\(none\)/);
  const outside = V.parseVisualRecord(record({ "full-day-zh-CN": [box(300, 900, 4, 4, { "": 10, band: 6 })] }));
  const r = V.judgeVisual(outside, { declared: ["band", "wing"], present: true });
  assert.equal(r.state, "failure", "the pixels in no area fail even with band declared");
  assert.match(r.why, /in band; unknown area wing \(known: canopy, grip, band, hull, mfd\)/);
  assert.equal(V.judgeVisual(V.parseVisualRecord(record()), {}).why, "visual: no pixel change");
});

test("VISUAL-ACCEPT passes any change at the head; an unreadable record never passes", () => {
  const rec = V.parseVisualRecord(record({ "full-day-en": [box(0, 0, 636, 951, { "": 5000 })] }));
  assert.equal(V.judgeVisual(rec, { accepted: true }).state, "success");
  assert.equal(V.judgeVisual(V.parseVisualRecord(undefined), { accepted: true }).state, "failure");
});

test("visualState: only a green run with a visual job is judged", () => {
  const run = (over = {}) => ({ id: 3, path: V.VISUAL_WORKFLOW, status: "completed", conclusion: "success", ...over });
  const job = { name: V.VISUAL_JOB, conclusion: "success" };
  assert.equal(V.visualState(null), null, "no cockpit run: no cockpit change");
  assert.equal(V.visualState({ run: run({ status: "in_progress" }) }), null, "ciState holds it");
  assert.equal(V.visualState({ run: run({ conclusion: "failure" }) }), null, "ciState fails it");
  assert.equal(V.visualState({ run: run(), job: null }), null, "a run made before D489 landed");
  assert.equal(V.visualState({ run: run(), job: { ...job, conclusion: "skipped" } }), null, "queue-scope skipped it");
  const bind = V.bindPr(H, { declared: [], present: false, accepted: false }, BASE);
  assert.equal(V.visualState({ run: run({ head_sha: H }), job, annotations: undefined }, bind).state, "failure");
  assert.equal(V.visualState({ run: run({ head_sha: H }), job, annotations: record() }, bind).state, "success");
  assert.equal(V.visualRun([run({ id: 1 }), run({ id: 5 }), { ...run({ id: 9 }), path: ".github/workflows/ci.yml" }]).id, 5);
});

// ---- rules.mjs wiring ----
const conf = R.parseDesignConf("");
const runOf = (path, id = 1, over = {}) => ({ id, workflow_id: path, path, name: path.split("/").pop(), status: "completed", conclusion: "success",
  head_sha: H, head_repository: { full_name: "modelplan/modelplan" }, head_branch: "feature/x", event: "pull_request", pull_requests: [{ number: 7 }], ...over });
const pr = (body = "") => ({ number: 7, state: "open", draft: false, user: ME, body, labels: [],
  head: { sha: H, ref: "feature/x", repo: { full_name: "modelplan/modelplan" } }, base: { ref: "main", repo: { full_name: "modelplan/modelplan" } } });
const runs = [runOf(".github/workflows/ci.yml"), runOf(V.VISUAL_WORKFLOW, 2)];
const gripChange = record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })] });
const evalPr = ({ body = "", comments = [], annotations = gripChange } = {}) => R.evaluatePr({ pr: pr(body), items: R.feed(comments, []), files: [{ filename: "desktop/cockpit/src/cockpit.css" }],
  runs, statuses: [], verifiedEdge: () => false, conf, visual: { run: runs[1], job: { name: "visual", conclusion: "success" }, annotations, expectedBase: BASE } });

test("evaluatePr: an undeclared change fails naming scene, box and area; declaring or accepting it lets the review gate decide", () => {
  const r = evalPr();
  assert.equal(r.state, R.FAILURE);
  assert.match(r.why, /^visual change outside declared areas \(no Visual-change line\): full-day-en 50,660 20x40 \(300 px\) in grip/);
  assert.deepEqual(r.visual, { declared: [], present: false, accepted: false });
  for (const o of [{ body: "Visual-change: grip" }, { comments: [comment(`VISUAL-ACCEPT @ ${H}`)] }]) {
    const ok = evalPr({ ...o, comments: [...(o.comments ?? []), comment(`VERDICT: merge @ ${H} (ghglm)`)] });
    assert.equal(ok.state, R.SUCCESS, ok.why);
  }
  assert.equal(evalPr({ body: "Visual-change: band" }).state, R.FAILURE);
  assert.equal(evalPr({ comments: [comment(`VISUAL-ACCEPT @ ${OLD}`)] }).state, R.FAILURE, "an accept for an older head");
  assert.equal(evalPr({ annotations: undefined }).state, R.FAILURE, "unreadable report");
  assert.notEqual(evalPr({ annotations: record() }).state, R.FAILURE, "no change needs no declaration");
});

test("evaluateGroup: the group diff may change the union of its PRs' declared areas, or anything if one accepted", () => {
  const qrun = (path, id = 1) => runOf(path, id, { head_branch: `gh-readonly-queue/main/pr-7-${BASE}`, event: "merge_group", pull_requests: [] });
  const queueRuns = R.QUEUE_WORKFLOWS.map((p, i) => qrun(p, i + 1));
  const visualRun = queueRuns.find((r) => r.path === V.VISUAL_WORKFLOW);
  const twoAreas = record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })], "full-night-en": [box(30, 300, 10, 10, { band: 50 })] });
  const step = (pr, visual, base) => ({ pr, prResult: { state: R.SUCCESS, why: "ok", hostedExempt: true, visual }, mergeProof: { ok: true }, base });
  const group = (a, b) => R.evaluateGroup({ steps: [step(1, a, BASE), step(2, b, OLD)], queueRuns, groupSha: H, visual: { run: visualRun, job: { name: "visual", conclusion: "success" }, annotations: twoAreas } });
  const decl = (...declared) => ({ declared, present: true, accepted: false });
  assert.equal(group(decl("grip"), decl("band")).state, R.SUCCESS);
  const one = group(decl("grip"), decl());
  assert.equal(one.state, R.FAILURE);
  assert.match(one.why, /^group visual change outside declared areas \(grip\): full-night-en 30,300 10x10 \(50 px\) in band/);
  assert.equal(group(decl("grip"), { ...decl(), accepted: true }).state, R.SUCCESS);
  assert.equal(R.evaluateGroup({ steps: [step(1, decl())], queueRuns }).state, R.SUCCESS, "no visual data: no cockpit change in the group");
});

// R11 ruling (#1320 round 3, macrev2-1320-3 / macrevb-1320-2): a report counts only when its base is exactly the base the gate
// computes now and its head is the evaluated head. PR: otherwise PENDING "re-run U11"; group: otherwise FAILURE.
const zeroWith = (over) => [meta(over), ...record().slice(1)];
const greenRun = (over = {}) => ({ id: 4, path: V.VISUAL_WORKFLOW, status: "completed", conclusion: "success", head_sha: H, ...over });
const job = { name: "visual", conclusion: "success" };

test("bindPr: a report for another head or another head's run is pending; another base is judged with a note", () => {
  const decl = { declared: [], present: false, accepted: false };
  const st = (annotations, expectedBase = BASE, run = greenRun()) => V.visualState({ run, job, annotations, expectedBase }, V.bindPr(H, decl, expectedBase));
  assert.equal(st(record()).state, "success", "report for the current base");
  assert.equal(st(record()).why, "visual: no pixel change", "no note at the current base");
  for (const [why, r] of [
    ["missing head", st(zeroWith({ head: undefined }))],
    ["other head", st(zeroWith({ head: OLD }))],
    ["another head's run", st(record(), BASE, greenRun({ head_sha: OLD }))],
  ]) { assert.equal(r.state, "pending", why); assert.match(r.why, /^visual report is for another base — re-run U11 \(report base/, why); }
  for (const [why, r] of [["other base", st(zeroWith({ base: OLD }))], ["merge ref unreadable", st(record(), null)]]) {
    assert.equal(r.state, "success", why);
    assert.match(r.why, /; report base (bbbbbbbb|cccccccc) ≠ current base (cccccccc|none); the merge queue re-checks against the exact base$/, why);
  }
});

test("reviewer case macrevb-1320-2: at PR level the earlier-base report is judged with a note; the merge group fails it", () => {
  // main moved from A to B; the PR head H is unchanged. The run carries a self-consistent report for the earlier merge
  // (base A, same head) with an undeclared MFD change.
  const A = "1".repeat(40), B = "2".repeat(40);
  const mfd = record({ "full-night-en": [box(398, 598, 4, 4, { mfd: 16 })] }).slice(1);
  const earlier = [meta({ base: A }), ...mfd], earlierZero = [meta({ base: A }), ...record().slice(1)];
  const prRuns = [runOf(".github/workflows/ci.yml"), runOf(V.VISUAL_WORKFLOW, 2)];
  const ev = (annotations, { comments = [], body = "" } = {}) => R.evaluatePr({ pr: pr(body), items: R.feed([...comments, comment(`VERDICT: merge @ ${H} (ghglm)`)], []), files: [{ filename: "desktop/cockpit/src/cockpit.css" }],
    runs: prRuns, statuses: [], verifiedEdge: () => false, conf, visual: { run: prRuns[1], job, annotations, expectedBase: B } });
  const undeclared = ev(earlier);
  assert.equal(undeclared.state, R.FAILURE, "judged normally: the undeclared change fails");
  assert.match(undeclared.why, /full-night-en 398,598 4x4 \(16 px\) in mfd.*report base 11111111 ≠ current base 22222222; the merge queue re-checks against the exact base/);
  assert.equal(ev(earlier, { body: "Visual-change: mfd" }).state, R.SUCCESS, "declaration applies");
  assert.equal(ev(earlier, { comments: [comment(`VISUAL-ACCEPT @ ${H}`)] }).state, R.SUCCESS, "accept applies");
  assert.match(ev(earlierZero).why, /report base 11111111 ≠ current base 22222222/, "zero change passes at PR level, with the note");
  // the same earlier-base report in the merge group (base_sha B) fails: the binding check before main
  const qr = (path, id) => runOf(path, id, { head_branch: `gh-readonly-queue/main/pr-7-${B}`, event: "merge_group", pull_requests: [] });
  const queueRuns = R.QUEUE_WORKFLOWS.map((p, i) => qr(p, i + 1)), vrun = queueRuns.find((r) => r.path === V.VISUAL_WORKFLOW);
  const step = { pr: 7, mergeProof: { ok: true }, prResult: { state: R.SUCCESS, why: "ok", hostedExempt: true, visual: { declared: [], present: false, accepted: true } } };
  const g = R.evaluateGroup({ steps: [step], queueRuns, groupSha: H, visual: { run: vrun, job, annotations: earlierZero } });
  assert.equal(g.state, R.FAILURE, "even zero change and an accept do not bind another base in the group");
  assert.match(g.why, /^group visual report is for another comparison \(report base 11111111 head aaaaaaaa; expected base 22222222 head aaaaaaaa\)/);
});

test("bindGroup: report head is the group commit and base the queue branch's merge_group.base_sha, else failure", () => {
  const run = greenRun({ head_branch: `gh-readonly-queue/main/pr-7-${BASE}`, event: "merge_group" });
  const grip = record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })] });
  const steps = [{ decl: { declared: ["grip"], present: true, accepted: false } }, { decl: { declared: [], present: true, accepted: false } }];
  const st = (annotations, groupSha = H, r = run) => V.visualState({ run: r, job, annotations }, V.bindGroup(groupSha, steps));
  assert.equal(V.queueBase(run), BASE);
  assert.equal(st(grip).state, "success", "union of the group's declarations");
  for (const [why, r] of [
    ["other base", st([meta({ base: OLD }), ...grip.slice(1)])],
    ["other head", st([meta({ head: OLD }), ...grip.slice(1)])],
    ["another commit's run", st(grip, H, { ...run, head_sha: OLD })],
    ["no group sha", st(grip, null)],
    ["queue branch without a base", st(grip, H, { ...run, head_branch: "feature/x" })],
  ]) { assert.equal(r.state, "failure", why); assert.match(r.why, /^visual report is for another comparison/, why); }
});

test("rollout marker: rules.mjs carries the exact line the visual job looks for on main", async () => {
  const { readFileSync } = await import("node:fs");
  const text = readFileSync(new URL("../merge-gates/rules.mjs", import.meta.url), "utf8");
  assert.ok(text.split("\n").includes(`export const VISUAL_DIFF_MARKER = "${R.VISUAL_DIFF_MARKER}";`));
  assert.equal(R.VISUAL_DIFF_MARKER, "D489-v1", "desktop/tests/cockpit/visual-diff.mjs MARKER_LINE names this value");
});

// macrevb-1320-3: a merge group never reuses a PR visual report. Replay: the PR passed against base A; main moved to B (an
// ancestor of the head H) and changed the cockpit; H reverts that change, so the group commit's tree equals H's tree,
// yet B -> group changes pixels.
const workflow = readFileSync(new URL("../../.github/workflows/u11-cockpit.yml", import.meta.url), "utf8");
function scopeScript() {
  const lines = workflow.split("\n"), at = lines.findIndex((l) => l.trim() === "- id: scope");
  const run = lines.findIndex((l, i) => i > at && l.trim() === "run: |");
  const out = [];
  for (let i = run + 1; i < lines.length && (lines[i].startsWith("          ") || !lines[i].trim()); i++) out.push(lines[i].slice(10));
  return out.join("\n");
}

test("queue-scope: the visual path list is the gate's; the visual job runs on the group's own watched changes", () => {
  const queuePaths = /QUEUE_PATHS: (.*)$/m.exec(workflow)[1];
  assert.equal(queuePaths, V.VISUAL_PATHS, "VISUAL_PATHS mirrors u11-cockpit.yml QUEUE_PATHS");
  const visualJob = workflow.slice(workflow.indexOf("\n  visual:\n"));
  assert.match(visualJob, /if: \$\{\{ !cancelled\(\) && \(github\.event_name != 'merge_group' \|\| needs\.queue-scope\.outputs\.visual == 'true'\) \}\}/);
  assert.doesNotMatch(visualJob.split("\n").slice(0, 6).join("\n"), /outputs\.run/, "the visual job never follows the tree-equal reuse");
});

test("queue-scope replay: tree-equal group whose head reverts a cockpit change main made since -> visual runs, checks reuse", () => {
  const dir = mkdtempSync(join(tmpdir(), "queue-scope-"));
  const g = (...args) => execFileSync("git", args, { cwd: dir, encoding: "utf8", env: { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@example.invalid" } }).trim();
  const scope = (base) => {
    const out = join(dir, ".out");
    writeFileSync(out, "");
    execFileSync("bash", ["-c", scopeScript()], { cwd: dir, env: { ...process.env, BASE: base, GITHUB_OUTPUT: out, QUEUE_PATHS: V.VISUAL_PATHS }, stdio: ["ignore", "ignore", "inherit"] });
    return Object.fromEntries(readFileSync(out, "utf8").trim().split("\n").map((l) => l.split("=")));
  };
  try {
    g("init", "-q", "-b", "main");
    mkdirSync(join(dir, "desktop/cockpit/web"), { recursive: true });
    writeFileSync(join(dir, "desktop/cockpit/web/cockpit.css"), ".grip{color:#fff}\n"); writeFileSync(join(dir, "README.md"), "a\n");
    g("add", "-A"); g("commit", "-qm", "A");
    writeFileSync(join(dir, "desktop/cockpit/web/cockpit.css"), ".grip{color:#f00}\n");
    g("commit", "-qam", "B: main changes the grip"); const B = g("rev-parse", "HEAD");
    g("checkout", "-qb", "pr");
    writeFileSync(join(dir, "desktop/cockpit/web/cockpit.css"), ".grip{color:#fff}\n");
    g("commit", "-qam", "H: PR reverts the grip"); const H = g("rev-parse", "HEAD");
    g("checkout", "-q", "--detach", B); g("merge", "-q", "--no-ff", "--no-edit", H);
    assert.equal(g("rev-parse", "HEAD^{tree}"), g("rev-parse", `${H}^{tree}`), "tree-equal group");
    assert.deepEqual(scope(B), { visual: "true", run: "false" }, "other checks reuse the head; the visual job runs against B");
    // a group whose head changes no watched path against its base skips the visual job
    g("checkout", "-q", "--detach", B); writeFileSync(join(dir, "README.md"), "b\n"); g("commit", "-qam", "docs"); const D = g("rev-parse", "HEAD");
    g("checkout", "-q", "--detach", B); g("merge", "-q", "--no-ff", "--no-edit", D);
    assert.equal(scope(B).visual, "false");
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test("gate replay: a group that changes cockpit paths since its base needs a report bound to that base", () => {
  const A = "1".repeat(40), B = "2".repeat(40);
  const qr = (path, id, over = {}) => runOf(path, id, { head_branch: `gh-readonly-queue/main/pr-7-${B}`, event: "merge_group", pull_requests: [], ...over });
  const queueRuns = R.QUEUE_WORKFLOWS.map((p, i) => qr(p, i + 1)), vrun = queueRuns.find((r) => r.path === V.VISUAL_WORKFLOW);
  // the PR passed at PR level on its stale base A (zero change, base note)
  const prRuns = [runOf(".github/workflows/ci.yml"), runOf(V.VISUAL_WORKFLOW, 2)];
  const prRes = R.evaluatePr({ pr: pr(""), items: R.feed([comment(`VERDICT: merge @ ${H} (ghglm)`)], []), files: [{ filename: "desktop/cockpit/web/cockpit.css" }],
    runs: prRuns, statuses: [], verifiedEdge: () => false, conf, visual: { run: prRuns[1], job, annotations: [meta({ base: A }), ...record().slice(1)], expectedBase: B } });
  assert.equal(prRes.state, R.SUCCESS, prRes.why);
  const step = { pr: 7, mergeProof: { ok: true }, prResult: prRes };
  const group = (visual, visualRequired = true) => R.evaluateGroup({ steps: [step], queueRuns, groupSha: H, visual, visualRequired });
  for (const [why, visual] of [["visual job skipped (old tree-equal reuse)", { run: vrun, job: { name: "visual", conclusion: "skipped" } }],
    ["no visual job", { run: vrun, job: null }], ["no run read", { run: null }]]) {
    const r = group(visual);
    assert.equal(r.state, R.FAILURE, why);
    assert.match(r.why, /^group changes cockpit paths since its base but .*; no visual comparison against the queue base$/, why);
  }
  assert.equal(group({ run: vrun, job: { name: "visual", conclusion: "skipped" } }, false).state, R.SUCCESS, "no watched change since the base: nothing to compare");
  const pixels = [meta({ base: B }), ...record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })] }).slice(1)];
  const ran = group({ run: vrun, job, annotations: pixels });
  assert.equal(ran.state, R.FAILURE, "the job ran against B: the reverted grip shows and is undeclared");
  assert.match(ran.why, /full-day-en 50,660 20x40 \(300 px\) in grip/);
  assert.equal(group({ run: vrun, job, annotations: [meta({ base: A }), ...pixels.slice(1)] }).state, R.FAILURE, "a report for A never binds the group");
  assert.ok(V.visualPathsChanged(["desktop/cockpit/web/cockpit.css"]) && !V.visualPathsChanged(["README.md"]) && V.visualPathsChanged(null));
});
