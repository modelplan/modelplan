// SPDX-License-Identifier: MIT
// D489 (owner 2026-11-28): the full-cockpit visual check without shared baseline images.
// The `visual` job of U11 cockpit web (.github/workflows/u11-cockpit.yml) renders the four full-* scenes for the PR's
// base and head on one runner, pixel-diffs them (desktop/tests/cockpit/visual-diff.mjs) and records the result as
// notice annotations: one META_TITLE record and one SCENE_TITLE record per scene. modelplan-gates reads them back and
// decides here, so a later `Visual-change:` edit of the PR body or a trusted VISUAL-ACCEPT comment re-evaluates without
// a new render.
//
// Rule: every changed pixel must lie inside the union of the areas the PR body declares on a `Visual-change:` line
// (names or aliases from desktop/tests/cockpit/visual-areas.json; `none` declares nothing). No line declares nothing,
// so any change fails. A trusted comment line `VISUAL-ACCEPT @ <head sha>` accepts every change at that head.
// Each box carries `cover`: changed-pixel counts keyed by the "+"-joined set of areas containing the pixel ("" = in
// no area). A box is outside the declaration when any of its keys shares no area with it.

export const VISUAL_WORKFLOW = ".github/workflows/u11-cockpit.yml";
export const VISUAL_JOB = "visual";
export const META_TITLE = "D489 cockpit visual";
export const SCENE_TITLE = "D489 cockpit visual scene";
export const SCENES = Object.freeze(["full-day-en", "full-day-zh-CN", "full-night-en", "full-night-zh-CN"]);
// GitHub truncates an annotation message at 4096 characters; a record must stay under it.
export const RECORD_MAX = 4000;
const SHA = /^[0-9a-f]{40}$/;
const NAME = /^[a-z][a-z0-9-]{0,31}$/;

const VISUAL_LINE = /^\s*\**Visual-change(?::\*{0,2}|\*{0,2}:)\s*(.*)$/i;
// The PR body's declaration: every `Visual-change:` line counts (names split on commas or spaces, lower-cased).
export function parseVisualChange(body) {
  const areas = new Set();
  let present = false;
  for (const line of String(body ?? "").split("\n")) {
    const m = VISUAL_LINE.exec(line.replace(/\r$/, ""));
    if (!m) continue;
    present = true;
    for (const name of m[1].replace(/[`*]/g, "").split(/[\s,]+/).map((s) => s.trim().toLowerCase()).filter(Boolean))
      if (name !== "none") areas.add(name);
  }
  return { present, areas: [...areas] };
}

const ACCEPT_LINE = /^\s*VISUAL-ACCEPT @ ([0-9a-f]{40})\s*$/;
// items: the trusted feed (rules.mjs feed()), so only the trusted account's comments and reviews reach here.
export function visualAccepted(items, head) {
  return (items ?? []).some((x) => String(x.body ?? "").split("\n").some((l) => ACCEPT_LINE.exec(l.replace(/\r$/, ""))?.[1] === head));
}

function validBox(b) {
  if (!Array.isArray(b) || b.length !== 6 || !b.slice(0, 5).every((n) => Number.isInteger(n) && n >= 0)) return false;
  const cover = b[5];
  if (!cover || typeof cover !== "object" || Array.isArray(cover)) return false;
  const entries = Object.entries(cover);
  return entries.length > 0 && entries.every(([k, n]) => Number.isInteger(n) && n > 0 && (k === "" || k.split("+").every((a) => NAME.test(a))))
    && entries.reduce((s, [, n]) => s + n, 0) === b[4];
}

// annotations: the visual job's check-run annotations. Returns { ok, why } or { ok, meta, scenes: Map(scene -> record) }.
// Anything missing, duplicated or malformed is not ok, which never passes.
export function parseVisualRecord(annotations) {
  if (!Array.isArray(annotations)) return { ok: false, why: "visual report unreadable" };
  const notes = (title) => annotations.filter((a) => a?.title === title && a.annotation_level === "notice");
  const json = (s) => { try { return JSON.parse(s); } catch { return null; } };
  const metas = notes(META_TITLE);
  if (metas.length !== 1) return { ok: false, why: `visual report: ${metas.length} ${META_TITLE} records` };
  const meta = json(metas[0].message);
  if (!meta || meta.v !== 1 || !SHA.test(meta.base ?? "") || !SHA.test(meta.subject ?? "") || !meta.areas || typeof meta.areas !== "object"
    || !Object.entries(meta.areas).every(([n, al]) => NAME.test(n) && Array.isArray(al) && al.every((a) => NAME.test(a))))
    return { ok: false, why: "visual report: invalid meta record" };
  const scenes = new Map();
  for (const a of notes(SCENE_TITLE)) {
    const r = json(a.message);
    if (!r || r.v !== 1 || !SCENES.includes(r.scene) || scenes.has(r.scene) || !Number.isInteger(r.pixels) || !Array.isArray(r.boxes)
      || !r.boxes.every(validBox) || r.boxes.reduce((s, b) => s + b[4], 0) !== r.pixels)
      return { ok: false, why: `visual report: invalid scene record${r?.scene ? ` ${r.scene}` : ""}` };
    scenes.set(r.scene, r);
  }
  const missing = SCENES.filter((s) => !scenes.has(s));
  if (missing.length) return { ok: false, why: `visual report: no record for ${missing.join(", ")}` };
  return { ok: true, meta, scenes };
}

// Declared names (or aliases) -> canonical area names, using the area list the report carries.
export function resolveDeclared(declared, areas) {
  const byName = new Map();
  for (const [name, aliases] of Object.entries(areas ?? {})) for (const n of [name, ...aliases]) byName.set(n, name);
  const known = new Set(), unknown = [];
  for (const d of declared) (byName.has(d) ? known.add(byName.get(d)) : unknown.push(d));
  return { known: [...known], unknown };
}

const where = (cover) => [...new Set(Object.keys(cover).flatMap((k) => (k ? k.split("+") : [])))].join("+") || "no area";
export const boxText = (scene, b) => `${scene} ${b[0]},${b[1]} ${b[2]}x${b[3]} (${b[4]} px) in ${where(b[5])}`;

// The decision for one record. declared: the names on the Visual-change lines; accepted: a trusted VISUAL-ACCEPT at
// the head. Returns { state: "success"|"failure", why, outside: [box text] }.
export function judgeVisual(record, { declared = [], present = false, accepted = false } = {}) {
  if (!record?.ok) return { state: "failure", why: record?.why ?? "visual report unreadable", outside: [] };
  const { known, unknown } = resolveDeclared(declared, record.meta.areas);
  const allowed = new Set(known);
  const outside = [];
  let changed = 0;
  for (const scene of SCENES) for (const b of record.scenes.get(scene).boxes) {
    changed += b[4];
    if (Object.keys(b[5]).some((k) => !(k ? k.split("+") : []).some((a) => allowed.has(a)))) outside.push(boxText(scene, b));
  }
  const decl = present ? (known.length ? known.join(", ") : "none") : "no Visual-change line";
  const unk = unknown.length ? `; unknown area ${unknown.join(", ")} (known: ${Object.keys(record.meta.areas).join(", ")})` : "";
  if (!changed) return { state: "success", why: "visual: no pixel change", outside };
  if (!outside.length) return { state: "success", why: `visual: ${changed} px inside ${decl}${unk}`, outside };
  if (accepted) return { state: "success", why: `visual: VISUAL-ACCEPT at head (${outside.length} boxes outside ${decl})`, outside };
  return { state: "failure", why: `visual change outside declared areas (${decl}): ${outside.join("; ")}${unk}; declare Visual-change: <area> or VISUAL-ACCEPT @ head`, outside };
}

// The latest run of the visual workflow among runs (already scoped to the PR or the group), or null.
export function visualRun(runs, scope = () => true) {
  return (runs ?? []).filter((r) => String(r.path ?? "").split("@")[0] === VISUAL_WORKFLOW && scope(r)
    && !(r.status === "completed" && r.conclusion === "action_required")).sort((a, b) => b.id - a.id)[0] ?? null;
}

// The gate's visual state. visual: { run, job, annotations, expectedBase } as evaluate.mjs read it (job = the run's `visual`
// job). bind(meta, run) ties the report to the comparison the gate computes now (bindPr / bindGroup) and returns
// { state, problem } on a mismatch or the declaration to judge against: { declared, present, accepted }.
// null when nothing is required: no U11 cockpit run at all (the change touches no cockpit path), a run still going or
// not green (ciState already holds or fails it), a visual job skipped by queue-scope (a merge group whose tree is a PR
// head's tree), or a run without a visual job (a PR run made before D489 landed; its merge group's run has the job).
// A green visual job without a readable record fails; a record for another comparison is pending (PR) or fails (group).
export function visualState(visual, bind) {
  const run = visual?.run;
  if (!run || run.status !== "completed" || run.conclusion !== "success") return null;
  if (!visual.job || visual.job.conclusion === "skipped") return null;
  const fail = (why) => ({ state: "failure", why, outside: [] });
  if (visual.job.conclusion !== "success") return fail(`visual job ${visual.job.conclusion}`);
  const record = parseVisualRecord(visual.annotations);
  if (!record.ok) return fail(record.why);
  const b = bind(record.meta, run);
  if (!b) return fail("visual report not bound: no binding");
  if (b.problem) return { state: b.state, why: b.problem, outside: [] };
  const v = judgeVisual(record, b);
  return b.note ? { ...v, why: `${v.why}; ${b.note}`, note: b.note } : v;
}

const short = (sha) => String(sha ?? "none").slice(0, 8);
export const OTHER_BASE = "visual report is for another base — re-run U11";
// R11 ruling (#1320 round 3, amended): no ancestry proof, no search over earlier merges. A merge group's report counts
// only for its exact base and head; at PR level the head must match and a base difference is noted, not blocking.
const mismatch = (meta, base, head) => !base || meta.base !== base || meta.head !== head;   // bindGroup
const detail = (meta, base, head) => `(report base ${short(meta.base)} head ${short(meta.head)}; expected base ${short(base)} head ${short(head)})`;

// A PR: expectedBase is the first parent of the PR's current merge ref, read by the gate from GitHub (null when it
// cannot be read). A report for another head, or from another head's run, is PENDING until U11 re-runs. Amended ruling
// (no stuck PRs after every main move): a report for the PR head against another base is judged normally, and the
// status notes the base difference; the merge group then re-checks against its exact base (bindGroup).
export function bindPr(head, decl, expectedBase) {
  return (meta, run) => {
    if (run.head_sha !== head || meta.head !== head) return { state: "pending", problem: `${OTHER_BASE} ${detail(meta, expectedBase, head)}` };
    if (meta.base !== expectedBase) return { ...decl, note: `report base ${short(meta.base)} ≠ current base ${short(expectedBase)}; the merge queue re-checks against the exact base` };
    return decl;
  };
}

// The merge_group.base_sha of a queue run: GitHub names the queue branch gh-readonly-queue/main/pr-<n>-<base sha>.
const QUEUE_BRANCH = /^gh-readonly-queue\/main\/pr-[0-9]+-([0-9a-f]{40})$/;
export const queueBase = (run) => QUEUE_BRANCH.exec(String(run?.head_branch ?? ""))?.[1] ?? null;

// A merge group: the report's head is the group commit and its base is the run's merge_group.base_sha; otherwise
// FAILURE. The declarations and accepts of every PR in the group count (union).
export function bindGroup(groupSha, steps) {
  return (meta, run) => {
    const base = queueBase(run);
    if (!groupSha || run.head_sha !== groupSha || mismatch(meta, base, groupSha))
      return { state: "failure", problem: `visual report is for another comparison ${detail(meta, base, groupSha)}` };
    const vs = steps.map((s) => s.decl ?? { declared: [], present: false, accepted: false });
    return { declared: [...new Set(vs.flatMap((v) => v.declared))], present: vs.some((v) => v.present), accepted: vs.some((v) => v.accepted) };
  };
}
