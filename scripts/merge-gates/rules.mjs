// SPDX-License-Identifier: MIT
// Merge-queue gate rules: pure functions, no I/O. They compute the `modelplan-gates` state of one PR head
// from trusted PR comments, reviews, the changed-file list and the head's workflow runs, and the state of
// one merge-group commit from the per-PR states plus the group's own proofs. evaluate.mjs feeds them.
//
// The rules are a port of the coordinator's landing scripts (tier, trusted-author, verdict, carry, GLM,
// and design checks). Deliberate differences are marked "Stricter:"; none of them relaxes a gate. There is no
// stale-base check (owner 2026-11-07): a PR need not contain the latest main, because the queue's own CI on
// the group commit (QUEUE_WORKFLOWS) tests "PR + latest main".

export const CONTEXT = "modelplan-gates";
// Every lane posts through this account; anybody can comment on a public repo, so nothing else counts.
// The numeric id is checked too, so a renamed or recycled login never inherits the trust.
export const TRUSTED = Object.freeze({ login: "guanbear", id: 11829005 });
// Workflows that belong to the gate itself never count as CI for the head they judge.
export const SELF_WORKFLOWS = Object.freeze([".github/workflows/merge-gates.yml", ".github/workflows/merge-gates-probe.yml"]);
// A head counts as CI-checked only once this workflow has run; every other run of the same push is created
// with it, so its completion means the head's run list is complete.
export const ANCHOR_WORKFLOW = ".github/workflows/ci.yml";
// Workflows that must pass on the merge-group commit itself (they have a merge_group trigger). desktop.yml
// carries the Mac build and native-headless checks; its queue-scope job skips them for a group outside its paths.
export const QUEUE_WORKFLOWS = Object.freeze([".github/workflows/ci.yml", ".github/workflows/desktop.yml"]);
const SHA = /^[0-9a-f]{40}$/;

export const PENDING = "pending";
export const SUCCESS = "success";
export const FAILURE = "failure";

export function isTrusted(user) {
  return !!user && user.login === TRUSTED.login && user.id === TRUSTED.id;
}

// Comments and reviews as one time-ordered list of {kind, user, body, at}. A review without a
// submission time (a pending draft review) is not visible to anyone and never counts.
export function feed(comments = [], reviews = []) {
  const items = [
    ...comments.map((c, i) => ({ kind: "comment", user: c.user, body: c.body ?? "", at: c.created_at ?? "", i })),
    ...reviews.filter((r) => r.submitted_at).map((r, i) => ({ kind: "review", user: r.user, body: r.body ?? "", at: r.submitted_at, i: comments.length + i })),
  ];
  return items.filter((x) => isTrusted(x.user)).sort((a, b) => (a.at < b.at ? -1 : a.at > b.at ? 1 : a.i - b.i));
}

const lines = (body) => body.split("\n").map((l) => l.replace(/\r$/, ""));

// ---- Tier (tier.sh) ----
// 0 docs, assets, CI config only; 1 ordinary code and test-only PRs; 2 seams, credentials, privacy,
// signing, release. A trusted comment that starts with "REVIEW-TIER: N" overrides; the latest one wins.
const TEST_RE = /(^|\/)Tests\/|^desktop\/tests\/|(^|\/)tests?\/|_test\.go$|\.(test|spec)\.m?[jt]s$/;
const TIER2_RE = /^schema\/app-cli\/|^cli\/internal\/appserver\/wire\/|^cli\/internal\/swiftwire\/|^clients\/swift\/|keychain|consent|credential|secret|privacy|signing|codesign|notari[sz]|sparkle|\.github\/workflows\/[^/]*(release|packag|candidate|sign|notar|distribution)[^/]*$|desktop\/native\/tools\/[^/]*(identity|sign|seal|bundle)[^/]*$|^scripts\/release|^cli\/internal\/(quota|readers|connections)\/|^desktop\/native\/ModelPlan(EngineStore|EngineClient|CockpitWeb)\/|^desktop\/cockpit\/src\/bridge/i;
const TIER0_RE = /^docs\/|\.md$|^NOTICE|^LICEN|\.(png|jpe?g|svg|webp|woff2?|ttf|otf)$|^desktop\/official-visuals\/|^desktop\/third-party\/|^scripts\/check-[a-z-]+\.mjs$|^scripts\/tests\/(check-|[a-z-]+-pack\.test\.mjs$)|^\.github\/|^source-policy\.json$/;
// Stricter: the gate's own rules and workflows are tier 2, so a PR cannot loosen the gate that judges it
// with less review than a seam change gets.
const GATE_SELF_RE = /^scripts\/merge-gates\/|^\.github\/workflows\/merge-gates[^/]*$/;

export function tierOverride(items) {
  let t = null;
  for (const x of items) if (x.kind === "comment") {
    const m = /^REVIEW-TIER: ([012])/.exec(x.body);
    if (m) t = Number(m[1]);
  }
  return t;
}

// paths: every path the PR touches (Stricter: renamed files contribute their old path too).
export function pathTier(paths) {
  if (paths.length && paths.every((p) => TEST_RE.test(p))) return 1;
  if (paths.some((p) => GATE_SELF_RE.test(p) || TIER2_RE.test(p))) return 2;
  if (!paths.length || paths.some((p) => !TIER0_RE.test(p))) return 1;
  return 0;
}

export function prPaths(files) {
  const out = [];
  for (const f of files) {
    out.push(f.filename);
    if (f.previous_filename && f.previous_filename !== f.filename) out.push(f.previous_filename);
  }
  return [...new Set(out)];
}

// ---- Design-touching (design-touch.sh + design-paths.conf) ----
const bashEre = (re) => new RegExp(re.replaceAll("[[:space:]]", "\\s"));

export function parseDesignConf(text) {
  const conf = { include: [], exclude: [], pinonly: [] };
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const [kind, a, b, ...rest] = line.split(/\s+/);
    if (kind === "include") conf.include.push({ surface: a, re: bashEre(b), prefixes: rest });
    else if (kind === "exclude") conf.exclude.push(bashEre(b));
    else if (kind === "pinonly") conf.pinonly.push({ re: bashEre(a), line: bashEre(b) });
    else throw new Error(`design-paths.conf: unknown rule '${kind}'`);
  }
  return conf;
}

// The changed lines of one file's API patch; null when GitHub sent no patch (binary or too large).
function changedLines(patch) {
  if (typeof patch !== "string") return null;
  const out = [];
  for (const l of patch.split("\n")) if ((l.startsWith("+") || l.startsWith("-")) && !l.startsWith("+++ ") && !l.startsWith("--- ")) out.push(l.slice(1));
  return out;
}

// GitHub lists at most 3000 files for a PR; a list that long may be cut, so it counts as design-touching.
export const FILE_LIST_LIMIT = 3000;

export function designTouch(files, conf) {
  if (files.length >= FILE_LIST_LIMIT) return { touching: true, surfaces: ["file-list-truncated"] };
  const surfaces = new Set();
  const consider = (path, patch) => {
    if (conf.exclude.some((re) => re.test(path))) return;
    for (const p of conf.pinonly) if (p.re.test(path)) {
      const ch = changedLines(patch);
      if (ch && ch.length && ch.every((l) => p.line.test(l))) return;
    }
    const inc = conf.include.find((r) => r.re.test(path));
    if (inc) surfaces.add(inc.surface);
  };
  for (const f of files) {
    consider(f.filename, f.patch);
    // Stricter: moving a file out of a design path is a design change too.
    if (f.previous_filename && f.previous_filename !== f.filename) consider(f.previous_filename, null);
  }
  return { touching: surfaces.size > 0, surfaces: [...surfaces] };
}

// ---- Carry (VERDICT-CARRY lines, review-land.sh) ----
// Edges come from trusted comments only, in posting order. From the head, follow the first edge whose new
// side is the current sha, at most 6 hops. Stricter: an edge counts only if `verified(old, new)` says the
// gate re-proved it from Git objects (evaluate.mjs: first parent is the reviewed head, second parent is on
// main, and the PR's own contribution is object-identical).
export function carryEdges(items) {
  const edges = [];
  for (const x of items) if (x.kind === "comment")
    for (const l of lines(x.body)) {
      const m = /^VERDICT-CARRY: ([0-9a-f]{40}) -> ([0-9a-f]{40})\b/.exec(l);
      if (m) edges.push({ old: m[1], new: m[2] });
    }
  return edges;
}

export function carryChain(edges, head, verified = () => false) {
  const chain = [];
  let f = head;
  for (let hop = 0; hop < 6; hop++) {
    const e = edges.find((x) => x.new === f);
    if (!e || !verified(e.old, e.new)) break;
    chain.push(e.old);
    f = e.old;
  }
  return chain;
}

// ---- Verdicts ----
// "VERDICT: merge|block @ <40 hex> (<lane>)" on its own line, case-insensitive, in trusted comments and
// reviews. Counts for the head or a carried head; per lane the latest wins.
export function verdicts(items, head, carried) {
  const at = new Set([head, ...carried]);
  const lanes = new Map();
  for (const x of items)
    for (const l of lines(x.body)) {
      const m = /^VERDICT: (merge|block) @ ([0-9a-f]{40})\b(?: \(([a-z0-9]+)\))?/i.exec(l);
      if (!m) continue;
      const sha = m[2].toLowerCase();
      if (at.has(sha)) lanes.set(m[3] ? `(${m[3].toLowerCase()})` : "(unnamed)", m[1].toLowerCase());
    }
  return lanes;
}

// "DESIGN: pass|fail @ <40 hex>" counts only in a trusted comment or review whose body starts with
// "Design-conformance review"; latest wins; carries over the same verified edges as verdicts.
export function designVerdict(items, head, carried) {
  const at = new Set([head, ...carried]);
  let r = null;
  for (const x of items) {
    if (!x.body.startsWith("Design-conformance review")) continue;
    for (const l of lines(x.body)) {
      const m = /^DESIGN: (pass|fail) @ ([0-9a-f]{40})\b/.exec(l);
      if (m && at.has(m[2])) r = m[1];
    }
  }
  return r;
}

// GLM cross-review (merge-when.sh): a trusted comment that starts with "GLMREV: OK|ISSUES @ <head>" or
// "GLMREV-ACCEPTED @ <head>" for the exact head (never carried); the latest one decides.
const GLM_SCOPE_RE = /^(desktop\/native\/|cli\/|clients\/swift\/|schema\/app-cli\/)/;
export const glmInScope = (paths) => paths.some((p) => GLM_SCOPE_RE.test(p));

export function glmVerdict(items, head) {
  let r = null;
  const re = new RegExp(`^(GLMREV: (OK|ISSUES)|GLMREV-ACCEPTED) @ ${head}(\\s|$)`);
  for (const x of items) if (x.kind === "comment") {
    const m = re.exec(x.body);
    if (m) r = m[2] === "ISSUES" ? "issues" : "ok";
  }
  return r;
}

// ---- Exact-head scenario evidence (evidence-gate.sh) ----
const SCENARIO_LINE = /^\s*\**Scenarios:?\**:?/i;
const SCENARIO_ID = /^[A-Z][A-Z0-9]{0,3}-[0-9]{2}$/;

// The first matching body line is the declaration. It is either "none" (a bracketed note may follow) or spec
// scenario IDs separated by commas, semicolons or "and", each with an optional bracketed note. Anything else
// (requirement IDs, free text, an empty line) is malformed: read as "no scenarios" it would switch the evidence
// gate off, so every PR is held to this, not only ledger PRs.
export function parseScenarios(body) {
  const line = lines(body ?? "").find((l) => SCENARIO_LINE.test(l));
  if (line === undefined) return { declared: false, ids: [], malformed: null };
  const rest = line.replace(SCENARIO_LINE, "").replace(/\*+\s*$/, "").trim();
  if (/^none\s*(\(.*\))?$/i.test(rest)) return { declared: true, ids: [], malformed: null };
  let bare = rest;
  for (let prev = null; prev !== bare;) { prev = bare; bare = bare.replace(/\([^()]*\)/g, " "); }
  const tokens = bare.split(/[,;\s]+/).filter((t) => t && t !== "and");
  // A note stays free text, but cannot hide a mistyped ID.
  const shaped = rest.match(/\b[A-Za-z][A-Za-z0-9-]*[0-9][A-Za-z0-9-]*\b/g) ?? [];
  const bad = [...tokens, ...shaped].filter((t) => !SCENARIO_ID.test(t));
  if (bad.length || !tokens.length)
    return { declared: true, ids: [], malformed: `Scenarios line must be spec scenario IDs or none${bad.length ? `, not: ${bad.slice(0, 3).join(" ")}` : ""}` };
  return { declared: true, ids: [...new Set(rest.match(/\b[A-Z][A-Z0-9]{0,3}-[0-9]{2}\b/g))].sort(), malformed: null };
}

// Lowest sufficient evidence per scenario (verification plan v2). Read from the default branch, never from a PR.
export const TIER_TABLE = "desktop/native/verification/scenario-tiers.tsv";
const CI_TIER = /^(T0|T1|T1P|T2|T2a|T2b)$/;

export function parseTiers(text) {
  const tiers = new Map();
  for (const l of lines(text)) {
    const [id, tier] = l.split("\t");
    if (SCENARIO_ID.test(id) && /^T[0-9][A-Za-z0-9]*$/.test(tier ?? "")) tiers.set(id, tier);
  }
  return tiers;
}

// A table that cannot be read comes back empty, so every scenario then needs evidence.
export function tiersFrom(read) {
  try { return parseTiers(read()); } catch { return new Map(); }
}

// Only trusted issue comments count. Evidence is tied to the actual head and is never carried across a merge
// or other commit. As in evidence-gate.sh (D21): a PR naming a ledger row needs a line for every scenario; any other
// PR needs one for each scenario that is not on a CI tier, so real-Mac tiers, G3 rows and IDs missing from `tiers`
// all do. A CI-tier scenario needs no line because evaluatePr requires green CI at the head anyway. #661 landed with
// C-10 (T3) unaccounted for when only ledger PRs were read here.
export function evidenceState(pr, items, head, tiers = new Map()) {
  const body = pr.body ?? "";
  const ledger = /g3-[0-9]+/i.test([pr.title ?? "", body, pr.head.ref ?? ""].join("\n"));
  const { ids: scenarios, malformed } = parseScenarios(body);
  if (malformed) return { state: FAILURE, why: malformed };
  if (!scenarios.length) return ledger ? { state: FAILURE, why: "ledger PR requires a Scenarios line with scenario IDs" }
    : { state: SUCCESS, why: "not an evidence-tier-1 PR" };
  const verified = new Set();
  for (const item of items) if (item.kind === "comment") {
    for (const line of lines(item.body)) {
      const match = /^VERIFIED: ([A-Z][A-Z0-9]{0,3}-[0-9]{2}) @ ([0-9a-f]{40}) evidence=[^ ]+/.exec(line);
      if (match && match[2] === head) verified.add(match[1]);
      // Owner 2026-11-07: device evidence runs once after v1 development. An exact-head deferral lets the PR land;
      // #470 stays open until every deferred scenario has real evidence, so this is never a VERIFIED line.
      const deferred = /^EVIDENCE-DEFERRED: ([A-Z][A-Z0-9]{0,3}-[0-9]{2}) @ ([0-9a-f]{40}) issue=470$/.exec(line);
      if (deferred && deferred[2] === head) verified.add(deferred[1]);
    }
  }
  const onCi = (id) => !ledger && CI_TIER.test(tiers.get(id) ?? "");
  const missing = scenarios.filter((id) => !verified.has(id) && !onCi(id));
  return missing.length ? { state: PENDING, why: `evidence pending: ${missing.join(", ")}` }
    : { state: SUCCESS, why: "scenario evidence verified" };
}

// ---- Trains ----
// A train lands many PRs under one Scenarios line, and only that line is checked for evidence, so a member's
// scenario missing from it would land unaccounted for (#650 dropped seven). evaluate.mjs reads members only for
// a PR that looks like a train: "train" in the title, a b/ branch, or a Supersedes section.
export const isTrain = (pr) => /\btrain\b/i.test(pr.title ?? "") || (pr.head.ref ?? "").startsWith("b/") || /^#{2,3}\s*Supersedes\b/im.test(pr.body ?? "");

// The PR numbers in the body's Supersedes section.
export function supersededPrs(body) {
  const section = /^#{2,3}\s*Supersedes\b.*\n((?:(?!#{1,3}\s).*(?:\n|$))*)/im.exec(body ?? "");
  return [...new Set([...(section?.[1] ?? "").matchAll(/#([0-9]+)/g)].map((m) => Number(m[1])))].sort((a, b) => a - b);
}

// based: PRs into the train's branch; open: open PRs into main; superseded: the PRs named in Supersedes;
// commits: the train head's commits that main lacks. A PR merged through GitHub or carried at its exact head is
// a member; a PR the train says it supersedes is one by declaration, unless it already landed on main under its
// own gate.
export function trainMembers(pr, { based, open, superseded, commits }) {
  const members = new Map();
  for (const p of [...based, ...open]) if (p.merged_at || commits.has(p.head.sha)) members.set(p.number, p);
  for (const p of superseded) if (!(p.merged_at && p.base?.ref === "main")) members.set(p.number, p);
  return [...members.values()].filter((p) => p.head.sha !== pr.head.sha).sort((a, b) => a.number - b.number);
}

// members: [{number, body}].
export function trainScenarioGap(pr, members) {
  const own = new Set(parseScenarios(pr.body).ids);
  const gaps = [];
  for (const m of members) {
    const { ids, malformed } = parseScenarios(m.body);
    if (malformed) gaps.push(`#${m.number}: unreadable Scenarios line`);
    const lost = ids.filter((id) => !own.has(id));
    if (lost.length) gaps.push(`#${m.number}: ${lost.join(" ")}`);
  }
  return gaps.length ? `train Scenarios line misses ${gaps.join("; ")}` : null;
}

// ---- CI at one commit (merge-when.sh) ----
// runs: Actions workflow runs whose head_sha is the commit. Only the newest run per workflow counts, so a
// superseded or re-triggered run never blocks. A run GitHub rejected at parse time (startup_failure) has no
// jobs and is caught here too. statuses: commit statuses at the commit other than our own context.
const OK_CONCLUSIONS = new Set(["success", "skipped", "neutral"]);
export function latestRuns(runs) {
  const by = new Map();
  for (const r of runs) {
    if (SELF_WORKFLOWS.includes(r.path)) continue;
    const prev = by.get(r.workflow_id);
    if (!prev || r.id > prev.id) by.set(r.workflow_id, r);
  }
  return [...by.values()];
}

export function ciState(runs, statuses = [], { required = [ANCHOR_WORKFLOW] } = {}) {
  const latest = latestRuns(runs);
  const failed = [], waiting = [];
  for (const r of latest) {
    if (r.status !== "completed") waiting.push(r.name);
    else if (!OK_CONCLUSIONS.has(r.conclusion)) failed.push(`${r.name} ${r.conclusion}`);
  }
  for (const s of statuses) {
    if (s.context === CONTEXT) continue;
    if (s.state === "pending") waiting.push(s.context);
    else if (s.state !== "success") failed.push(`${s.context} ${s.state}`);
  }
  if (failed.length) return { state: FAILURE, why: `failed: ${failed.join(", ")}` };
  const missing = required.filter((p) => !latest.some((r) => r.path === p));
  if (missing.length) return { state: PENDING, why: `waiting for ${missing.join(", ")} to start` };
  if (waiting.length) return { state: PENDING, why: `running: ${waiting.join(", ")}` };
  return { state: SUCCESS, why: "checks green" };
}

// ---- One PR head ----
// pr: REST pull request; items: feed(); files: REST PR files; runs/statuses: CI at the head;
// verifiedEdge(old, new): carry proof; conf: parsed design-paths.conf; members: a train's member PRs;
// tiers: parseTiers().
export function evaluatePr({ pr, items, files, runs, statuses, verifiedEdge, conf, members = [], tiers = new Map() }) {
  const head = pr.head.sha;
  const res = (state, why, extra = {}) => ({ state, why, head, ...extra });
  if (!SHA.test(head)) return res(FAILURE, "head is not a full sha");
  if (pr.state !== "open") return res(FAILURE, `PR is ${pr.state}`);
  if (pr.base.ref !== "main") return res(FAILURE, `base is ${pr.base.ref}, not main; coordinator decides`);
  // Only the trusted account's own same-repository PRs land; a stranger's or a fork PR waits for the coordinator.
  if (!isTrusted(pr.user) || pr.head.repo?.full_name !== pr.base.repo.full_name)
    return res(FAILURE, "not a trusted same-repository PR; coordinator decides");
  const evidence = evidenceState(pr, items, head, tiers);
  if (evidence.state === FAILURE) return res(FAILURE, evidence.why);
  const gap = trainScenarioGap(pr, members);
  if (gap) return res(FAILURE, gap);
  if (pr.draft) return res(PENDING, "draft");

  const paths = prPaths(files);
  const override = tierOverride(items);
  const tier = override ?? pathTier(paths);
  const design = designTouch(files, conf);
  const carried = carryChain(carryEdges(items), head, verifiedEdge);
  const extra = { tier, design: design.touching ? design.surfaces : [], carried };

  let lanes = verdicts(items, head, carried);
  // Owner 2026-11-04 tier split: on tier 2 a macrev (Terra) verdict is advice, not a gate.
  if (tier === 2) lanes = new Map([...lanes].filter(([l]) => l !== "(macrev)"));
  // Stricter: a trusted block stops every tier, tier 0 included.
  const blocked = [...lanes].filter(([, v]) => v === "block").map(([l]) => l);
  if (blocked.length) return res(FAILURE, `VERDICT block ${blocked.join(" ")}`, extra);

  const missing = [];
  if (evidence.state === PENDING) missing.push(evidence.why);
  // Owner 2026-11-07: while Codex quota is out, a Sonnet reviewer stands in for macrev2 under its own label.
  if (tier === 2 && lanes.get("(macrev2)") !== "merge" && lanes.get("(sonnet)") !== "merge") missing.push("VERDICT (macrev2) or (sonnet) merge");
  if (tier === 1 && ![...lanes.values()].includes("merge")) missing.push("a VERDICT merge");
  if (design.touching) {
    const d = designVerdict(items, head, carried);
    if (d === "fail") return res(FAILURE, `DESIGN fail (${design.surfaces.join(",")})`, extra);
    if (d !== "pass") missing.push("DESIGN pass");
  }
  if (tier !== 0 && glmInScope(paths)) {
    const g = glmVerdict(items, head);
    if (g === "issues") return res(FAILURE, "GLMREV ISSUES at head", extra);
    if (g !== "ok") missing.push("GLMREV OK or ACCEPTED");
  }
  const ci = ciState(runs, statuses);
  if (ci.state === FAILURE) return res(FAILURE, ci.why, extra);
  if (missing.length) return res(PENDING, `tier ${tier}: needs ${missing.join(", ")}`, extra);
  if (ci.state === PENDING) return res(PENDING, ci.why, extra);
  return res(SUCCESS, `tier ${tier}: gates pass${carried.length ? ` (carried ${carried.length})` : ""}`, extra);
}

// ---- One merge-group commit ----
// steps: one per PR in the group, base first: {pr, prResult, mergeProof: {ok, why}}.
// queueRuns/queueStatuses: CI on the group commit itself.
export function evaluateGroup({ steps, queueRuns, queueStatuses = [] }) {
  if (!steps.length) return { state: FAILURE, why: "no PR found in the merge group" };
  for (const s of steps) {
    const n = `#${s.pr}`;
    if (!s.mergeProof.ok) return { state: FAILURE, why: `${n}: ${s.mergeProof.why}` };
    if (s.prResult.state !== SUCCESS) return { state: s.prResult.state === PENDING ? FAILURE : s.prResult.state, why: `${n}: ${s.prResult.why}` };
  }
  const ci = ciState(queueRuns, queueStatuses, { required: QUEUE_WORKFLOWS });
  if (ci.state !== SUCCESS) return { state: ci.state, why: `group ${ci.why}` };
  return { state: SUCCESS, why: `group of ${steps.length}: gates pass` };
}

export function description(text) {
  return text.length <= 140 ? text : text.slice(0, 139) + "…";
}
