// SPDX-License-Identifier: MIT
// D489: the full-cockpit visual check in modelplan-gates (scripts/merge-gates/visual.mjs and its rules.mjs wiring).
import test from "node:test";
import assert from "node:assert/strict";
import * as V from "../merge-gates/visual.mjs";
import * as R from "../merge-gates/rules.mjs";

const H = "a".repeat(40), OLD = "b".repeat(40), BASE = "c".repeat(40);
const ME = { login: "guanbear", id: 11829005 };
const comment = (body, user = ME) => ({ user, body, created_at: "2026-11-28T00:00:00Z" });
const AREAS = { canopy: ["window"], grip: ["levers"], band: [], hull: [] };
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
  assert.match(r.why, /in band; unknown area wing \(known: canopy, grip, band, hull\)/);
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
  assert.equal(V.visualState({ run: run(), job, annotations: undefined }).state, "failure");
  assert.equal(V.visualState({ run: run(), job, annotations: record() }).state, "success");
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
  runs, statuses: [], verifiedEdge: () => false, conf, visual: { run: runs[1], job: { name: "visual", conclusion: "success" }, annotations } });

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
  const qrun = (path, id = 1) => runOf(path, id, { head_branch: `gh-readonly-queue/main/pr-7-${OLD}`, event: "merge_group", pull_requests: [] });
  const queueRuns = R.QUEUE_WORKFLOWS.map((p, i) => qrun(p, i + 1));
  const visualRun = queueRuns.find((r) => r.path === V.VISUAL_WORKFLOW);
  const twoAreas = record({ "full-day-en": [box(50, 660, 20, 40, { grip: 300 })], "full-night-en": [box(30, 300, 10, 10, { band: 50 })] });
  const step = (pr, visual) => ({ pr, prResult: { state: R.SUCCESS, why: "ok", hostedExempt: true, visual }, mergeProof: { ok: true } });
  const group = (a, b) => R.evaluateGroup({ steps: [step(1, a), step(2, b)], queueRuns, visual: { run: visualRun, job: { name: "visual", conclusion: "success" }, annotations: twoAreas } });
  const decl = (...declared) => ({ declared, present: true, accepted: false });
  assert.equal(group(decl("grip"), decl("band")).state, R.SUCCESS);
  const one = group(decl("grip"), decl());
  assert.equal(one.state, R.FAILURE);
  assert.match(one.why, /^group visual change outside declared areas \(grip\): full-night-en 30,300 10x10 \(50 px\) in band/);
  assert.equal(group(decl("grip"), { ...decl(), accepted: true }).state, R.SUCCESS);
  assert.equal(R.evaluateGroup({ steps: [step(1, decl())], queueRuns }).state, R.SUCCESS, "no visual data: no cockpit change in the group");
});
