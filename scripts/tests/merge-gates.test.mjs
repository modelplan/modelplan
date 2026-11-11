// SPDX-License-Identifier: MIT
import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import * as R from "../merge-gates/rules.mjs";
import * as G from "../merge-gates/git.mjs";
import { workflowProblems } from "../workflow-policy.mjs";

const root = new URL("../..", import.meta.url).pathname;
const conf = R.parseDesignConf(readFileSync(join(root, "scripts/merge-gates/design-paths.conf"), "utf8"));
const H = "a".repeat(40), OLD = "b".repeat(40), OLDER = "c".repeat(40);
const ME = { login: "guanbear", id: 11829005 };
let clock = 0;
const at = () => new Date(Date.UTC(2026, 10, 4, 0, 0, clock++)).toISOString();
const comment = (body, user = ME) => ({ user, body, created_at: at() });
const review = (body, user = ME) => ({ user, body, submitted_at: at() });
const file = (filename, extra = {}) => ({ filename, ...extra });
// A run of PR #7 made in this repository; `qrun` is one of the merge queue's runs on a group commit.
const run = (path, conclusion = "success", id = 1, status = "completed", over = {}) => ({ id, workflow_id: path, path, name: path.split("/").pop(), status, conclusion,
  head_sha: H, head_repository: { full_name: "modelplan/modelplan" }, head_branch: "feature/x", event: "pull_request", pull_requests: [{ number: 7 }], ...over });
const qrun = (path, conclusion = "success", id = 1, status = "completed", over = {}) =>
  run(path, conclusion, id, status, { head_branch: `gh-readonly-queue/main/pr-7-${OLD}`, event: "merge_group", pull_requests: [], ...over });
const greenCi = [run(".github/workflows/ci.yml")];
const greenQueue = R.QUEUE_WORKFLOWS.map((path) => qrun(path));
const pr = (over = {}) => ({
  number: 7, state: "open", draft: false, user: ME,
  head: { sha: H, ref: "feature/x", repo: { full_name: "modelplan/modelplan" } },
  base: { ref: "main", repo: { full_name: "modelplan/modelplan" } },
  ...over,
});
const evalPr = ({ comments = [], reviews = [], files = [file("scripts/tool.mjs")], runs = greenCi, statuses = [], verified = () => false, p = pr() } = {}) =>
  R.evaluatePr({ pr: p, items: R.feed(comments, reviews), files, runs, statuses, verifiedEdge: verified, conf });
const v = (verdict, sha = H, lane = "macrev") => `Review\n\nVERDICT: ${verdict} @ ${sha}${lane ? ` (${lane})` : ""}`;

test("trust needs the login and the numeric id; deleted authors and drafts never count", () => {
  assert.ok(R.isTrusted(ME));
  assert.ok(!R.isTrusted({ login: "guanbear", id: 1 }));
  assert.ok(!R.isTrusted({ login: "someone", id: 11829005 }));
  assert.ok(!R.isTrusted(null));
  const items = R.feed([comment("x", null), comment("y", { login: "x", id: 2 }), comment("z")], [{ user: ME, body: "draft" }]);
  assert.deepEqual(items.map((x) => x.body), ["z"]);
});

test("tier: path rules, test-only rule, override and gate self-protection", () => {
  assert.equal(R.pathTier(["docs/a.md", ".github/workflows/ci.yml", "x.png"]), 0);
  assert.equal(R.pathTier(["cli/main.go"]), 1);
  assert.equal(R.pathTier(["desktop/native/ModelPlanDock/KeychainStore.swift"]), 2, "tier-2 words are case-insensitive");
  assert.equal(R.pathTier(["cli/internal/consent/consent_test.go", "desktop/tests/a.test.mjs"]), 1, "test-only stays tier 1");
  assert.equal(R.pathTier(["cli/internal/consent/consent_test.go", "cli/internal/consent/consent.go"]), 2);
  assert.equal(R.pathTier([]), 1);
  assert.equal(R.pathTier([".github/workflows/merge-gates.yml"]), 2);
  assert.equal(R.pathTier(["scripts/merge-gates/rules.mjs"]), 2);
  assert.equal(R.pathTier([R.TIER_TABLE]), 2, "the tier table decides which scenarios need evidence");
  assert.equal(R.pathTier(["docs/a.md", R.TIER_TABLE]), 2);
  assert.equal(R.pathTier([".github/workflows/release.yml"]), 2);
  assert.deepEqual(R.prPaths([file("docs/new.md", { previous_filename: "cli/old.go" })]), ["docs/new.md", "cli/old.go"]);
  const items = R.feed([comment("REVIEW-TIER: 2"), comment("note\nREVIEW-TIER: 0"), comment("REVIEW-TIER: 0", { login: "x", id: 3 })], [review("REVIEW-TIER: 1")]);
  assert.equal(R.tierOverride(items), 2, "override must start the comment; reviews and strangers do not count");
  assert.equal(R.tierOverride(R.feed([comment("REVIEW-TIER: 2"), comment("REVIEW-TIER: 0")])), 0, "latest wins");
});

test("verdicts: exact full head, case-insensitive, latest per lane, trusted only", () => {
  const items = R.feed([
    comment(v("merge", H, "macrev")),
    comment(v("BLOCK", H, "GLM")),
    comment(v("merge", H, "glm")),
    comment(v("block", H.slice(0, 39) + "f", "macrev2")),
    comment(`VERDICT: block @ ${H}0 (macrev2)`),
    comment(v("block", H, "macrev2"), { login: "spam", id: 9 }),
    comment(`prose VERDICT: block @ ${H} (x)`),
  ]);
  assert.deepEqual([...R.verdicts(items, H, [])], [["(macrev)", "merge"], ["(glm)", "merge"]]);
  assert.deepEqual([...R.verdicts(R.feed([comment(v("merge", H.toUpperCase(), ""))]), H, [])], [["(unnamed)", "merge"]]);
});

test("tier gates: tier 1 any merge, tier 2 needs macrev2, macrev is advice on tier 2, blocks stop every tier", () => {
  assert.equal(evalPr({ comments: [comment(v("merge"))] }).state, R.SUCCESS);
  assert.equal(evalPr().state, R.PENDING);
  const t2 = [file("clients/swift/Wire.swift")];
  const glm = comment(`GLMREV: OK @ ${H}`);
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrev")), glm] }).state, R.PENDING);
  assert.equal(evalPr({ files: t2, comments: [comment(v("block", H, "macrev")), comment(v("merge", H, "macrev2")), glm] }).state, R.SUCCESS);
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrev2")), comment(v("block", H, "glm")), glm] }).state, R.FAILURE);
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "sonnet")), glm] }).state, R.SUCCESS, "Sonnet stands in for macrev2");
  assert.equal(evalPr({ files: t2, comments: [comment(v("block", H, "sonnet")), comment(v("merge", H, "macrev2")), glm] }).state, R.FAILURE);
  assert.equal(evalPr({ files: [file("docs/a.md")] }).state, R.SUCCESS, "tier 0 needs no verdict");
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment(v("block"))] }).state, R.FAILURE);
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment("REVIEW-TIER: 1")] }).state, R.PENDING);
});

test("evidence: an exact-head trusted deferral to #470 clears a scenario, nothing looser does", () => {
  const ledger = pr({ title: "G3-20 fix", body: "Scenarios: D-01" });
  const later = `EVIDENCE-DEFERRED: D-01 @ ${H} issue=470`;
  assert.equal(R.evidenceState(ledger, R.feed([comment(later)]), H).state, R.SUCCESS);
  assert.equal(R.evidenceState(ledger, R.feed([comment(`EVIDENCE-DEFERRED: D-01 @ ${OLD} issue=470`)]), H).state, R.PENDING);
  assert.equal(R.evidenceState(ledger, R.feed([comment(`EVIDENCE-DEFERRED: D-01 @ ${H} issue=1`)]), H).state, R.PENDING);
  assert.equal(R.evidenceState(ledger, R.feed([comment(later, { login: "spam", id: 9 })]), H).state, R.PENDING);
  assert.equal(R.evidenceState(ledger, R.feed([comment(`EVIDENCE-DEFERRED: D-02 @ ${H} issue=470`)]), H).state, R.PENDING);
});

test("D97 AUTO-VERIFIED: trusted first line at the exact head clears the listed scenarios, ledger and G3 rows included", () => {
  const docs = [file("docs/evidence.md")];
  const ledger = (body) => pr({ title: "Fix G3-07", body: `Ledger: G3-07\n${body}` });
  const av = (ids, sha = H, gates = "ci,gui,review") => `AUTO-VERIFIED: ${ids} @ ${sha} gates=${gates}`;
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, comments: [comment(`${av("V-01, V-02")}\n\nchecked`)] }).state, R.SUCCESS);
  assert.equal(evalPr({ p: ledger("Scenarios: G3-07, V-01, V-02"), files: docs, comments: [comment(av("G3-07 V-01 V-02"))] }).state, R.SUCCESS, "G3 row and space-separated IDs");
  for (const gates of R.AUTO_VERIFIED_GATES)
    assert.equal(evalPr({ p: ledger("Scenarios: V-01"), files: docs, comments: [comment(av("V-01", H, gates))] }).state, R.SUCCESS, gates);
  // Mixed with a coordinator VERIFIED line and a #470 deferral.
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02, V-03"), files: docs, comments: [comment(av("V-01")), comment(`VERIFIED: V-02 @ ${H} evidence=/x/y`), comment(`EVIDENCE-DEFERRED: V-03 @ ${H} issue=470`)] }).state, R.SUCCESS);
  // A Scenarios line without a ledger row (real-Mac tier) is cleared the same way.
  assert.equal(evalPr({ p: pr({ title: "Ordinary", body: "Scenarios: C-10" }), files: docs, comments: [comment(av("C-10"))] }).state, R.SUCCESS);

  const pending = (comments, why, p = ledger("Scenarios: V-01, V-02")) => {
    const r = evalPr({ p, files: docs, comments });
    assert.equal(r.state, R.PENDING, why);
    return r;
  };
  pending([comment(av("V-01, V-02", OLD))], "old head");
  assert.match(pending([comment(av("V-01, V-02"))], "a new head invalidates it", pr({ title: "Fix G3-07", body: "Scenarios: V-01, V-02", head: { sha: OLD, ref: "feature/x", repo: { full_name: "modelplan/modelplan" } } })).why, /V-01, V-02/);
  pending([comment(av("V-01, V-02"), { login: "mallory", id: 1 })], "untrusted login");
  pending([comment(av("V-01, V-02"), { login: "guanbear", id: 1 })], "recycled login");
  pending([comment(`notes first\n${av("V-01, V-02")}`)], "not the first line");
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, reviews: [review(av("V-01, V-02"))] }).state, R.PENDING, "a review is not a comment");
  pending([comment(` ${av("V-01, V-02")}`)], "leading space");
  for (const gates of ["ci,review", "gui,review", "ci,gui", "review,gui,ci", "ci,gui,review,visual,design", "ci,gui,review,", "ci,gui,review,extra", "ci,gui,review,walkthrough", ""])
    pending([comment(av("V-01, V-02", H, gates))], `gates=${gates}`);
  pending([comment(av("V-01, V-02", H.slice(0, 12), "ci,gui,review,design,visual"))], "short sha");
  pending([comment(av("V-01, V-02", H.toUpperCase()))], "upper-case sha");
  pending([comment(`${av("V-01, V-02")} trailing`)], "trailing text");
  pending([comment(av("V-01, v-02"))], "malformed ID");
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, comments: [comment(av("V-01, V-02", OLD)), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true }).state, R.PENDING, "never carried");
  assert.match(pending([comment(av("V-01"))], "only the listed ID").why, /evidence pending: V-02$/);

  // Design-touching PR: the line must name design (evidence-gate.sh NEED_D).
  const designFiles = [file("desktop/cockpit/src/field-page.ts")];
  assert.equal(R.designTouch(designFiles, conf).touching, true);
  const designEv = (gates) => R.evidenceState(ledger("Scenarios: V-01"), R.feed([comment(av("V-01", H, gates))]), H, new Map(), { designTouching: true }).state;
  assert.equal(designEv("ci,gui,review"), R.PENDING);
  assert.equal(designEv("ci,gui,review,visual"), R.PENDING);
  assert.equal(designEv("ci,gui,review,design"), R.SUCCESS);
  assert.equal(designEv("ci,gui,review,design,visual"), R.SUCCESS);
  assert.match(evalPr({ p: ledger("Scenarios: V-01"), files: designFiles, comments: [comment(av("V-01"))] }).why, /evidence pending: V-01/);
  assert.doesNotMatch(evalPr({ p: ledger("Scenarios: V-01"), files: designFiles, comments: [comment(av("V-01", H, "ci,gui,review,design"))] }).why, /evidence pending/);
});

test("PR admission: trusted same-repo PRs into main only; drafts wait", () => {
  assert.equal(evalPr({ p: pr({ user: { login: "x", id: 1 } }) }).state, R.FAILURE);
  assert.equal(evalPr({ p: pr({ head: { sha: H, repo: { full_name: "fork/modelplan" } } }) }).state, R.FAILURE);
  assert.equal(evalPr({ p: pr({ base: { ref: "next", repo: { full_name: "modelplan/modelplan" } } }) }).state, R.FAILURE);
  assert.equal(evalPr({ p: pr({ draft: true }), comments: [comment(v("merge"))] }).state, R.PENDING);
});

test("carry: verified edges only, followed back from the head, at most 6 hops", () => {
  const edges = R.carryEdges(R.feed([comment(`VERDICT-CARRY: ${OLD} -> ${H}`), comment(`VERDICT-CARRY: ${OLDER} -> ${OLD}`)]));
  assert.deepEqual(R.carryChain(edges, H, () => true), [OLD, OLDER]);
  assert.deepEqual(R.carryChain(edges, H, (o) => o !== OLDER), [OLD]);
  assert.deepEqual(R.carryChain(edges, H), []);
  const shas = Array.from({ length: 9 }, (_, i) => String(i).repeat(40));
  const long = shas.slice(1).map((s, i) => ({ old: s, new: shas[i] }));
  assert.equal(R.carryChain(long, shas[0], () => true).length, 6);
  const carried = { comments: [comment(v("merge", OLD)), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)] };
  assert.equal(evalPr({ ...carried, verified: () => true }).state, R.SUCCESS);
  assert.equal(evalPr(carried).state, R.PENDING, "an unproven carry line does not carry");
  assert.equal(R.carryEdges(R.feed([], [review(`VERDICT-CARRY: ${OLD} -> ${H}`)])).length, 0, "edges come from comments only");
});

test("design gate: paths, pin-only bundle updates, DESIGN lines only in design-conformance reviews", () => {
  assert.equal(R.designTouch([file("desktop/native/ModelPlanDock/Sources/View.swift")], conf).touching, true);
  assert.equal(R.designTouch([file("desktop/native/ModelPlanDock/Tests/ViewTests.swift")], conf).touching, false);
  assert.equal(R.designTouch([file("docs/x.md"), file("desktop/cockpit/src/ui.md")], conf).touching, false);
  assert.equal(R.designTouch([file("app/en.lproj/Localizable.strings")], conf).touching, true);
  const factory = "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift";
  const pin = `@@ -1,2 +1,2 @@\n-    static let webSource = "${OLD}"\n+    static let webSource = "${H}"\n context`;
  assert.equal(R.designTouch([file(factory, { patch: pin })], conf).touching, false);
  assert.equal(R.designTouch([file(factory, { patch: pin + "\n+let other = 1" })], conf).touching, true);
  assert.equal(R.designTouch([file(factory)], conf).touching, true, "no patch from GitHub: not provably pin-only");
  assert.equal(R.designTouch([file("docs/a.md", { previous_filename: "desktop/native/ModelPlanSettings/A.swift" })], conf).touching, true);
  assert.equal(R.designTouch(Array.from({ length: R.FILE_LIST_LIMIT }, (_, i) => file(`docs/${i}.md`)), conf).touching, true);

  const files = [file("desktop/native/ModelPlanSettings/Pane.swift")];
  const merge = comment(v("merge")), glm = comment(`GLMREV: OK @ ${H}`);
  assert.equal(evalPr({ files, comments: [merge, glm] }).state, R.PENDING);
  assert.equal(evalPr({ files, comments: [merge, glm, comment(`Tier review\nDESIGN: pass @ ${H}`)] }).state, R.PENDING, "stray DESIGN line");
  assert.equal(evalPr({ files, comments: [merge, glm], reviews: [review(`Design-conformance review (GLM)\nDESIGN: pass @ ${H}`)] }).state, R.SUCCESS);
  assert.equal(evalPr({ files, comments: [merge, glm, comment(`Design-conformance review\nDESIGN: pass @ ${H}`), comment(`Design-conformance review\nDESIGN: fail @ ${H}`)] }).state, R.FAILURE);
  assert.equal(evalPr({ files: [file("desktop/official-visuals/dock/a.svg")], comments: [] }).state, R.PENDING, "tier 0 design-touching still needs DESIGN");
});

test("design gate: only the pinned CLI identity file is excluded by name; other generated-looking files are reviewed", () => {
  const identity = "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityConsentCLIIdentity.generated.swift";
  assert.equal(R.designTouch([file(identity)], conf).touching, false);
  for (const other of [identity.replace("CommunityConsentCLIIdentity", "DockFace"), identity.replace(".generated.swift", ".swift"), `${identity}.swift`, identity.replace("ModelPlanAppIntegration/Sources/ModelPlanAppIntegration", "ModelPlanDock/Native")])
    assert.equal(R.designTouch([file(other)], conf).touching, true, other);
});

test("GLM gate: seams only, exact head, comment must start with the line, latest wins", () => {
  const files = [file("cli/main.go")];
  const merge = comment(v("merge"));
  assert.equal(evalPr({ files: [file("scripts/x.mjs")], comments: [merge] }).state, R.SUCCESS, "outside GLM scope");
  assert.equal(evalPr({ files, comments: [merge] }).state, R.PENDING, "a seam PR waits for GLM");
  assert.equal(evalPr({ files, comments: [merge, comment(`note\nGLMREV: OK @ ${H}`)] }).state, R.PENDING);
  assert.equal(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${H}0`)] }).state, R.PENDING);
  assert.equal(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${H}`), comment(`GLMREV: ISSUES @ ${H}\n1. x`)] }).state, R.FAILURE);
  assert.equal(evalPr({ files, comments: [merge, comment(`GLMREV: ISSUES @ ${H}`), comment(`GLMREV-ACCEPTED @ ${H}`)] }).state, R.SUCCESS);
  assert.equal(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${OLD}`), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true }).state, R.PENDING, "GLMREV never carries");
});

test("GLM-out fallback: (sonnet) DESIGN/GLMREV pass only inside the window, exact head, posted before expiry; fail/ISSUES always count", () => {
  const UNTIL = "2026-11-14T12:17:50Z", until = Date.parse(UNTIL);
  const inside = Date.parse("2026-11-09T12:00:00Z"), after = until + 1000;
  const evalFb = ({ comments, files, now = inside, u = until }) =>
    R.evaluatePr({ pr: pr(), items: R.feed(comments), files, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, glmFallbackUntil: u, now });
  // window parsing: strict UTC form, at most 8 days ahead
  assert.equal(R.parseFallbackUntil(UNTIL, inside), until);
  assert.equal(R.parseFallbackUntil("", inside), null);
  assert.equal(R.parseFallbackUntil("2026-11-14 12:17:50", inside), null);
  assert.equal(R.parseFallbackUntil("2026-12-30T00:00:00Z", inside), null, "too far ahead");

  const merge = comment(v("merge"));
  const seam = [file("cli/main.go")];
  const gOk = comment(`GLMREV (sonnet): OK @ ${H}\n\nSonnet review`);
  const r = evalFb({ comments: [merge, gOk], files: seam });
  assert.equal(r.state, R.SUCCESS);
  assert.deepEqual(r.glmFallback, ["GLMREV (sonnet)"]);
  assert.match(r.why, /via GLMREV \(sonnet\)/);
  assert.equal(evalFb({ comments: [merge, gOk], files: seam, now: after }).state, R.PENDING, "expired window");
  assert.equal(evalFb({ comments: [merge, gOk], files: seam, u: null }).state, R.PENDING, "no window");
  assert.equal(evalFb({ comments: [merge, comment(`GLMREV (sonnet): OK @ ${OLD}`)], files: seam }).state, R.PENDING, "other head");
  assert.equal(evalFb({ comments: [merge, comment(`GLMREV (sonnet): OK @ ${H.slice(0, 12)}`)], files: seam }).state, R.PENDING, "short sha");
  assert.equal(evalFb({ comments: [merge, comment(`note\nGLMREV (sonnet): OK @ ${H}`)], files: seam }).state, R.PENDING, "must start the comment");
  assert.equal(evalFb({ comments: [merge, comment(`GLMREV (sonnet): OK @ ${H}`, { login: "guanbear", id: 1 })], files: seam }).state, R.PENDING, "untrusted");
  assert.equal(evalFb({ comments: [merge, comment(`GLMREV (sonnet): ISSUES @ ${H}`)], files: seam, now: after }).state, R.FAILURE, "ISSUES always counts");
  assert.equal(evalFb({ comments: [merge, comment(`GLMREV: OK @ ${H}`)], files: seam, now: after }).state, R.SUCCESS, "GLM markers unchanged");
  // posted after the window closed (a window set in the past but still parsed): never counts
  const late = { user: ME, body: `GLMREV (sonnet): OK @ ${H}`, created_at: "2026-11-15T00:00:00Z" };
  assert.equal(evalFb({ comments: [merge, late], files: seam, now: inside, u: Date.parse("2026-11-14T00:00:00Z") }).state, R.PENDING);

  const ui = [file("desktop/native/ModelPlanSettings/Pane.swift")], glm = comment(`GLMREV: OK @ ${H}`);
  const dOk = comment(`Design-conformance review (sonnet) @ ${H}\n\nDESIGN (sonnet): pass @ ${H}`);
  const d = evalFb({ comments: [merge, glm, dOk], files: ui });
  assert.equal(d.state, R.SUCCESS);
  assert.deepEqual(d.glmFallback, ["DESIGN (sonnet)"]);
  assert.equal(evalFb({ comments: [merge, glm, dOk], files: ui, now: after }).state, R.PENDING, "expired window");
  assert.equal(evalFb({ comments: [merge, glm, comment(`Tier review\nDESIGN (sonnet): pass @ ${H}`)], files: ui }).state, R.PENDING, "needs the design-conformance header");
  assert.equal(evalFb({ comments: [merge, glm, comment(`Design-conformance review (sonnet) @ ${H}\nDESIGN (sonnet): fail @ ${H}`)], files: ui, now: after }).state, R.FAILURE, "fail always counts");
});

test("GLM-out fallback mixing: a (sonnet) pass/OK only at the exact head and never over a fail/ISSUES; fail/ISSUES from either reviewer stays blocking", () => {
  const until = Date.parse("2026-11-14T12:17:50Z"), now = Date.parse("2026-11-09T12:00:00Z");
  const evalFb = ({ comments, files, verified = () => false }) =>
    R.evaluatePr({ pr: pr(), items: R.feed(comments), files, runs: greenCi, statuses: [], verifiedEdge: verified, conf, glmFallbackUntil: until, now });
  const merge = comment(v("merge")), glm = comment(`GLMREV: OK @ ${H}`);
  const ui = [file("desktop/native/ModelPlanSettings/Pane.swift")], seam = [file("cli/main.go")];
  const dsn = (r, sha = H) => comment(`Design-conformance review (sonnet) @ ${sha}\n\nDESIGN (sonnet): ${r} @ ${sha}`);
  const dglm = (r, sha = H) => comment(`Design-conformance review (GLM) @ ${sha}\n\nDESIGN: ${r} @ ${sha}`);
  const carry = comment(`VERDICT-CARRY: ${OLD} -> ${H}`);
  // exact head only: a (sonnet) pass at a carried head does not count; a GLM pass there still carries
  assert.equal(evalFb({ comments: [merge, glm, dsn("pass", OLD), carry], files: ui, verified: () => true }).state, R.PENDING, "sonnet pass over a carry edge");
  assert.equal(evalFb({ comments: [merge, glm, dglm("pass", OLD), carry], files: ui, verified: () => true }).state, R.SUCCESS, "GLM pass still carries");
  // DESIGN: no overriding across reviewers
  assert.equal(evalFb({ comments: [merge, glm, dglm("fail"), dsn("pass")], files: ui }).state, R.FAILURE, "sonnet pass over GLM fail");
  assert.equal(evalFb({ comments: [merge, glm, dsn("fail"), dglm("pass")], files: ui }).state, R.FAILURE, "GLM pass over sonnet fail");
  assert.equal(evalFb({ comments: [merge, glm, dsn("fail"), dsn("pass")], files: ui }).state, R.FAILURE, "sonnet pass over sonnet fail");
  assert.equal(evalFb({ comments: [merge, glm, dglm("fail"), dglm("pass")], files: ui }).state, R.SUCCESS, "GLM-only: latest wins");
  // GLMREV: same, with GLMREV-ACCEPTED as the only lift
  const g = (b) => comment(`${b} @ ${H}`);
  assert.equal(evalFb({ comments: [merge, g("GLMREV: ISSUES"), g("GLMREV (sonnet): OK")], files: seam }).state, R.FAILURE, "sonnet OK over GLM ISSUES");
  assert.equal(evalFb({ comments: [merge, g("GLMREV (sonnet): ISSUES"), g("GLMREV: OK")], files: seam }).state, R.FAILURE, "GLM OK over sonnet ISSUES");
  assert.equal(evalFb({ comments: [merge, g("GLMREV (sonnet): ISSUES"), g("GLMREV-ACCEPTED")], files: seam }).state, R.SUCCESS, "ACCEPTED lifts");
  assert.equal(evalFb({ comments: [merge, g("GLMREV: ISSUES"), g("GLMREV: OK")], files: seam }).state, R.SUCCESS, "GLM-only: latest wins");
  assert.equal(evalFb({ comments: [merge, g("GLMREV (sonnet): OK"), g("GLMREV: ISSUES")], files: seam }).state, R.FAILURE, "a later ISSUES wins");
});

test("DESIGN-ACCEPTED: coordinator lift of a GLM or (sonnet) DESIGN fail, exact head, trusted comment first line only", () => {
  const until = Date.parse("2026-11-14T12:17:50Z"), now = Date.parse("2026-11-09T12:00:00Z");
  const evalD = ({ comments, reviews = [], verified = () => false, u = until }) =>
    R.evaluatePr({ pr: pr(), items: R.feed(comments, reviews), files: [file("desktop/native/ModelPlanSettings/Pane.swift")], runs: greenCi, statuses: [], verifiedEdge: verified, conf, glmFallbackUntil: u, now });
  const merge = comment(v("merge")), glm = comment(`GLMREV: OK @ ${H}`);
  const gFail = comment(`Design-conformance review (GLM) @ ${H}\nDESIGN: fail @ ${H}`);
  const sFail = comment(`Design-conformance review (sonnet) @ ${H}\nDESIGN (sonnet): fail @ ${H}`);
  const ok = evalD({ comments: [merge, glm, gFail, comment(`DESIGN-ACCEPTED @ ${H}\n\nCoordinator: out of scope.`)] });
  assert.equal(ok.state, R.SUCCESS);
  assert.match(ok.why, /via DESIGN-ACCEPTED/);
  assert.equal(evalD({ comments: [merge, glm, sFail, comment(`DESIGN-ACCEPTED @ ${H}`)], u: null }).state, R.SUCCESS, "lifts a sonnet fail, window not needed");
  const lift = comment(`DESIGN-ACCEPTED @ ${H}`), laterFail = comment(`Design-conformance review (GLM) @ ${H}\nDESIGN: fail @ ${H}`);
  assert.equal(evalD({ comments: [merge, glm, lift, laterFail] }).state, R.FAILURE, "a later fail wins again");
  assert.equal(evalD({ comments: [merge, glm] }).state, R.PENDING);
  assert.equal(evalD({ comments: [merge, glm, comment(`DESIGN-ACCEPTED @ ${H}`)] }).state, R.SUCCESS, "also stands in for a missing pass");
  for (const [why, c, rv] of [
    ["carried head", [comment(`DESIGN-ACCEPTED @ ${OLD}`), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], []],
    ["short sha", [comment(`DESIGN-ACCEPTED @ ${H.slice(0, 12)}`)], []],
    ["not the first line", [comment(`note\nDESIGN-ACCEPTED @ ${H}`)], []],
    ["untrusted", [comment(`DESIGN-ACCEPTED @ ${H}`, { login: "guanbear", id: 1 })], []],
    ["inside a design review", [comment(`Design-conformance review (sonnet) @ ${H}\nDESIGN-ACCEPTED @ ${H}`)], []],
    ["a review, not a comment", [], [review(`DESIGN-ACCEPTED @ ${H}`)]],
  ]) assert.equal(evalD({ comments: [merge, glm, gFail, ...c], reviews: rv, verified: () => true }).state, R.FAILURE, why);
});

test("CI at the head: newest run per workflow, parse-time failures, statuses, anchor workflow", () => {
  assert.equal(R.ciState([]).state, R.PENDING);
  assert.equal(R.ciState(greenCi).state, R.SUCCESS);
  assert.equal(R.ciState([run(".github/workflows/ci.yml", "failure", 1), run(".github/workflows/ci.yml", "success", 2)]).state, R.SUCCESS);
  assert.equal(R.ciState([...greenCi, run(".github/workflows/desktop.yml", "startup_failure", 5)]).state, R.FAILURE);
  assert.equal(R.ciState([...greenCi, run(".github/workflows/desktop.yml", "cancelled", 5)]).state, R.FAILURE);
  assert.equal(R.ciState([...greenCi, run(".github/workflows/desktop.yml", null, 5, "in_progress")]).state, R.PENDING);
  assert.equal(R.ciState([...greenCi, run(".github/workflows/merge-gates.yml", "failure", 9)]).state, R.SUCCESS, "own runs never count");
  assert.equal(R.ciState(greenCi, [{ context: "modelplan-gates", state: "failure" }]).state, R.SUCCESS);
  assert.equal(R.ciState(greenCi, [{ context: "other", state: "error" }]).state, R.FAILURE);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [] }).state, R.PENDING);
  assert.equal(evalPr({ comments: [], runs: [run(".github/workflows/ci.yml", "failure")] }).state, R.FAILURE, "a red head fails before reviews arrive");
});

test("CI scope: a fork's newer passing run for the same head sha never masks our failing run", () => {
  const CI = ".github/workflows/ci.yml";
  const ours = run(CI, "failure", 1);
  const fork = run(CI, "success", 2, "completed", { head_repository: { full_name: "attacker/modelplan" }, pull_requests: [] });
  // Without a scope the newest run wins: this is the masking the scope closes.
  assert.equal(R.ciState([ours, fork]).state, R.SUCCESS);
  const masked = evalPr({ comments: [comment(v("merge"))], runs: [ours, fork] });
  assert.equal(masked.state, R.FAILURE, "our own failing run still decides");
  assert.match(masked.why, /ci\.yml failure/);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [fork] }).state, R.PENDING, "a fork's run alone never counts as CI");
  // Another PR of this repository with the same head (a train branch) does not speak for this PR either.
  const other = run(CI, "success", 3, "completed", { head_branch: "train/x", pull_requests: [{ number: 8 }] });
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [ours, other] }).state, R.FAILURE);
  // A same-repository run with no PR list (a manual run) counts only on the PR's branch.
  const manual = (branch) => run(CI, "success", 4, "completed", { event: "workflow_dispatch", head_branch: branch, pull_requests: [] });
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [ours, manual("feature/x")] }).state, R.SUCCESS);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [ours, manual("elsewhere")] }).state, R.FAILURE);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [run(CI, "success", 1, "completed", { head_repository: null })] }).state, R.PENDING, "no repository, no trust");
});

test("CI scope in the merge queue: only this repository's merge_group runs count for the group commit", () => {
  const ok = { pr: 7, prResult: { state: R.SUCCESS, why: "ok" }, mergeProof: { ok: true } };
  const failing = R.QUEUE_WORKFLOWS.map((path) => qrun(path, "failure", 1));
  const forkGreen = R.QUEUE_WORKFLOWS.map((path) => run(path, "success", 9, "completed", { head_repository: { full_name: "attacker/modelplan" }, pull_requests: [] }));
  const group = R.evaluateGroup({ steps: [ok], queueRuns: [...failing, ...forkGreen] });
  assert.equal(group.state, R.FAILURE, "a fork PR at the group commit cannot pass the group");
  assert.equal(R.evaluateGroup({ steps: [ok], queueRuns: forkGreen }).state, R.PENDING, "fork runs alone: the queue's CI has not run");
  // A pull_request run of ours at the group sha is not the queue's run either.
  assert.equal(R.evaluateGroup({ steps: [ok], queueRuns: R.QUEUE_WORKFLOWS.map((path) => run(path)) }).state, R.PENDING);
  assert.equal(R.evaluateGroup({ steps: [ok], queueRuns: greenQueue, repo: "other/repo" }).state, R.PENDING, "repo comes from the caller");
  // A single-PR group reuses the head's checks: the PR's own fork-masked failure fails that step first.
  const head = evalPr({ comments: [comment(v("merge"))], runs: [run(".github/workflows/ci.yml", "failure", 1),
    run(".github/workflows/ci.yml", "success", 2, "completed", { head_repository: { full_name: "attacker/modelplan" }, pull_requests: [] })] });
  assert.equal(R.evaluateGroup({ steps: [{ pr: 7, prResult: head, mergeProof: { ok: true } }], queueRuns: greenQueue }).state, R.FAILURE);
});

test("CI cancelled upstream: the newest run being cancelled fails the head; a superseded head's cancel is skipped", () => {
  const CI = ".github/workflows/ci.yml";
  const timedOut = evalPr({ comments: [comment(v("merge"))], runs: [run(CI, "cancelled", 2)] });
  assert.equal(timedOut.state, R.FAILURE, "a timed-out run never leaves the head pending");
  assert.match(timedOut.why, /cancelled upstream/);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [run(CI, "cancelled", 1), run(CI, "success", 2)] }).state, R.SUCCESS, "a re-run replaces it");
  assert.equal(R.evaluateGroup({ steps: [{ pr: 7, prResult: { state: R.SUCCESS, why: "ok" }, mergeProof: { ok: true } }],
    queueRuns: [qrun(CI, "cancelled"), qrun(".github/workflows/desktop.yml")] }).state, R.FAILURE);
  assert.equal(R.cancelledRunSuperseded({ conclusion: "cancelled", head_sha: OLD }, H), true, "a newer push replaced it");
  assert.equal(R.cancelledRunSuperseded({ conclusion: "cancelled", head_sha: H }, H), false, "still the head: evaluate");
  assert.equal(R.cancelledRunSuperseded({ conclusion: "failure", head_sha: OLD }, H), false);
});

test("ledger evidence: exact-head trusted comment required for every listed scenario", () => {
  const docs = [file("docs/evidence.md")];
  const ledger = (body, extra = {}) => pr({ title: "Fix G3-07", body, ...extra });
  const mark = (id, sha = H) => `VERIFIED: ${id} @ ${sha} evidence=artifacts/run-1`;
  assert.equal(evalPr({ p: ledger("Details"), files: docs }).state, R.FAILURE);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01, V-03"), files: docs }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01"), {login:"other", id:1})] }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01", OLD))] }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01"), files: docs, reviews: [review(mark("D-01"))] }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01, V-03"), files: docs, comments: [comment(mark("D-01")), comment(mark("V-03"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ p: pr({title:"Ordinary fix", body:""}), files: docs }).state, R.SUCCESS);
  assert.equal(evalPr({ p: pr({title:"Ordinary", body:"Scenarios: D-01", head:{sha:H, ref:"fix/g3-12", repo:{full_name:"modelplan/modelplan"}}}), files: docs }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(`VERIFIED: D-01 @ ${H} evidence=`)] }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01", OLD)), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("**Scenarios:** D-01, D-01"), files: docs, comments: [comment(mark("D-01"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01, V-03"), files: docs, comments: [comment(mark("D-01")), comment(mark("V-03"), {login:"guanbear",id:1})] }).state, R.PENDING);
  assert.equal(evalPr({ p: ledger("Scenarios: D-01\nScenarios: V-03"), files: docs, comments: [comment(mark("D-01"))] }).state, R.SUCCESS, "only the first declaration counts");
  assert.equal(evalPr({ p: ledger("Scenarios: d-01"), files: docs }).state, R.FAILURE, "IDs follow the shell gate's uppercase format");
  assert.equal(evalPr({ p: ledger("Scenarios: G3-12, V-03"), files: docs, comments: [comment(mark("V-03"))] }).state, R.PENDING, "ledger scenario needs its own evidence");
  assert.equal(evalPr({ p: ledger("Scenarios: G3-12, V-03"), files: docs, comments: [comment(mark("G3-12")), comment(mark("V-03"))] }).state, R.SUCCESS, "numeric scenario prefixes match verified evidence");
});

test("merge group requires evidence for each member's own head", () => {
  const docs = [file("docs/evidence.md")];
  const first = evalPr({p:pr({title:"G3-01", body:"Scenarios: D-01"}), files:docs,
    comments:[comment(`VERIFIED: D-01 @ ${H} evidence=first`)]});
  const other = pr({title:"G3-02", body:"Scenarios: D-02", head:{sha:OLD, ref:"fix/g3-02", repo:{full_name:"modelplan/modelplan"}}});
  const absent = evalPr({p:other, files:docs, comments:[comment(`VERIFIED: D-02 @ ${H} evidence=wrong-head`)]});
  const valid = evalPr({p:other, files:docs, comments:[comment(`VERIFIED: D-02 @ ${OLD} evidence=second`)]});
  const step = (n, result) => ({pr:n, prResult:result, mergeProof:{ok:true}});
  const queueRuns = greenQueue;
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, absent)], queueRuns}).state, R.FAILURE);
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, valid)], queueRuns}).state, R.SUCCESS);
});

test("malformed scenario members fail PR and merge group despite valid evidence", () => {
  const docs = [file("docs/evidence.md")];
  const receipt = comment(`VERIFIED: V-01 @ ${H} evidence=fixture`);
  for (const invalid of ["S6", "d-01", "V-1", "V-001"]) {
    const result = evalPr({ p: pr({title:"G3-07", body:`Scenarios: V-01, ${invalid}`}), files:docs, comments:[receipt] });
    assert.equal(result.state, R.FAILURE, invalid);
    assert.equal(R.evaluateGroup({steps:[{pr:1, prResult:result, mergeProof:{ok:true}}], queueRuns:greenQueue}).state, R.FAILURE, invalid);
  }
  const valid = evalPr({p:pr({title:"G3-07", body:"Scenarios: V-01 (normal entry), V-01"}), files:docs, comments:[receipt]});
  assert.equal(valid.state, R.SUCCESS);
});

test("a Scenarios line without a ledger row needs the same exact-head evidence (#661: C-10 passed unaccounted)", () => {
  const docs = [file("docs/evidence.md")];
  const plain = (body) => pr({ title: "Cockpit publication", body: `Ledger: none\n${body}`, head: { sha: H, ref: "web/publication", repo: { full_name: "modelplan/modelplan" } } });
  const done = (id) => comment(`VERIFIED: ${id} @ ${H} evidence=fixture`);
  const pending = evalPr({ p: plain("Scenarios: C-09, C-10"), files: docs, comments: [done("C-09")] });
  assert.equal(pending.state, R.PENDING);
  assert.match(pending.why, /evidence pending: C-10/);
  const group = R.evaluateGroup({ steps: [{ pr: 661, prResult: pending, mergeProof: { ok: true } }], queueRuns: greenQueue });
  assert.equal(group.state, R.FAILURE, "a pending member never lands");
  assert.equal(evalPr({ p: plain("Scenarios: C-09, C-10"), files: docs, comments: [done("C-09"), comment(`EVIDENCE-DEFERRED: C-10 @ ${H} issue=470`)] }).state, R.SUCCESS);
  assert.equal(evalPr({ p: plain("Scenarios: C-09"), files: docs, comments: [comment(`VERIFIED: C-09 @ ${OLD} evidence=fixture`)] }).state, R.PENDING, "another head proves nothing");
  assert.equal(evalPr({ p: plain("Scenarios: none"), files: docs }).state, R.SUCCESS);
  assert.equal(evalPr({ p: pr({ title: "Docs", body: "No declaration here." }), files: docs }).state, R.SUCCESS);
});

test("D21: without a ledger row a CI-tier scenario rides on green CI; real-Mac tiers and anything unknown need a line", () => {
  const docs = [file("docs/evidence.md")];
  const tiers = R.parseTiers("# comment\nid\ttier\tneeds\nS-11\tT2\t-\nV-17\tT1P\t-\nR-01\tT0\tVF\nC-10\tT3\tCK\nD-02\tT4\tSYS\n");
  assert.deepEqual([...tiers], [["S-11", "T2"], ["V-17", "T1P"], ["R-01", "T0"], ["C-10", "T3"], ["D-02", "T4"]]);
  const plain = (line) => pr({ title: "Cockpit", body: `Ledger: none\nScenarios: ${line}` });
  const ev = (line, o = {}) => R.evaluatePr({ pr: plain(line), items: R.feed(o.comments ?? []), files: docs, runs: o.runs ?? greenCi, statuses: [], verifiedEdge: () => false, conf, tiers: o.tiers ?? tiers });

  assert.equal(ev("S-11, V-17, R-01").state, R.SUCCESS, "T2 passes on green CI");
  assert.equal(ev("S-11", { runs: [run(".github/workflows/ci.yml", "failure")] }).state, R.FAILURE, "red CI stops it");
  assert.equal(ev("S-11", { runs: [run(".github/workflows/ci.yml", null, 1, "in_progress")] }).state, R.PENDING, "running CI is not green");
  const t3 = ev("S-11, C-10");
  assert.equal(t3.state, R.PENDING, "T3 still needs its line");
  assert.match(t3.why, /evidence pending: C-10$|evidence pending: C-10\b/);
  assert.doesNotMatch(t3.why, /S-11/);
  assert.equal(ev("D-02").state, R.PENDING, "T4 too");
  assert.equal(ev("C-10", { comments: [comment(`EVIDENCE-DEFERRED: C-10 @ ${H} issue=470`)] }).state, R.SUCCESS);
  assert.equal(ev("C-10", { comments: [comment(`VERIFIED: C-10 @ ${H} evidence=fixture`)] }).state, R.SUCCESS);
  assert.equal(ev("Z-01").state, R.PENDING, "a scenario missing from the table needs evidence");
  assert.equal(ev("G3-12").state, R.PENDING, "a ledger row in the line is a ledger PR");
  // A PR naming a ledger row needs a line for every scenario, whatever its tier.
  const ledger = R.evaluatePr({ pr: pr({ title: "Fix G3-07", body: "Scenarios: S-11" }), items: [], files: docs, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, tiers });
  assert.equal(ledger.state, R.PENDING);

  // Fail closed: no readable table means every scenario needs evidence.
  const missing = R.tiersFrom(() => { throw new Error("ENOENT"); });
  assert.equal(missing.size, 0);
  assert.equal(ev("S-11", { tiers: missing }).state, R.PENDING);
  assert.equal(ev("S-11", { tiers: R.tiersFrom(() => "not a table\n") }).state, R.PENDING);

  // The shipped table, and the checkout that must bring it to the gate.
  const shipped = R.tiersFrom(() => readFileSync(join(root, R.TIER_TABLE), "utf8"));
  assert.equal(shipped.get("C-10"), "T3");
  assert.ok(shipped.size > 90);
  const sparse = /sparse-checkout: \|\n((?:\s+\S+\n)+)/.exec(readFileSync(join(root, ".github/workflows/merge-gates.yml"), "utf8"))?.[1].trim().split(/\s+/) ?? [];
  assert.ok(sparse.includes("scripts/merge-gates"), "the gate's own code");
  assert.ok(sparse.includes(dirname(R.TIER_TABLE)), "cone-mode sparse checkout takes directories, so the table's directory");
});

test("Scenarios lines: spec IDs or none, on every PR; requirement IDs and free text are rejected (exception review 1.4)", () => {
  const docs = [file("docs/evidence.md")];
  const plain = (line) => pr({ title: "Widget setting", body: `Ledger: none\n${line}` });
  for (const line of [
    "Scenarios: SET-9-09",
    "Scenarios: SET-9 Quota Widget controls (widget side)",
    "Scenarios: LBL-2.2-01, LBL-2.2-02",
    "Scenarios: DOCK-3.1-01, D-01",
    "Scenarios: owner test build opens the cockpit from the menu bar",
    "Scenarios: D-01 and a sentence",
    "Scenarios: none listed",
    "Scenarios: none, D-03",
    "Scenarios:",
    "Scenarios were not changed",
  ]) {
    const result = evalPr({ p: plain(line), files: docs });
    assert.equal(result.state, R.FAILURE, line);
    assert.match(result.why, /Scenarios line/, line);
  }
  const draft = evalPr({ p: pr({ draft: true, title: "x", body: "Scenarios: SET-9-12" }), files: docs });
  assert.equal(draft.state, R.FAILURE, "a draft sees the rejection at once");
  // Forms real PRs use: notes in brackets, semicolons, bold, none with a note.
  const shapes = {
    "Scenarios: R-08, R-09 (partial evidence); V-06, V-07": ["R-08", "R-09", "V-06", "V-07"],
    "**Scenarios:** C-13 (Effort and Breakdown slice), C-05 (live locale; web slice)": ["C-05", "C-13"],
    "Scenarios: D-12 and D-24": ["D-12", "D-24"],
    "Scenarios: G3-12, V-03": ["G3-12", "V-03"],
    "Scenarios: none": [],
    "**Scenarios:** None": [],
    "Scenarios: none (no new product behaviour)": [],
  };
  for (const [line, ids] of Object.entries(shapes)) {
    const parsed = R.parseScenarios(`Intro\n${line}\nScenarios: SET-9-09`);
    assert.equal(parsed.malformed, null, line);
    assert.deepEqual(parsed.ids, ids, line);
  }
  assert.equal(R.parseScenarios("no line").declared, false);
});

test("train: every member's scenarios must be in the train's own line (#650 dropped seven)", () => {
  const docs = [file("docs/evidence.md")];
  const ref = (name) => ({ sha: H, ref: name, repo: { full_name: "modelplan/modelplan" } });
  const train = pr({ title: "Quota Widget train", body: "Ledger: none\nScenarios: D-01, V-02", head: ref("b/widget-train") });
  const done = [comment(`VERIFIED: D-01 @ ${H} evidence=fixture`), comment(`VERIFIED: V-02 @ ${H} evidence=fixture`)];
  const trainPr = (members, p = train) => R.evaluatePr({ pr: p, items: R.feed(done), files: docs, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, members });
  assert.equal(trainPr([{ number: 1, body: "Scenarios: D-01" }, { number: 2, body: "Scenarios: none" }, { number: 3, body: "no line" }]).state, R.SUCCESS);
  const short = trainPr([{ number: 519, body: "Scenarios: R-08, V-02" }, { number: 518, body: "Scenarios: S-01" }]);
  assert.equal(short.state, R.FAILURE);
  assert.match(short.why, /#519: R-08/);
  assert.match(short.why, /#518: S-01/);
  const bad = trainPr([{ number: 626, body: "Scenarios: SET-9 Quota Widget controls" }]);
  assert.equal(bad.state, R.FAILURE, "an unreadable member line cannot be proved a subset");
  assert.match(bad.why, /#626/);
  const none = pr({ title: "Train", body: "Scenarios: none", head: ref("b/x") });
  assert.equal(trainPr([{ number: 7, body: "Scenarios: D-01" }], none).state, R.FAILURE);

  assert.ok(R.isTrain(train));
  assert.ok(R.isTrain(pr({ title: "Build 9 TRAIN", body: "" })));
  assert.ok(R.isTrain(pr({ title: "x", body: "", head: ref("b/widget") })));
  assert.ok(R.isTrain(pr({ title: "x", body: "## Supersedes\n\n#620" })));
  assert.ok(!R.isTrain(pr({ title: "Restrained change", body: "supersedes #1 in prose", head: ref("feature/b/x") })));
  assert.deepEqual(R.supersededPrs("Intro #1\n## Supersedes\n\n#620, #621. Also #518 (see #518).\n\n## Dependencies\n\n#646"), [518, 620, 621]);
  assert.deepEqual(R.supersededPrs("#1 only"), []);

  // Members: merged into the train branch, or an open PR whose exact head the train contains, or superseded by name.
  const inTrain = new Set(["1".repeat(40)]);
  const picked = R.trainMembers(train, {
    based: [{ number: 665, merged_at: "2026-11-07T00:00:00Z", head: { sha: "2".repeat(40) }, body: "a" }, { number: 666, merged_at: null, head: { sha: "1".repeat(40) }, body: "b" }, { number: 669, merged_at: null, head: { sha: "3".repeat(40) }, body: "c" }],
    open: [{ number: 519, head: { sha: "1".repeat(40) }, body: "d" }, { number: 700, head: { sha: "4".repeat(40) }, body: "e" }, { number: 665, head: { sha: "2".repeat(40) }, body: "a" }],
    superseded: [{ number: 620, head: { sha: "5".repeat(40) }, base: { ref: "main" }, body: "f" }, { number: 650, head: { sha: H }, body: "self" },
      { number: 523, merged_at: "2026-11-07T00:00:00Z", head: { sha: "6".repeat(40) }, base: { ref: "main" }, body: "landed under its own gate" }],
    commits: inTrain,
  });
  assert.deepEqual(picked.map((m) => m.number), [519, 620, 665, 666]);
});

test("merge-group evaluation: the group's own CI replaces any stale-base rule", () => {
  const ok = { state: R.SUCCESS, why: "ok" };
  const step = (o = {}) => ({ pr: 7, prResult: ok, mergeProof: { ok: true }, ...o });
  const qci = greenQueue;
  assert.ok(R.QUEUE_WORKFLOWS.includes(".github/workflows/desktop.yml"), "the queue must test the Mac build class");
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: qci }).state, R.SUCCESS);
  assert.equal(R.evaluateGroup({ steps: [], queueRuns: qci }).state, R.FAILURE);
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [] }).state, R.PENDING, "queue CI not started yet");
  assert.equal(R.evaluateGroup({ steps: [step(), step({ pr: 8, prResult: { state: R.PENDING, why: "x" } })], queueRuns: qci }).state, R.FAILURE, "an unready PR fails the group");
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [qrun(".github/workflows/ci.yml")] }).state, R.PENDING, "the Mac queue run has not started");
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [qrun(".github/workflows/ci.yml"), qrun(".github/workflows/desktop.yml", "failure")] }).state, R.FAILURE, "a failed Mac queue run fails the group");
  assert.equal(R.evaluateGroup({ steps: [step({ mergeProof: { ok: false, why: "x" } })], queueRuns: qci }).state, R.FAILURE);
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [qrun(".github/workflows/ci.yml", "failure"), qrun(".github/workflows/desktop.yml")] }).state, R.FAILURE);
  assert.ok(R.description("x".repeat(200)).length <= 140);
});

// ---- Git proofs against a real repository ----
function repo() {
  const dir = mkdtempSync(join(tmpdir(), "merge-gates-"));
  const env = { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@example.invalid", GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
  const g = (...args) => execFileSync("git", args, { cwd: dir, env, encoding: "utf8" }).trim();
  const put = (path, text) => writeFileSync(join(dir, path), text);
  g("init", "-q", "-b", "main");
  g("config", "core.fileMode", "true");
  put("a.txt", "a\n"); put("b.txt", "b\n"); put("c.txt", "c\n");
  g("add", "."); g("commit", "-qm", "base");
  g("update-ref", "refs/remotes/origin/main", "HEAD");
  return { dir, g, put, sha: () => g("rev-parse", "HEAD"), done: () => rmSync(dir, { recursive: true, force: true }) };
}
const MAINREF = "refs/remotes/origin/main";

test("carry proof: object-identical contribution over a clean main merge, fail closed otherwise", () => {
  const r = repo();
  try {
    r.g("checkout", "-qb", "pr");
    r.put("a.txt", "a2\n"); r.g("commit", "-qam", "pr change");
    const reviewed = r.sha();
    r.g("checkout", "-q", "main");
    r.put("b.txt", "b2\n"); r.g("commit", "-qam", "main change");
    r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-q", "pr"); r.g("merge", "-q", "--no-edit", "main");
    const carried = r.sha();
    assert.deepEqual(G.verifyCarry(r.dir, reviewed, carried, MAINREF), { ok: true, why: "object-identical contribution" });
    assert.equal(G.verifyCarry(r.dir, carried, reviewed, MAINREF).ok, false);

    // Main touched the PR's own file: the contribution is no longer the reviewed one.
    r.g("checkout", "-q", "main");
    r.put("a.txt", "a2\n"); r.g("commit", "-qam", "main makes the same edit to a");
    r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-q", "pr"); r.g("merge", "-q", "--no-edit", "main");
    assert.equal(G.verifyCarry(r.dir, carried, r.sha(), MAINREF).ok, false);

    // An extra change hidden in the merge commit is caught.
    r.g("checkout", "-q", "-b", "pr2", reviewed);
    r.g("merge", "-q", "--no-commit", "main~1"); r.put("c.txt", "sneaky\n"); r.g("add", "c.txt"); r.g("commit", "-qm", "merge");
    assert.equal(G.verifyCarry(r.dir, reviewed, r.sha(), MAINREF).why, "contribution changed by the merge");

    // A mode-only change is part of the contribution.
    r.g("checkout", "-q", "-b", "pr3", reviewed);
    r.g("merge", "-q", "--no-commit", "main~1"); chmodSync(join(r.dir, "a.txt"), 0o755); r.g("add", "a.txt"); r.g("commit", "-qm", "merge");
    assert.equal(G.verifyCarry(r.dir, reviewed, r.sha(), MAINREF).ok, false);

    // Second parent must be on main.
    r.g("checkout", "-q", "-b", "side", "main~2"); r.put("c.txt", "side\n"); r.g("commit", "-qam", "side");
    r.g("checkout", "-q", "-b", "pr4", reviewed); r.g("merge", "-q", "--no-edit", "side");
    assert.equal(G.verifyCarry(r.dir, reviewed, r.sha(), MAINREF).why, "second parent is not on main");
  } finally { r.done(); }
});

test("commitsOnlyIn: the head's commits that main does not have, fail closed on a missing object", () => {
  const r = repo();
  try {
    const base = r.sha();
    r.g("checkout", "-qb", "member"); r.put("a.txt", "m\n"); r.g("commit", "-qam", "member");
    const member = r.sha();
    r.g("checkout", "-qb", "train"); r.put("b.txt", "t\n"); r.g("commit", "-qam", "train");
    const train = r.sha();
    const only = G.commitsOnlyIn(r.dir, train, MAINREF);
    assert.ok(only.has(member) && only.has(train));
    assert.ok(!only.has(base));
    assert.throws(() => G.commitsOnlyIn(r.dir, "f".repeat(40), MAINREF), /not found/);
  } finally { r.done(); }
});

test("clean-merge proof: the group tree is exactly Git's merge of its parents", () => {
  const r = repo();
  try {
    r.g("checkout", "-qb", "pr");
    r.put("a.txt", "a2\n"); r.g("commit", "-qam", "pr");
    r.g("checkout", "-q", "main");
    r.put("b.txt", "b2\n"); r.g("commit", "-qam", "main");
    r.g("merge", "-q", "--no-ff", "--no-edit", "pr");
    assert.equal(G.verifyCleanMerge(r.dir, r.sha()).ok, true);
    r.put("c.txt", "extra\n"); r.g("commit", "-q", "--amend", "-a", "--no-edit");
    assert.equal(G.verifyCleanMerge(r.dir, r.sha()).ok, false);
    assert.equal(G.verifyCleanMerge(r.dir, r.g("rev-parse", "HEAD~1")).ok, false, "not a merge");
    assert.equal(G.verifyCleanMerge(r.dir, "0".repeat(40)).ok, false);
  } finally { r.done(); }
});

test("queue-scope sees every changed path, whatever Git would quote", () => {
  // Git quotes non-ASCII, quote and control characters in plain --name-only output, which would hide the
  // desktop/ prefix from the anchored match and let a group skip its Mac checks. Runs the shipped command.
  const desktop = readFileSync(join(root, ".github/workflows/desktop.yml"), "utf8");
  const paths = /^\s+QUEUE_PATHS: (.+)$/m.exec(desktop)[1];
  const command = /^\s+elif (git diff .+); then$/m.exec(desktop)[1];
  const scoped = (name) => {
    const dir = mkdtempSync(join(tmpdir(), "queue-scope-"));
    try {
      const git = (...args) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", ...args], { cwd: dir, stdio: "pipe" });
      git("init", "-q");
      git("commit", "-q", "--allow-empty", "-m", "base");
      const base = git("rev-parse", "HEAD").toString().trim();
      mkdirSync(dirname(join(dir, name)), { recursive: true });
      writeFileSync(join(dir, name), "x");
      git("add", "-A");
      git("commit", "-q", "-m", "change");
      return spawnSync("bash", ["-c", command], { cwd: dir, env: { ...process.env, BASE: base, QUEUE_PATHS: paths } }).status === 0;
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  };
  for (const name of ["desktop/native/a.swift", "desktop/native/测试.swift", 'desktop/a"b.swift', "desktop/a\tb.swift", "desktop/a\nb.swift", "codex/cli-pin.json"]) {
    assert.equal(scoped(name), true, `queue-scope misses ${JSON.stringify(name)}`);
  }
  for (const name of ["docs/mac-ci.md", "docs/desktop/测试.md", "codex/cli-pin.json.bak"]) {
    assert.equal(scoped(name), false, `queue-scope wrongly selects ${JSON.stringify(name)}`);
  }
});

test("shipped files: design rules parse, gate workflows pass the workflow policy", () => {
  assert.ok(conf.include.some((r) => r.surface === "dock") && conf.exclude.length >= 4 && conf.pinonly.length === 1);
  for (const f of ["merge-gates.yml", "merge-gates-probe.yml", "ci.yml"]) {
    const path = `.github/workflows/${f}`;
    assert.deepEqual(workflowProblems(readFileSync(join(root, path), "utf8"), path), [], path);
  }
  for (const path of [...R.QUEUE_WORKFLOWS, ".github/workflows/merge-gates-probe.yml"]) {
    assert.match(readFileSync(join(root, path), "utf8"), /^  merge_group:\s*$/m, `${path} must run for queue groups`);
  }
  // merge_group has no paths filter: queue-scope must decide with the same list as pull_request, or a
  // group could skip a Mac check its PR run would have needed. native-headless must wait for that decision.
  const desktop = readFileSync(join(root, ".github/workflows/desktop.yml"), "utf8");
  const prPathList = JSON.parse(/^  pull_request:\n    paths: (\[.*\])$/m.exec(desktop)[1]);
  const scope = new RegExp(/^\s+QUEUE_PATHS: (.+)$/m.exec(desktop)[1]);
  for (const p of prPathList) assert.match(p.replace(/\*\*$/, "x"), scope, `queue-scope misses ${p}`);
  assert.doesNotMatch("docs/mac-ci.md", scope);
  assert.match(/^  native-headless:\n(?:.*\n){1,3}/m.exec(desktop)[0], /needs: queue-scope/);
  const probe = readFileSync(join(root, ".github/workflows/merge-gates-probe.yml"), "utf8");
  assert.match(probe, /pull_request:\s*\n\s*types:\s*\[[^\]]*\bedited\b/, "PR title/body edits must re-evaluate evidence");
  const gates = readFileSync(join(root, ".github/workflows/merge-gates.yml"), "utf8");
  assert.match(gates, /actions\/checkout@[0-9a-f]{40} /, "the gate pins its action by commit");
  assert.doesNotMatch(gates, /^\s+(pull_request|merge_group|pull_request_review):/m, "the gate never runs PR code");
  // workflow_run names must match real workflow names, or the gate silently never re-evaluates.
  const dir = join(root, ".github/workflows");
  const names = new Set(readdirSync(dir).filter((f) => /\.ya?ml$/.test(f))
    .map((f) => /^name:\s*(.+)$/m.exec(readFileSync(join(dir, f), "utf8"))?.[1].trim()));
  const listed = /workflows:\n((?:\s+- .+\n)+)/.exec(gates)[1].split("\n").map((l) => l.replace(/^\s+- /, "").trim()).filter(Boolean);
  for (const n of listed) assert.ok(names.has(n), `workflow_run lists unknown workflow '${n}'`);
  // The probe skips new-head events, so the workflows that always run on them must re-evaluate the head.
  for (const [file, name] of [["ci.yml", "ci"], ["repo-checks.yml", "repo checks"]]) {
    const text = readFileSync(join(dir, file), "utf8");
    assert.ok(listed.includes(name), `merge-gates must re-evaluate when ${name} completes`);
    const types = /^  pull_request:\n(?:    #.*\n)*    types: \[(.*)\]$/m.exec(text)?.[1].split(/,\s*/) ?? [];
    for (const t of ["opened", "synchronize", "reopened", "ready_for_review"]) assert.ok(types.includes(t), `${file} must run on ${t}`);
    assert.doesNotMatch(/^  pull_request:\n(?:    .*\n)*/m.exec(text)[0], /paths:/, `${file} must run for every PR`);
  }
  // A run skipped by the job's `if:` must not cancel a live evaluation: the concurrency group sits on the job.
  assert.doesNotMatch(gates, /^concurrency:/m);
  assert.match(gates, /^    concurrency:\n      group: merge-gates-/m);
  // A cancelled run evaluates (a timeout cancels the whole run) unless a newer push replaced its head, and it never
  // shares a concurrency group with the live evaluation of the PR.
  const jobIf = /^    if: >-\n((?:      .*\n)+)/m.exec(gates)[1];
  assert.doesNotMatch(jobIf, /conclusion != 'cancelled'\n/, "cancelled runs are not dropped outright");
  assert.match(jobIf, /conclusion != 'cancelled' \|\| github\.event\.workflow_run\.event == 'merge_group'\n\s+\|\| github\.event\.workflow_run\.pull_requests\[0\]\.head\.sha == github\.event\.workflow_run\.head_sha\)/);
  assert.match(gates, /group: merge-gates-\$\{\{ github\.event\.workflow_run\.conclusion == 'cancelled' && format\('cancelled-\{0\}', github\.event\.workflow_run\.head_sha\)/);
  assert.match(readFileSync(join(root, "scripts/merge-gates/evaluate.mjs"), "utf8"), /cancelledRunSuperseded\(wr, /, "the evaluator re-checks the live head");
});

// ---- data-sync admission ----
const BOT = { login: "github-actions[bot]", id: 41898282, type: "Bot" };
const RUN_ID = 4242;
const syncPr = (over = {}) => pr({ user: BOT, created_at: "2026-11-08T01:00:05Z", head: { sha: H, ref: `data/sync-0.5.21-${RUN_ID}`, repo: { full_name: "modelplan/modelplan" } }, ...over });
const syncRun = (over = {}) => ({ id: RUN_ID, path: ".github/workflows/data-sync.yml", event: "schedule", head_branch: "main", head_sha: OLD, created_at: "2026-11-08T01:00:00Z", updated_at: "2026-11-08T01:02:00Z",
  repository: { full_name: "modelplan/modelplan" }, head_repository: { full_name: "modelplan/modelplan" }, ...over });
const syncCommit = (over = {}) => ({ sha: H, author: BOT, parents: [{ sha: OLD }], ...over });
// The dispatched checks data-sync.yml starts on the branch: same repository, no PR list, the PR's branch.
const syncChecks = (...paths) => (paths.length ? paths : [".github/workflows/ci.yml", ".github/workflows/repo-checks.yml"])
  .map((path, i) => run(path, "success", i + 1, "completed", { event: "workflow_dispatch", head_branch: `data/sync-0.5.21-${RUN_ID}`, pull_requests: [] }));
const evalSync = ({ p = syncPr(), files = [file("data/manifest.json"), file("data/plans.json")], comments = [comment(v("merge", H, ""))], run = syncRun(), commit = syncCommit(), runs = syncChecks() } = {}) =>
  R.evaluatePr({ pr: p, items: R.feed(comments), files, runs, statuses: [], verifiedEdge: () => false, conf, sync: { run, commit } });

test("data-sync: a bot PR from a data-sync.yml run with a trusted exact-head verdict passes without a ci.yml run", () => {
  const r = evalSync();
  assert.equal(r.state, R.SUCCESS, r.why);
  assert.equal(evalSync({ run: syncRun({ event: "workflow_dispatch" }) }).state, R.SUCCESS);
});

test("data-sync: ci.yml and repo-checks.yml stay required; dispatched runs on the branch count, a fork's or another branch's do not", () => {
  assert.equal(evalSync({ runs: [] }).state, R.PENDING, "no checks yet");
  assert.equal(evalSync({ runs: syncChecks(".github/workflows/ci.yml") }).state, R.PENDING, "repo-checks missing");
  assert.equal(evalSync({ runs: syncChecks(".github/workflows/repo-checks.yml") }).state, R.PENDING, "ci.yml missing");
  const [ci, rc] = syncChecks();
  assert.equal(evalSync({ runs: [{ ...ci, head_repository: { full_name: "evil/modelplan" } }, rc] }).state, R.PENDING, "fork run ignored");
  assert.equal(evalSync({ runs: [{ ...ci, head_branch: "main" }, rc] }).state, R.PENDING, "other branch ignored");
  assert.equal(evalSync({ runs: [{ ...ci, status: "in_progress", conclusion: null }, rc] }).state, R.PENDING);
  assert.equal(evalSync({ runs: [ci, { ...rc, conclusion: "failure" }] }).state, R.FAILURE);
});

test("data-sync: the run is bound to the PR (parent = run head, PR opened during the run) and the file list is not truncated", () => {
  assert.equal(evalSync({ commit: syncCommit({ parents: [{ sha: "d".repeat(40) }] }) }).state, R.FAILURE, "parent is not the run's checkout");
  assert.equal(evalSync({ run: syncRun({ head_sha: undefined }) }).state, R.FAILURE);
  assert.equal(evalSync({ run: syncRun({ updated_at: "2026-11-08T01:00:03Z" }) }).state, R.FAILURE, "PR opened after the run ended");
  assert.equal(evalSync({ run: syncRun({ created_at: "2026-11-08T01:00:10Z", updated_at: "2026-11-08T01:09:00Z" }) }).state, R.FAILURE, "PR opened before the run started");
  assert.equal(evalSync({ files: Array.from({ length: R.FILE_LIST_LIMIT }, (_, i) => file(`data/f${i}.json`)) }).state, R.FAILURE, "file list at the API cap");
  assert.equal(evalSync({ files: Array.from({ length: R.FILE_LIST_LIMIT - 1 }, (_, i) => file(`data/f${i}.json`)) }).state, R.SUCCESS);
});

test("data-sync: a failing run or status on the head still fails; a block still blocks", () => {
  assert.equal(evalSync({ runs: [...syncChecks(), run(".github/workflows/u6-engine-store-core.yml", "failure", 9, "completed", { head_branch: `data/sync-0.5.21-${RUN_ID}`, pull_requests: [] })] }).state, R.FAILURE);
  assert.equal(evalSync({ comments: [comment(v("merge", H, "")), comment(v("block", H, "glm"))] }).state, R.FAILURE);
});

test("data-sync: a file outside data/ fails, including a rename from outside", () => {
  assert.equal(evalSync({ files: [file("data/a.json"), file("scripts/data-sync.mjs")] }).state, R.FAILURE);
  assert.equal(evalSync({ files: [file("data/a.json", { previous_filename: "cli/main.go" })] }).state, R.FAILURE);
  assert.equal(evalSync({ files: [file("data/../cli/main.go")] }).state, R.FAILURE);
  assert.equal(evalSync({ files: [file("database/a.json")] }).state, R.FAILURE);
  assert.equal(evalSync({ files: [] }).state, R.FAILURE);
});

test("data-sync: a fork fails", () => {
  const fork = { sha: H, ref: `data/sync-0.5.21-${RUN_ID}`, repo: { full_name: "evil/modelplan" } };
  assert.equal(evalSync({ p: syncPr({ head: fork }) }).state, R.FAILURE);
  assert.equal(evalSync({ run: syncRun({ head_repository: { full_name: "evil/modelplan" } }) }).state, R.FAILURE);
  assert.equal(evalSync({ p: syncPr({ base: { ref: "main", repo: { full_name: "evil/modelplan" } } }) }).state, R.FAILURE);
});

test("data-sync: a wrong branch name or a run that is not this PR's data-sync run fails", () => {
  const branch = (ref) => ({ sha: H, ref, repo: { full_name: "modelplan/modelplan" } });
  for (const ref of ["data/other-0.5.21-4242", "feature/data/sync-0.5.21-4242", "data/sync-0.5.21", "data/sync-0.5.21-4242x", "claude/x"])
    assert.equal(evalSync({ p: syncPr({ head: branch(ref) }) }).state, R.FAILURE, ref);
  assert.equal(evalSync({ run: syncRun({ id: 1 }) }).state, R.FAILURE, "run id differs from the branch");
  assert.equal(evalSync({ run: syncRun({ path: ".github/workflows/ci.yml" }) }).state, R.FAILURE);
  assert.equal(evalSync({ run: syncRun({ event: "pull_request" }) }).state, R.FAILURE);
  assert.equal(evalSync({ run: syncRun({ head_branch: "feature/x" }) }).state, R.FAILURE);
  assert.equal(evalSync({ run: syncRun({ created_at: "2026-11-08T02:00:00Z" }) }).state, R.FAILURE, "run after the PR");
  assert.equal(evalSync({ run: null }).state, R.FAILURE);
});

test("data-sync: a missing, stale, foreign or non-merge VERDICT fails", () => {
  assert.equal(evalSync({ comments: [] }).state, R.FAILURE);
  assert.equal(evalSync({ comments: [comment(v("merge", OLD, ""))] }).state, R.FAILURE, "stale head");
  assert.equal(evalSync({ comments: [comment(v("merge", H, ""), { login: "someone", id: 5 })] }).state, R.FAILURE, "not trusted");
  assert.equal(evalSync({ comments: [comment(v("merge", H, ""), BOT)] }).state, R.FAILURE, "the bot cannot approve itself");
  assert.equal(evalSync({ comments: [comment(`REVIEW-TIER: 0`)] }).state, R.FAILURE, "tier override is not a verdict");
});

test("data-sync: an author other than the bot or guanbear fails, and a bot lookalike fails", () => {
  for (const user of [{ login: "someone", id: 5 }, { login: "github-actions[bot]", id: 1 }, { login: "github-actions", id: 41898282 }, { login: "dependabot[bot]", id: 49699333 }])
    assert.equal(evalSync({ p: syncPr({ user }) }).state, R.FAILURE, user.login);
  assert.equal(evalSync({ commit: syncCommit({ author: { login: "someone", id: 5 } }) }).state, R.FAILURE, "head commit author");
  assert.equal(evalSync({ commit: syncCommit({ author: ME }) }).state, R.FAILURE, "head commit by guanbear on a bot PR");
  assert.equal(evalSync({ commit: syncCommit({ sha: OLD }) }).state, R.FAILURE, "commit is not the head");
  assert.equal(evalSync({ commit: syncCommit({ parents: [{}, {}] }) }).state, R.FAILURE, "merge commit");
  assert.equal(evalSync({ commit: null }).state, R.FAILURE);
});

test("data-sync: guanbear's own PR and any other PR keep today's rules", () => {
  assert.equal(evalPr({ files: [file("data/a.json")], comments: [comment(v("merge"))], runs: [] }).state, R.PENDING, "guanbear PR still needs ci.yml");
  const r = evalPr({ p: pr({ user: { login: "someone", id: 5 } }) });
  assert.equal(r.state, R.FAILURE);
  assert.match(r.why, /not a trusted same-repository PR/);
  assert.equal(R.dataSyncRunId(pr({ user: { login: "someone", id: 5 }, head: { sha: H, ref: "data/sync-1-2", repo: { full_name: "modelplan/modelplan" } } })), null);
});

test("an action_required run never ran: it is skipped when picking the latest run, so it cannot fail or pass a head", () => {
  const held = (path, id) => run(path, "action_required", id, "completed", { head_branch: `data/sync-0.5.21-${RUN_ID}` });
  const checks = syncChecks();
  // A data-sync PR: newer pull_request runs held for approval next to the executed dispatched runs.
  const r = evalSync({ runs: [...checks, held(".github/workflows/ci.yml", 50), held(".github/workflows/repo-checks.yml", 51)] });
  assert.equal(r.state, R.SUCCESS, r.why);
  // Only held runs: nothing executed, so pending, never success.
  const only = evalSync({ runs: [held(".github/workflows/ci.yml", 50), held(".github/workflows/repo-checks.yml", 51)] });
  assert.equal(only.state, R.PENDING, only.why);
  assert.equal(evalPr({ comments: [comment(v("merge"))], runs: [run(".github/workflows/ci.yml", "action_required", 5)] }).state, R.PENDING, "ordinary PR too");
  // A held run newer than an executed failure does not hide the failure.
  const failed = evalSync({ runs: [{ ...checks[0], conclusion: "failure", id: 3 }, checks[1], held(".github/workflows/ci.yml", 60)] });
  assert.equal(failed.state, R.FAILURE, failed.why);
  assert.equal(R.ciState([run(".github/workflows/ci.yml", "failure", 3), run(".github/workflows/ci.yml", "action_required", 9)]).state, R.FAILURE);
  assert.equal(R.ciState([run(".github/workflows/ci.yml", "success", 3), run(".github/workflows/ci.yml", "action_required", 9)]).state, R.SUCCESS);
});
