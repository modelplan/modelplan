// SPDX-License-Identifier: MIT
import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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
const run = (path, conclusion = "success", id = 1, status = "completed") => ({ id, workflow_id: path, path, name: path.split("/").pop(), status, conclusion });
const greenCi = [run(".github/workflows/ci.yml")];
const pr = (over = {}) => ({
  state: "open", draft: false, user: ME,
  head: { sha: H, repo: { full_name: "modelplan/modelplan" } },
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
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "sonnet")), comment(v("merge", H, "glm"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ files: [file("docs/a.md")] }).state, R.SUCCESS, "tier 0 needs no verdict");
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment(v("block"))] }).state, R.FAILURE);
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment("REVIEW-TIER: 1")] }).state, R.PENDING);
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
  const step = (n, result) => ({pr:n, prResult:result, mergeProof:{ok:true}, overlap:[]});
  const queueRuns = [run(".github/workflows/ci.yml")];
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, absent)], queueRuns}).state, R.FAILURE);
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, valid)], queueRuns}).state, R.SUCCESS);
});

test("malformed scenario members fail PR and merge group despite valid evidence", () => {
  const docs = [file("docs/evidence.md")];
  const receipt = comment(`VERIFIED: V-01 @ ${H} evidence=fixture`);
  for (const invalid of ["S6", "d-01", "V-1", "V-001"]) {
    const result = evalPr({ p: pr({title:"G3-07", body:`Scenarios: V-01, ${invalid}`}), files:docs, comments:[receipt] });
    assert.equal(result.state, R.FAILURE, invalid);
    assert.equal(R.evaluateGroup({steps:[{pr:1, prResult:result, mergeProof:{ok:true}, overlap:[]}], queueRuns:greenCi}).state, R.FAILURE, invalid);
  }
  const valid = evalPr({p:pr({title:"G3-07", body:"Scenarios: V-01 (normal entry), V-01"}), files:docs, comments:[receipt]});
  assert.equal(valid.state, R.SUCCESS);
});

test("stale-base guard and merge-group evaluation", () => {
  assert.deepEqual(R.staleOverlap(["desktop/native/A.swift", "docs/x.md"], ["desktop/native/B.swift", "docs/y.md", "cli/z.go"]), ["desktop/native"]);
  assert.deepEqual(R.staleOverlap(["cli/a.go"], ["desktop/native/B.swift"]), []);
  // Module granularity (owner 2026-11-06): a desktop/native/<Package> path compares by its first
  // five segments, so an unrelated native module on the base is not an overlap...
  const mine = ["desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/App.swift"];
  assert.deepEqual(R.staleOverlap(mine, ["desktop/native/ModelPlanEngineStore/Sources/ModelPlanEngineStore/Store.swift"]), []);
  // ...while the same five-segment module still is.
  assert.deepEqual(R.staleOverlap(mine, ["desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/Other.swift"]),
    ["desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration"]);
  // Shorter desktop/native paths: a package-root file is its package token (a module PR does not
  // overlap it); files directly under desktop/native stay at tree level, like the legacy rule.
  assert.deepEqual(R.staleOverlap(["desktop/native/ModelPlanAppIntegration/README.md"], ["desktop/native/ModelPlanAppIntegration/Other.md"]),
    ["desktop/native/ModelPlanAppIntegration"]);
  assert.deepEqual(R.staleOverlap(mine, ["desktop/native/ModelPlanAppIntegration/README.md"]), []);
  assert.deepEqual(R.staleOverlap(["desktop/native/A.swift"], ["desktop/native/B.swift"]), ["desktop/native"]);
  // A base workflow change overlaps only when the PR itself changes a workflow file.
  assert.deepEqual(R.staleOverlap(mine, [".github/workflows/desktop.yml"]), []);
  assert.deepEqual(R.staleOverlap([mine[0], ".github/workflows/u11-native.yml"], [".github/workflows/desktop.yml"]), [".github/workflows"]);
  const ok = { state: R.SUCCESS, why: "ok" };
  const step = (o = {}) => ({ pr: 7, prResult: ok, mergeProof: { ok: true }, overlap: [], ...o });
  const qci = [run(".github/workflows/ci.yml")];
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: qci }).state, R.SUCCESS);
  assert.equal(R.evaluateGroup({ steps: [], queueRuns: qci }).state, R.FAILURE);
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [] }).state, R.PENDING, "queue CI not started yet");
  assert.equal(R.evaluateGroup({ steps: [step(), step({ pr: 8, prResult: { state: R.PENDING, why: "x" } })], queueRuns: qci }).state, R.FAILURE, "an unready PR fails the group");
  assert.equal(R.evaluateGroup({ steps: [step({ overlap: ["desktop/native"] })], queueRuns: qci }).state, R.FAILURE);
  assert.equal(R.evaluateGroup({ steps: [step({ mergeProof: { ok: false, why: "x" } })], queueRuns: qci }).state, R.FAILURE);
  assert.equal(R.evaluateGroup({ steps: [step()], queueRuns: [run(".github/workflows/ci.yml", "failure")] }).state, R.FAILURE);
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

test("shipped files: design rules parse, gate workflows pass the workflow policy", () => {
  assert.ok(conf.include.some((r) => r.surface === "dock") && conf.exclude.length >= 4 && conf.pinonly.length === 1);
  for (const f of ["merge-gates.yml", "merge-gates-probe.yml", "ci.yml"]) {
    const path = `.github/workflows/${f}`;
    assert.deepEqual(workflowProblems(readFileSync(join(root, path), "utf8"), path), [], path);
  }
  for (const path of [...R.QUEUE_WORKFLOWS, ".github/workflows/merge-gates-probe.yml"]) {
    assert.match(readFileSync(join(root, path), "utf8"), /^  merge_group:\s*$/m, `${path} must run for queue groups`);
  }
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
});
