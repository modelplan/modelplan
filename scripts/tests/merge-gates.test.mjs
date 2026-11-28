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
// D374: a native head also needs the mac-compile success status; the default statuses carry it so unrelated tests stay green.
const compileOk = { context: "mac-compile", state: "success" };
const evalPr = ({ comments = [], reviews = [], files = [file("scripts/tool.mjs")], runs = greenCi, statuses = [compileOk], verified = () => false, prove, p = pr() } = {}) =>
  R.evaluatePr({ pr: p, items: R.feed(comments, reviews), files, runs, statuses, verifiedEdge: verified, proveMainMerges: prove, conf });
const evalPrBase = (o) => evalPr(o);
// D243 (owner 2026-11-13): scenario evidence, Scenarios lines, trains, GLMREV, DESIGN and non-GPT verdict blocks are
// advisory. They never change the PR state; the status description names them after "info:". advisory() reads the
// evidence part back out of a result: PENDING when the description reports missing or unreadable evidence.
const advisory = (r) => /info: .*(evidence pending|Scenarios line|train Scenarios)/.test(r.why) ? R.PENDING : R.SUCCESS;
// The advisory GLMREV or DESIGN result the description reports: SUCCESS for ok/pass, FAILURE for issues/fail,
// PENDING when the marker is absent. The PR itself must pass regardless.
const marker = (r, kind) => {
  assert.equal(r.state, R.SUCCESS, `${kind} never decides the PR (D243)`);
  const m = new RegExp(`info: .*${kind} (ok|pass|issues|fail)`).exec(r.why);
  return !m ? R.PENDING : m[1] === "ok" || m[1] === "pass" ? R.SUCCESS : R.FAILURE;
};
const v = (verdict, sha = H, lane = "macrev") => `Review\n\nVERDICT: ${verdict} @ ${sha}${lane ? ` (${lane})` : ""}`;

test("trust needs the login and the numeric id; deleted authors and drafts never count", () => {
  assert.ok(R.isTrusted(ME));
  assert.ok(!R.isTrusted({ login: "guanbear", id: 1 }));
  assert.ok(!R.isTrusted({ login: "someone", id: 11829005 }));
  assert.ok(!R.isTrusted(null));
  const items = R.feed([comment("x", null), comment("y", { login: "x", id: 2 }), comment("z")], [{ user: ME, body: "draft" }]);
  assert.deepEqual(items.map((x) => x.body), ["z"]);
});

test("D395 stateless landing: a REVIEWER assignment never changes what lands; any counting block at the head blocks", () => {
  const t2 = [file("cli/internal/quota/x.go")];
  const rv = (lane) => `REVIEWER: ${lane}`;
  const mixed = [comment(v("block", H, "macrev2")), comment(v("block", H, "macrevb")), comment(v("merge", H, "macrevd"))];
  assert.equal(evalPr({ files: t2, comments: mixed }).state, R.FAILURE, "any block stops it");
  assert.equal(evalPr({ files: t2, comments: [comment(rv("macrevd")), ...mixed] }).state, R.FAILURE, "an assignment hides no block");
  assert.equal(evalPr({ files: t2, comments: [comment(rv("macrevd")), comment(v("merge", H, "macrev2"))] }).state, R.SUCCESS, "any Sol lane's merge lands, whoever is assigned");
  assert.equal(evalPr({ files: t2, comments: [comment(rv("nosuchlane")), comment(v("merge", H, "macrevd"))] }).state, R.SUCCESS, "an invalid assignment holds nothing");
  assert.equal(evalPr({ files: t2, comments: [comment(rv("macrevc")), comment(v("merge", H, "macrevc"))] }).state, R.PENDING, "Terra never admits tier 2");
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment(rv("sonnet")), comment(v("block", H, "macrev2"))] }).state, R.FAILURE, "a GPT block stops tier 0");
  assert.equal(evalPr({ files: [file("docs/a.md")], comments: [comment(rv("sonnet"))] }).state, R.SUCCESS, "tier 0 needs no verdict, whatever is assigned");
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

test("tier gates: tier 1 needs a GPT merge, tier 2 needs a Sol lane, macrev is advice on tier 2, GPT blocks stop every tier", () => {
  assert.equal(evalPr({ comments: [comment(v("merge"))] }).state, R.SUCCESS);
  assert.equal(evalPr().state, R.PENDING);
  const t2 = [file("clients/swift/Wire.swift")];
  const glm = comment(`GLMREV: OK @ ${H}`);
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrev")), glm] }).state, R.PENDING);
  assert.equal(evalPr({ files: t2, comments: [comment(v("block", H, "macrev")), comment(v("merge", H, "macrev2")), glm] }).state, R.FAILURE, "D395 stateless: a Terra block blocks tier 2 too");
  // D243: one review gate. A GLM or (sonnet) block is reviewer input, shown in the description, never a FAILURE.
  const glmBlock = evalPr({ files: t2, comments: [comment(v("merge", H, "macrev2")), comment(v("block", H, "glm")), glm] });
  assert.equal(glmBlock.state, R.SUCCESS);
  assert.match(glmBlock.why, /info: .*\(glm\) block/);
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "sonnet")), glm] }).state, R.PENDING, "tier 2: sonnet never counts");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "sonnet"))] }).state, R.PENDING, "tier 1: sonnet never counts");
  assert.equal(evalPr({ files: t2, comments: [comment(v("block", H, "sonnet")), comment(v("merge", H, "macrev2")), glm] }).state, R.SUCCESS, "a sonnet block is input");
  assert.equal(evalPr({ files: t2, comments: [comment(v("block", H, "macrevb")), comment(v("merge", H, "macrev2"))] }).state, R.FAILURE, "a Sol block at the head stops it");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "macrevc")), comment(v("block", H, ""))] }).state, R.FAILURE, "an unnamed block stops it");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "macrevc")), comment(v("block", OLD, "macrev2"))] }).state, R.SUCCESS, "a block at another head is not outstanding");
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrevd"))] }).state, R.SUCCESS, "tier 2 macrevd (third Sol lane); no GLMREV needed");
  // Owner D149: a GPT reviewer lane is required; sonnet never counts in the public gate
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrevb")), glm] }).state, R.SUCCESS, "tier 2 macrevb");
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrev2")), glm] }).state, R.SUCCESS, "tier 2 macrev2");
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "macrevc")), glm] }).state, R.PENDING, "tier 2 macrevc is Terra");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "glm"))] }).state, R.PENDING, "tier 1 GLM-only");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "macrevc"))] }).state, R.SUCCESS, "tier 1 macrevc");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "macrev2"))] }).state, R.SUCCESS, "tier 1 Sol");
});

test("R13/D482: a PR with a Ledger: G3-nn line is IMPORTANT (at least tier 1), so only a Sol lane lands it", () => {
  const body = "Ledger: G3-65\nScenarios: V-01";
  const ledger = pr({ body });
  assert.ok(R.ledgerPr(ledger));
  assert.ok(R.ledgerPr(pr({ body: "Summary\n\n- Ledger: G3-26, G3-27 (fix)\nScenarios: none" })));
  assert.ok(!R.ledgerPr(pr({ body: "Scenarios: none" })));
  assert.ok(!R.ledgerPr(pr({ body: "Ledger: none\nSee G3-65 elsewhere" })), "only the Ledger line counts");
  const glm = comment(`GLMREV: OK @ ${H}`);
  const av = comment(`AUTO-VERIFIED: V-01 @ ${H} gates=ci,gui,review`);
  const e = (comments, p) => evalPr({ p, files: [file("scripts/tool.mjs")], comments: [...comments, glm, av] });
  assert.equal(R.pathTier(["scripts/tool.mjs"]), 1, "the files alone are tier 1");
  assert.equal(e([comment(v("merge", H, "macrevc"))], ledger).state, R.PENDING, "Terra alone is not enough");
  assert.equal(e([comment(v("merge", H, "macrevc"))], ledger).tier, 1, "D482: no tier-2 floor; the class carries R13");
  assert.equal(e([comment(v("merge", H, "macrevc"))], ledger).review, R.IMPORTANT);
  assert.equal(e([comment(v("merge", H, "ghglm"))], ledger).state, R.PENDING, "D482: GLM alone is not enough either");
  assert.equal(R.evaluatePr({ pr: ledger, items: R.feed([comment(v("merge", H, "ghglm")), glm, av]), files: [file("scripts/tool.mjs")], runs: greenCi, statuses: [compileOk], verifiedEdge: () => false, conf, glmTiers: [1, 2] }).state, R.PENDING, "D482: REVIEW_GLM_TIERS does not widen it");
  const docsLedger = R.evaluatePr({ pr: ledger, items: R.feed([glm, av]), files: [file("docs/a.md")], runs: greenCi, statuses: [compileOk], verifiedEdge: () => false, conf });
  assert.equal(docsLedger.tier, 1, "a docs-only ledger PR is tier 1 (ledgerMinTier)"); assert.equal(docsLedger.state, R.PENDING);
  assert.equal(e([comment(v("merge", H, "macrev2"))], ledger).state, R.SUCCESS, "Sol lands it");
  assert.equal(e([comment(v("merge", H, "macrevb"))], ledger).state, R.SUCCESS);
  assert.equal(e([comment("REVIEW-TIER: 0"), comment(v("merge", H, "macrevc"))], ledger).state, R.PENDING, "an override cannot lower it below tier 1 or make it normal");
  assert.equal(e([comment(v("merge", H, "macrevc"))], pr({ body: "Scenarios: none" })).state, R.SUCCESS, "a non-ledger PR stays tier 1");
});

test("workflow reviewer (gh-terra pilot): a Terra lane; its shadow name and other hyphenated names count for nothing", () => {
  assert.ok(R.TERRA_LANES.includes("(gh-terra)"));
  assert.ok(!R.SOL_LANES.includes("(gh-terra)"));
  assert.deepEqual([...R.verdicts(R.feed([comment(v("merge", H, "gh-terra"))]), H, [])], [["(gh-terra)", "merge"]]);
  assert.deepEqual([...R.verdicts(R.feed([comment(v("block", H, "GH-Terra-Shadow"))]), H, [])], [["(gh-terra-shadow)", "block"]]);
  for (const odd of ["gh-", "-gh", "gh--terra", "gh_terra", "gh terra"])
    assert.deepEqual([...R.verdicts(R.feed([comment(v("merge", H, odd))]), H, [])], [["(unnamed)", "merge"]], odd);
  const t2 = [file("clients/swift/Wire.swift")];
  assert.equal(evalPr({ comments: [comment(v("merge", H, "gh-terra"))] }).state, R.SUCCESS, "tier 1 gh-terra");
  assert.equal(evalPr({ comments: [comment(v("block", H, "gh-terra")), comment(v("merge", H, "macrevc"))] }).state, R.FAILURE, "a gh-terra block stops tier 1");
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", H, "gh-terra"))] }).state, R.PENDING, "tier 2 needs Sol");
  const t2Block = evalPr({ files: t2, comments: [comment(v("block", H, "gh-terra")), comment(v("merge", H, "macrev2"))] });
  assert.equal(t2Block.state, R.FAILURE, "D395 stateless: any GPT block at the head blocks, Terra on tier 2 too");
  assert.equal(evalPr({ comments: [comment(v("merge", H, "gh-terra-shadow"))] }).state, R.PENDING, "shadow never counts");
  const shadow = evalPr({ comments: [comment(v("block", H, "gh-terra-shadow")), comment(v("merge", H, "macrevc"))] });
  assert.equal(shadow.state, R.SUCCESS, "a shadow block is input");
  assert.match(shadow.why, /info: .*\(gh-terra-shadow\) block/);
  assert.equal(evalPr({ comments: [comment(v("merge", H, "gh-terra"), { login: "github-actions[bot]", id: 41898282 })] }).state, R.PENDING, "only the trusted account posts verdicts");
  assert.equal(R.pathTier([".github/workflows/pr-review.yml"]), 2, "the reviewer workflow is gate-self");
  assert.equal(R.pathTier(["scripts/pr-review/brief.mjs"]), 2);
});

test("Sol workflow reviewer (ghsol, D352): a Sol lane for tiers 1 and 2 and a valid sticky REVIEWER; ghsolshadow counts for nothing", () => {
  assert.ok(R.SOL_LANES.includes("(ghsol)"));
  assert.ok(!R.TERRA_LANES.includes("(ghsol)"));
  assert.ok(!R.SOL_LANES.includes("(ghsolshadow)"));
  const t2 = [file("clients/swift/Wire.swift")];
  const rv = (lane) => comment(`REVIEWER: ${lane}`);
  // tier 1 here is an IMPORTANT path (D395: on a NORMAL PR an assignment pins nothing, see the D395-5 test)
  for (const files of [[file("scripts/refresh-tool.mjs")], t2]) {
    const tier = files === t2 ? 2 : 1;
    assert.equal(evalPr({ files, comments: [comment(v("merge", H, "ghsol"))] }).state, R.SUCCESS, `tier ${tier}: ghsol merge passes`);
    assert.equal(evalPr({ files, comments: [comment(v("block", H, "ghsol")), comment(v("merge", H, "macrev2"))] }).state, R.FAILURE, `tier ${tier}: a ghsol block stops it`);
    // D395 stateless: an assignment changes nothing; another lane's block blocks, another Sol lane's merge lands.
    const sticky = evalPr({ files, comments: [rv("ghsol"), comment(v("block", H, "macrevb")), comment(v("merge", H, "ghsol"))] });
    assert.equal(sticky.state, R.FAILURE, `tier ${tier}: another lane's block stops it whoever is assigned`);
    assert.match(sticky.why, /reviewer \(ghsol\)/);
    assert.equal(evalPr({ files, comments: [rv("(ghsol)"), comment(v("merge", H, "macrevb"))] }).state, R.SUCCESS, `tier ${tier}: any Sol lane's merge lands`);
    assert.equal(evalPr({ files, comments: [rv("ghsol"), comment(v("block", H, "ghsol")), comment(v("merge", H, "macrevb"))] }).state, R.FAILURE, `tier ${tier}: sticky ghsol block fails`);
    // Shadow: never counts, never assigns; its block is reported only.
    assert.equal(evalPr({ files, comments: [comment(v("merge", H, "ghsolshadow"))] }).state, R.PENDING, `tier ${tier}: shadow never counts`);
    const shadow = evalPr({ files, comments: [comment(v("block", H, "ghsolshadow")), comment(v("merge", H, "macrev2"))] });
    assert.equal(shadow.state, R.SUCCESS, `tier ${tier}: a shadow block is advice`);
    assert.match(shadow.why, /info: .*\(ghsolshadow\) block/);
    const badSticky = evalPr({ files, comments: [rv("ghsolshadow"), comment(v("merge", H, "ghsolshadow")), comment(v("merge", H, "macrev2"))] });
    assert.equal(badSticky.state, R.SUCCESS, `tier ${tier}: a shadow assignment holds nothing (D395 stateless); macrev2's merge lands`);
  }
  assert.equal(evalPr({ comments: [comment(v("merge", H, "ghsol"), { login: "github-actions[bot]", id: 41898282 })] }).state, R.PENDING, "only the trusted account posts verdicts");
  // The comment format the workflow posts: the record and quoted answer first, the VERDICT as the last line.
  const posted = `**Sol workflow review** (ghsol)\n\n> FOLLOW-UP F1: x\n> Record: ${H}\n> VERDICT: block\n\nVERDICT: merge @ ${H} (ghsol)`;
  assert.deepEqual([...R.verdicts(R.feed([comment(posted)]), H, [])], [["(ghsol)", "merge"]], "only the unquoted last line is read");
  // Data-sync admission honours a ghsol assignment on tier 1 and tier 2.
  assert.equal(evalSync({ comments: [comment("REVIEWER: ghsol"), comment(v("merge", H, "ghsol"))] }).state, R.SUCCESS);
  assert.equal(evalSync({ comments: [comment("REVIEW-TIER: 2"), comment("REVIEWER: ghsol"), comment(v("merge", H, "ghsol"))] }).state, R.SUCCESS);
  assert.equal(evalSync({ comments: [comment("REVIEWER: ghsol"), comment(v("merge", H, "macrev2"))] }).state, R.FAILURE, "another lane's merge does not admit");
  assert.equal(R.pathTier([".github/workflows/pr-review-sol.yml"]), 2, "the Sol reviewer workflow is gate-self");
  assert.equal(R.pathTier(["scripts/pr-review/sol.mjs"]), 2);
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
  // R13: a ledger PR is tier 2, so every case below also carries the Sol verdict and the GLM review it now needs.
  const evalPr = (o) => evalPrBase({ ...o, comments: [...(o.comments ?? []), comment(v("merge", H, "macrev2")), comment(`GLMREV: OK @ ${H}`)] });
  const ledger = (body) => pr({ title: "Fix G3-07", body: `Ledger: G3-07\n${body}` });
  const av = (ids, sha = H, gates = "ci,gui,review") => `AUTO-VERIFIED: ${ids} @ ${sha} gates=${gates}`;
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, comments: [comment(`${av("V-01, V-02")}\n\nchecked`)] }).state, R.SUCCESS);
  assert.equal(evalPr({ p: ledger("Scenarios: G3-07, V-01, V-02"), files: docs, comments: [comment(av("G3-07 V-01 V-02"))] }).state, R.SUCCESS, "G3 row and space-separated IDs");
  assert.equal(evalPr({ p: ledger("Scenarios: G3-107, V-01"), files: docs, comments: [comment(av("G3-107, V-01"))] }).state, R.SUCCESS, "three-digit G3 row");
  assert.equal(evalPr({ p: ledger("Scenarios: G3-107"), files: docs, comments: [comment(`VERIFIED: G3-107 @ ${H} evidence=/x/y`)] }).state, R.SUCCESS, "three-digit VERIFIED line");
  assert.equal(evalPr({ p: ledger("Scenarios: G3-107"), files: docs, comments: [comment(`EVIDENCE-DEFERRED: G3-107 @ ${H} issue=470`)] }).state, R.SUCCESS, "three-digit deferral");
  for (const gates of R.AUTO_VERIFIED_GATES)
    assert.equal(evalPr({ p: ledger("Scenarios: V-01"), files: docs, comments: [comment(av("V-01", H, gates))] }).state, R.SUCCESS, gates);
  // Mixed with a coordinator VERIFIED line and a #470 deferral.
  assert.equal(evalPr({ p: ledger("Scenarios: V-01, V-02, V-03"), files: docs, comments: [comment(av("V-01")), comment(`VERIFIED: V-02 @ ${H} evidence=/x/y`), comment(`EVIDENCE-DEFERRED: V-03 @ ${H} issue=470`)] }).state, R.SUCCESS);
  // A Scenarios line without a ledger row (real-Mac tier) is cleared the same way.
  assert.equal(evalPr({ p: pr({ title: "Ordinary", body: "Scenarios: C-10" }), files: docs, comments: [comment(av("C-10"))] }).state, R.SUCCESS);

  // D243: missing evidence is advisory; the PR passes and the description reports it.
  const pending = (comments, why, p = ledger("Scenarios: V-01, V-02")) => {
    const r = evalPr({ p, files: docs, comments });
    assert.equal(r.state, R.SUCCESS, why);
    assert.equal(advisory(r), R.PENDING, why);
    return r;
  };
  pending([comment(av("V-01, V-02", OLD))], "old head");
  assert.match(pending([comment(av("V-01, V-02"))], "a new head invalidates it", pr({ title: "Fix G3-07", body: "Scenarios: V-01, V-02", head: { sha: OLD, ref: "feature/x", repo: { full_name: "modelplan/modelplan" } } })).why, /V-01, V-02/);
  pending([comment(av("V-01, V-02"), { login: "mallory", id: 1 })], "untrusted login");
  pending([comment(av("V-01, V-02"), { login: "guanbear", id: 1 })], "recycled login");
  pending([comment(`notes first\n${av("V-01, V-02")}`)], "not the first line");
  assert.equal(advisory(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, reviews: [review(av("V-01, V-02"))] })), R.PENDING, "a review is not a comment");
  pending([comment(` ${av("V-01, V-02")}`)], "leading space");
  for (const gates of ["ci,review", "gui,review", "ci,gui", "review,gui,ci", "ci,gui,review,visual,design", "ci,gui,review,", "ci,gui,review,extra", "ci,gui,review,walkthrough", ""])
    pending([comment(av("V-01, V-02", H, gates))], `gates=${gates}`);
  pending([comment(av("V-01, V-02", H.slice(0, 12), "ci,gui,review,design,visual"))], "short sha");
  pending([comment(av("V-01, V-02", H.toUpperCase()))], "upper-case sha");
  pending([comment(`${av("V-01, V-02")} trailing`)], "trailing text");
  pending([comment(av("V-01, v-02"))], "malformed ID");
  assert.equal(advisory(evalPr({ p: ledger("Scenarios: V-01, V-02"), files: docs, comments: [comment(av("V-01, V-02", OLD)), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true })), R.PENDING, "never carried");
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

// D243 G6 (owner 2026-11-14): a merge VERDICT carries across main merges without a VERDICT-CARRY comment.
const MID = "d".repeat(40);
const proved = (between = [H]) => (o, n) => ({ ok: true, why: "main merges only, diff unchanged", between });
const unproved = () => ({ ok: false, why: "the PR's own diff changed", between: [] });

test("auto-carry: a merge VERDICT carries over a proven clean main merge and says so in the description", () => {
  const seen = [];
  const r = evalPr({ comments: [comment(v("merge", OLD, "macrevc"))], prove: (o, n) => { seen.push([o, n]); return proved()(o, n); } });
  assert.deepEqual(seen, [[OLD, H]], "the reviewed head is proved against the current head");
  assert.equal(r.state, R.SUCCESS);
  assert.match(r.why, /^tier 1: gates pass; verdict carried from bbbbbbbb \(main merges only, diff unchanged\)/);
  assert.equal(r.autoCarried, OLD);
  assert.ok(R.description(r.why).includes("verdict carried from bbbbbbbb (main merges only, diff unchanged)"));
  // Waiting for CI after a carry still names the carry.
  const waiting = evalPr({ comments: [comment(v("merge", OLD, "macrevc"))], prove: proved(), runs: [run(".github/workflows/ci.yml", null, 1, "in_progress")] });
  assert.equal(waiting.state, R.PENDING);
  assert.match(waiting.why, /verdict carried from bbbbbbbb/);
  // Two main merges in a row carry the same way.
  assert.equal(evalPr({ comments: [comment(v("merge", OLD, "macrevc"))], prove: proved([H, MID]) }).state, R.SUCCESS);
});

test("auto-carry: no carry when the proof fails (own hunks changed, a non-merge commit, not on main)", () => {
  const r = evalPr({ comments: [comment(v("merge", OLD, "macrevc"))], prove: unproved });
  assert.equal(r.state, R.PENDING);
  assert.doesNotMatch(r.why, /carried/);
  assert.equal(evalPr({ comments: [comment(v("merge", OLD, "macrevc"))] }).state, R.PENDING, "no proof function, no carry");
});

test("auto-carry: no carry after a VERDICT at a later head, and a carried block still blocks", () => {
  // A review posted at a head after the reviewed one (here a block at MID) stops the carry from OLD.
  const later = [comment(v("merge", OLD, "macrevc")), comment(v("block", MID, "macrevc"))];
  assert.equal(evalPr({ comments: later, prove: proved([H, MID]) }).state, R.PENDING);
  // Only the newest reviewed head is a candidate: an older merge never skips over a newer review.
  const seen = [];
  evalPr({ comments: later, prove: (o, n) => { seen.push(o); return proved([H, MID])(o, n); } });
  assert.deepEqual(seen, [MID]);
  assert.equal(evalPr({ comments: later, prove: (o) => (o === MID ? unproved() : proved([H, MID])()) }).state, R.PENDING, "no fallback to OLD");
  // A block at the reviewed head carries with it.
  const blocked = evalPr({ comments: [comment(v("merge", OLD, "macrevc")), comment(v("block", OLD, "macrevc"))], prove: proved() });
  assert.equal(blocked.state, R.FAILURE);
  assert.match(blocked.why, /VERDICT block \(macrevc\)/);
  // A fresh verdict at the current head still counts alongside a carried one.
  assert.equal(evalPr({ comments: [comment(v("merge", OLD, "macrevc")), comment(v("block", H, "macrev2"))], prove: proved() }).state, R.FAILURE);
});

test("auto-carry: tier rules apply to the carried verdict; tier 2 needs a Sol lane", () => {
  const t2 = [file("clients/swift/Wire.swift")];
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", OLD, "macrevc"))], prove: proved() }).state, R.PENDING, "Terra is advice on tier 2");
  assert.equal(evalPr({ files: t2, comments: [comment(v("merge", OLD, "glm"))], prove: proved() }).state, R.PENDING, "GLM never counts");
  for (const lane of ["macrev2", "macrevb", "macrevd"]) {
    const r = evalPr({ files: t2, comments: [comment(v("merge", OLD, lane))], prove: proved() });
    assert.equal(r.state, R.SUCCESS, lane);
    assert.match(r.why, /^tier 2: gates pass; verdict carried from bbbbbbbb/);
  }
});

test("design marker: paths, pin-only bundle updates, DESIGN lines only in design-conformance reviews (advisory, D243)", () => {
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
  assert.equal(marker(evalPr({ files, comments: [merge, glm] }), "DESIGN"), R.PENDING);
  assert.equal(marker(evalPr({ files, comments: [merge, glm, comment(`Tier review\nDESIGN: pass @ ${H}`)] }), "DESIGN"), R.PENDING, "stray DESIGN line");
  assert.equal(marker(evalPr({ files, comments: [merge, glm], reviews: [review(`Design-conformance review (GLM)\nDESIGN: pass @ ${H}`)] }), "DESIGN"), R.SUCCESS);
  assert.equal(marker(evalPr({ files, comments: [merge, glm, comment(`Design-conformance review\nDESIGN: pass @ ${H}`), comment(`Design-conformance review\nDESIGN: fail @ ${H}`)] }), "DESIGN"), R.FAILURE);
  assert.equal(evalPr({ files: [file("desktop/official-visuals/dock/a.svg")], comments: [] }).state, R.SUCCESS, "tier 0 design-touching no longer waits for DESIGN");
});

test("design gate: only the pinned CLI identity file is excluded by name; other generated-looking files are reviewed", () => {
  const identity = "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityConsentCLIIdentity.generated.swift";
  assert.equal(R.designTouch([file(identity)], conf).touching, false);
  for (const other of [identity.replace("CommunityConsentCLIIdentity", "DockFace"), identity.replace(".generated.swift", ".swift"), `${identity}.swift`, identity.replace("ModelPlanAppIntegration/Sources/ModelPlanAppIntegration", "ModelPlanDock/Native")])
    assert.equal(R.designTouch([file(other)], conf).touching, true, other);
});

test("GLMREV marker: seams only, exact head, comment must start with the line, latest wins (advisory, D243)", () => {
  const files = [file("cli/main.go")];
  const merge = comment(v("merge"));
  assert.equal(marker(evalPr({ files: [file("scripts/x.mjs")], comments: [merge, comment(`GLMREV: ISSUES @ ${H}`)] }), "GLMREV"), R.PENDING, "outside GLM scope");
  assert.equal(marker(evalPr({ files, comments: [merge] }), "GLMREV"), R.PENDING, "a seam PR no longer waits for GLM");
  assert.equal(marker(evalPr({ files, comments: [merge, comment(`note\nGLMREV: OK @ ${H}`)] }), "GLMREV"), R.PENDING);
  assert.equal(marker(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${H}0`)] }), "GLMREV"), R.PENDING);
  assert.equal(marker(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${H}`), comment(`GLMREV: ISSUES @ ${H}\n1. x`)] }), "GLMREV"), R.FAILURE);
  assert.equal(marker(evalPr({ files, comments: [merge, comment(`GLMREV: ISSUES @ ${H}`), comment(`GLMREV-ACCEPTED @ ${H}`)] }), "GLMREV"), R.SUCCESS);
  assert.equal(marker(evalPr({ files, comments: [merge, comment(`GLMREV: OK @ ${OLD}`), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true }), "GLMREV"), R.PENDING, "GLMREV never carries");
  assert.equal(evalPr({ files, comments: [comment(`GLMREV: OK @ ${H}`)] }).state, R.PENDING, "GLMREV OK is not a review verdict");
});

test("GLM-out fallback: (sonnet) DESIGN/GLMREV pass only inside the window, exact head, posted before expiry; fail/ISSUES always count", () => {
  const UNTIL = "2026-11-14T12:17:50Z", until = Date.parse(UNTIL);
  const inside = Date.parse("2026-11-09T12:00:00Z"), after = until + 1000;
  const evalFb = ({ comments, files, now = inside, u = until }) => {
    const r = R.evaluatePr({ pr: pr(), items: R.feed(comments), files, runs: greenCi, statuses: [compileOk], verifiedEdge: () => false, conf, glmFallbackUntil: u, now });
    return { ...r, state: marker(r, files === seam ? "GLMREV" : "DESIGN") };
  };
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
  const ui = [file("desktop/native/ModelPlanSettings/Pane.swift")], seam = [file("cli/main.go")];
  const evalFb = ({ comments, files, verified = () => false }) => {
    const r = R.evaluatePr({ pr: pr(), items: R.feed(comments), files, runs: greenCi, statuses: [compileOk], verifiedEdge: verified, conf, glmFallbackUntil: until, now });
    return { ...r, state: marker(r, files === seam ? "GLMREV" : "DESIGN") };
  };
  const merge = comment(v("merge")), glm = comment(`GLMREV: OK @ ${H}`);
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
  const evalD = ({ comments, reviews = [], verified = () => false, u = until }) => {
    const r = R.evaluatePr({ pr: pr(), items: R.feed(comments, reviews), files: [file("desktop/native/ModelPlanSettings/Pane.swift")], runs: greenCi, statuses: [compileOk], verifiedEdge: verified, conf, glmFallbackUntil: u, now });
    return { ...r, state: marker(r, "DESIGN") };
  };
  const merge = comment(v("merge")), glm = comment(`GLMREV: OK @ ${H}`);
  const gFail = comment(`Design-conformance review (GLM) @ ${H}\nDESIGN: fail @ ${H}`);
  const sFail = comment(`Design-conformance review (sonnet) @ ${H}\nDESIGN (sonnet): fail @ ${H}`);
  const ok = evalD({ comments: [merge, glm, gFail, comment(`DESIGN-ACCEPTED @ ${H}\n\nCoordinator: out of scope.`)] });
  assert.equal(ok.state, R.SUCCESS);
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

test("D243: evidence lines are read exactly as before but only reported; G3 mentions no longer force a Scenarios line", () => {
  const docs = [file("docs/evidence.md")];
  const ledger = (body, extra = {}) => pr({ title: "Fix G3-07", body, ...extra });
  const mark = (id, sha = H) => `VERIFIED: ${id} @ ${sha} evidence=artifacts/run-1`;
  const ev = (o) => { const r = evalPr(o); assert.equal(r.state, R.SUCCESS, "evidence never blocks"); return advisory(r); };
  assert.equal(ev({ p: ledger("Details"), files: docs }), R.SUCCESS, "G13 cut: a G3 mention needs no Scenarios line");
  assert.equal(ev({ p: ledger("Scenarios: D-01, V-03"), files: docs }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01"), {login:"other", id:1})] }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01", OLD))] }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01"), files: docs, reviews: [review(mark("D-01"))] }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01, V-03"), files: docs, comments: [comment(mark("D-01")), comment(mark("V-03"))] }), R.SUCCESS);
  assert.equal(ev({ p: pr({title:"Ordinary fix", body:""}), files: docs }), R.SUCCESS);
  assert.equal(ev({ p: pr({title:"Ordinary", body:"Scenarios: D-01", head:{sha:H, ref:"fix/g3-12", repo:{full_name:"modelplan/modelplan"}}}), files: docs }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(`VERIFIED: D-01 @ ${H} evidence=`)] }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01"), files: docs, comments: [comment(mark("D-01", OLD)), comment(`VERDICT-CARRY: ${OLD} -> ${H}`)], verified: () => true }), R.PENDING);
  assert.equal(ev({ p: ledger("**Scenarios:** D-01, D-01"), files: docs, comments: [comment(mark("D-01"))] }), R.SUCCESS);
  assert.equal(ev({ p: ledger("Scenarios: D-01, V-03"), files: docs, comments: [comment(mark("D-01")), comment(mark("V-03"), {login:"guanbear",id:1})] }), R.PENDING);
  assert.equal(ev({ p: ledger("Scenarios: D-01\nScenarios: V-03"), files: docs, comments: [comment(mark("D-01"))] }), R.SUCCESS, "only the first declaration counts");
  assert.equal(ev({ p: ledger("Scenarios: d-01"), files: docs }), R.PENDING, "a malformed line is reported, not failed");
  assert.equal(ev({ p: ledger("Scenarios: G3-12, V-03"), files: docs, comments: [comment(mark("V-03"))] }), R.PENDING, "ledger scenario needs its own evidence");
  assert.equal(ev({ p: ledger("Scenarios: G3-12, V-03"), files: docs, comments: [comment(mark("G3-12")), comment(mark("V-03"))] }), R.SUCCESS, "numeric scenario prefixes match verified evidence");
});

test("D243: a merge group no longer waits for each member's evidence; the member reports it", () => {
  const docs = [file("docs/evidence.md")];
  const first = evalPr({p:pr({title:"G3-01", body:"Scenarios: D-01"}), files:docs,
    comments:[comment(`VERIFIED: D-01 @ ${H} evidence=first`)]});
  const other = pr({title:"G3-02", body:"Scenarios: D-02", head:{sha:OLD, ref:"fix/g3-02", repo:{full_name:"modelplan/modelplan"}}});
  const absent = evalPr({p:other, files:docs, comments:[comment(`VERIFIED: D-02 @ ${H} evidence=wrong-head`)]});
  const valid = evalPr({p:other, files:docs, comments:[comment(`VERIFIED: D-02 @ ${OLD} evidence=second`)]});
  const step = (n, result) => ({pr:n, prResult:result, mergeProof:{ok:true}});
  const queueRuns = greenQueue;
  assert.equal(advisory(absent), R.PENDING);
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, absent)], queueRuns}).state, R.SUCCESS);
  assert.equal(R.evaluateGroup({steps:[step(1, first), step(2, valid)], queueRuns}).state, R.SUCCESS);
});

test("D243: a malformed Scenarios line is reported, never a PR or merge-group failure", () => {
  const docs = [file("docs/evidence.md")];
  const receipt = comment(`VERIFIED: V-01 @ ${H} evidence=fixture`);
  for (const invalid of ["S6", "d-01", "V-1", "V-001"]) {
    const result = evalPr({ p: pr({title:"G3-07", body:`Scenarios: V-01, ${invalid}`}), files:docs, comments:[receipt] });
    assert.equal(result.state, R.SUCCESS, invalid);
    assert.match(result.why, /info: .*Scenarios line/, invalid);
    assert.equal(R.evaluateGroup({steps:[{pr:1, prResult:result, mergeProof:{ok:true}}], queueRuns:greenQueue}).state, R.SUCCESS, invalid);
  }
  const valid = evalPr({p:pr({title:"G3-07", body:"Scenarios: V-01 (normal entry), V-01"}), files:docs, comments:[receipt]});
  assert.equal(valid.state, R.SUCCESS);
  assert.doesNotMatch(valid.why, /info:/);
});

test("a Scenarios line reads exact-head evidence the same way; D243 reports a gap instead of holding the PR (#661)", () => {
  const docs = [file("docs/evidence.md")];
  const plain = (body) => pr({ title: "Cockpit publication", body: `Ledger: none\n${body}`, head: { sha: H, ref: "web/publication", repo: { full_name: "modelplan/modelplan" } } });
  const done = (id) => comment(`VERIFIED: ${id} @ ${H} evidence=fixture`);
  const pending = evalPr({ p: plain("Scenarios: C-09, C-10"), files: docs, comments: [done("C-09")] });
  assert.equal(pending.state, R.SUCCESS);
  assert.match(pending.why, /info: evidence pending: C-10/);
  const group = R.evaluateGroup({ steps: [{ pr: 661, prResult: pending, mergeProof: { ok: true } }], queueRuns: greenQueue });
  assert.equal(group.state, R.SUCCESS, "device evidence moved to the build gate");
  assert.equal(advisory(evalPr({ p: plain("Scenarios: C-09, C-10"), files: docs, comments: [done("C-09"), comment(`EVIDENCE-DEFERRED: C-10 @ ${H} issue=470`)] })), R.SUCCESS);
  assert.equal(advisory(evalPr({ p: plain("Scenarios: C-09"), files: docs, comments: [comment(`VERIFIED: C-09 @ ${OLD} evidence=fixture`)] })), R.PENDING, "another head proves nothing");
  assert.equal(evalPr({ p: plain("Scenarios: none"), files: docs }).state, R.SUCCESS);
  assert.equal(evalPr({ p: pr({ title: "Docs", body: "No declaration here." }), files: docs }).state, R.SUCCESS);
});

test("D21: a CI-tier scenario rides on green CI; real-Mac tiers and anything unknown are reported as missing (advisory, D243)", () => {
  const docs = [file("docs/evidence.md")];
  const tiers = R.parseTiers("# comment\nid\ttier\tneeds\nS-11\tT2\t-\nV-17\tT1P\t-\nR-01\tT0\tVF\nC-10\tT3\tCK\nD-02\tT4\tSYS\n");
  assert.deepEqual([...tiers], [["S-11", "T2"], ["V-17", "T1P"], ["R-01", "T0"], ["C-10", "T3"], ["D-02", "T4"]]);
  const plain = (line) => pr({ title: "Cockpit", body: `Ledger: none\nScenarios: ${line}` });
  const ev = (line, o = {}) => R.evaluatePr({ pr: plain(line), items: R.feed(o.comments ?? []), files: docs, runs: o.runs ?? greenCi, statuses: [], verifiedEdge: () => false, conf, tiers: o.tiers ?? tiers });

  assert.equal(advisory(ev("S-11, V-17, R-01")), R.SUCCESS, "T2 passes on green CI");
  assert.equal(ev("S-11", { runs: [run(".github/workflows/ci.yml", "failure")] }).state, R.FAILURE, "red CI stops it");
  assert.equal(ev("S-11", { runs: [run(".github/workflows/ci.yml", null, 1, "in_progress")] }).state, R.PENDING, "running CI is not green");
  const t3 = ev("S-11, C-10");
  assert.equal(t3.state, R.SUCCESS, "D243: missing evidence never holds the PR");
  assert.equal(advisory(t3), R.PENDING, "T3 still needs its line");
  assert.match(t3.why, /evidence pending: C-10$|evidence pending: C-10\b/);
  assert.doesNotMatch(t3.why, /S-11/);
  assert.equal(advisory(ev("D-02")), R.PENDING, "T4 too");
  assert.equal(advisory(ev("C-10", { comments: [comment(`EVIDENCE-DEFERRED: C-10 @ ${H} issue=470`)] })), R.SUCCESS);
  assert.equal(advisory(ev("C-10", { comments: [comment(`VERIFIED: C-10 @ ${H} evidence=fixture`)] })), R.SUCCESS);
  assert.equal(advisory(ev("Z-01")), R.PENDING, "a scenario missing from the table needs evidence");
  assert.equal(advisory(ev("G3-12")), R.PENDING, "a ledger row is not in the tier table");
  // D243 cut G13: a G3 mention in the title no longer makes every scenario need a line.
  const ledger = R.evaluatePr({ pr: pr({ title: "Fix G3-07", body: "Scenarios: S-11" }), items: [], files: docs, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, tiers });
  assert.equal(ledger.state, R.SUCCESS);
  assert.equal(advisory(ledger), R.SUCCESS);

  // Fail closed: no readable table means every scenario needs evidence.
  const missing = R.tiersFrom(() => { throw new Error("ENOENT"); });
  assert.equal(missing.size, 0);
  assert.equal(advisory(ev("S-11", { tiers: missing })), R.PENDING);
  assert.equal(advisory(ev("S-11", { tiers: R.tiersFrom(() => "not a table\n") })), R.PENDING);

  // The shipped table, and the checkout that must bring it to the gate.
  const shipped = R.tiersFrom(() => readFileSync(join(root, R.TIER_TABLE), "utf8"));
  assert.equal(shipped.get("C-10"), "T3");
  assert.ok(shipped.size > 90);
  const sparse = /sparse-checkout: \|\n((?:\s+\S+\n)+)/.exec(readFileSync(join(root, ".github/workflows/merge-gates.yml"), "utf8"))?.[1].trim().split(/\s+/) ?? [];
  assert.ok(sparse.includes("scripts/merge-gates"), "the gate's own code");
  assert.ok(sparse.includes(dirname(R.TIER_TABLE)), "cone-mode sparse checkout takes directories, so the table's directory");
});

test("Scenarios lines: spec IDs or none; requirement IDs and free text are reported as unreadable, never failed (D243)", () => {
  const docs = [file("docs/evidence.md")];
  const plain = (line) => pr({ title: "Widget setting", body: `Ledger: none\n${line}` });
  for (const line of [
    "Scenarios: SET-9-09",
    "Scenarios: SET-9 Quota Widget controls (widget side)",
    "Scenarios: LBL-2.2-01, LBL-2.2-02",
    "Scenarios: DOCK-3.1-01, D-01",
    "Scenarios: owner test build opens the cockpit from the menu bar",
    "Scenarios: D-01 and a sentence",
    "Scenarios: G3-1007",
    "Scenarios: G3-007",
    "Scenarios: none listed",
    "Scenarios: none, D-03",
    "Scenarios:",
    "Scenarios were not changed",
  ]) {
    const result = evalPr({ p: plain(line), files: docs });
    assert.equal(result.state, R.SUCCESS, line);
    assert.match(result.why, /info: .*Scenarios line/, line);
  }
  const draft = evalPr({ p: pr({ draft: true, title: "x", body: "Scenarios: SET-9-12" }), files: docs });
  assert.equal(draft.state, R.PENDING, "a draft only waits");
  assert.match(draft.why, /^draft; info: .*Scenarios line/, "and sees the note at once");
  // Forms real PRs use: notes in brackets, semicolons, bold, none with a note.
  const shapes = {
    "Scenarios: R-08, R-09 (partial evidence); V-06, V-07": ["R-08", "R-09", "V-06", "V-07"],
    "**Scenarios:** C-13 (Effort and Breakdown slice), C-05 (live locale; web slice)": ["C-05", "C-13"],
    "Scenarios: D-12 and D-24": ["D-12", "D-24"],
    "Scenarios: G3-12, V-03": ["G3-12", "V-03"],
    "Scenarios: G3-107, C-01 (three-digit ledger row)": ["C-01", "G3-107"],
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

test("train: a member scenario missing from the train's own line is reported (#650 dropped seven; advisory since D243)", () => {
  const docs = [file("docs/evidence.md")];
  const ref = (name) => ({ sha: H, ref: name, repo: { full_name: "modelplan/modelplan" } });
  const train = pr({ title: "Quota Widget train", body: "Ledger: none\nScenarios: D-01, V-02", head: ref("b/widget-train") });
  const done = [comment(`VERIFIED: D-01 @ ${H} evidence=fixture`), comment(`VERIFIED: V-02 @ ${H} evidence=fixture`)];
  const trainPr = (members, p = train) => R.evaluatePr({ pr: p, items: R.feed(done), files: docs, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, members });
  assert.equal(trainPr([{ number: 1, body: "Scenarios: D-01" }, { number: 2, body: "Scenarios: none" }, { number: 3, body: "no line" }]).state, R.SUCCESS);
  const short = trainPr([{ number: 519, body: "Scenarios: R-08, V-02" }, { number: 518, body: "Scenarios: S-01" }]);
  assert.equal(short.state, R.SUCCESS);
  assert.match(short.why, /#519: R-08/);
  assert.match(short.why, /#518: S-01/);
  const bad = trainPr([{ number: 626, body: "Scenarios: SET-9 Quota Widget controls" }]);
  assert.equal(bad.state, R.SUCCESS);
  assert.match(bad.why, /info: .*train Scenarios/, "an unreadable member line cannot be proved a subset");
  assert.match(bad.why, /#626/);
  const none = pr({ title: "Train", body: "Scenarios: none", head: ref("b/x") });
  assert.equal(advisory(trainPr([{ number: 7, body: "Scenarios: D-01" }], none)), R.PENDING);

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
  assert.deepEqual([...R.QUEUE_WORKFLOWS].sort(), [".github/workflows/ci.yml", ".github/workflows/desktop.yml", ".github/workflows/official-visuals.yml",
    ".github/workflows/transport-fuzz.yml", ".github/workflows/u11-cockpit.yml", ".github/workflows/u11a-aggregate.yml", ".github/workflows/u14-harness.yml"], "queue membership is pinned");
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

test("auto-carry proof: main merges only and an identical own diff; own-hunk changes, extra commits and side merges fail", () => {
  const r = repo();
  try {
    const lines = (n, edit = {}) => Array.from({ length: n }, (_, i) => edit[i] ?? `line ${i}`).join("\n") + "\n";
    r.put("big.txt", lines(40)); r.g("add", "big.txt"); r.g("commit", "-qm", "big"); r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-qb", "pr");
    r.put("a.txt", "a2\n"); r.put("big.txt", lines(40, { 5: "pr edit" })); r.g("commit", "-qam", "pr change");
    const reviewed = r.sha();
    // Main moves: another file and a far-away hunk of a file the PR also edits.
    r.g("checkout", "-q", "main");
    r.put("b.txt", "b2\n"); r.put("big.txt", lines(40, { 35: "main edit" })); r.g("commit", "-qam", "main change"); r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-q", "pr"); r.g("merge", "-q", "--no-edit", "main");
    const m1 = r.sha();
    const ok = G.verifyMainMerges(r.dir, reviewed, m1, MAINREF);
    assert.deepEqual(ok, { ok: true, why: "main merges only, diff unchanged", between: [m1] });
    // A second main merge on top still carries from the reviewed head, listing both merges.
    r.g("checkout", "-q", "main"); r.put("c.txt", "c2\n"); r.g("commit", "-qam", "main again"); r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-q", "pr"); r.g("merge", "-q", "--no-edit", "main");
    const m2 = r.sha();
    assert.deepEqual(G.verifyMainMerges(r.dir, reviewed, m2, MAINREF).between, [m2, m1]);

    // The merge resolution changes the PR's own hunk: no carry.
    r.g("checkout", "-q", "-b", "pr2", reviewed);
    r.g("merge", "-q", "--no-commit", "main"); r.put("big.txt", lines(40, { 5: "pr edit, resolved differently", 35: "main edit" })); r.g("add", "big.txt"); r.g("commit", "-qm", "merge");
    assert.match(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).why, /differs from a clean merge of its parents/);
    // A generated file regenerated in the merge counts as the PR's own diff too.
    r.g("checkout", "-q", "-b", "pr2b", reviewed);
    r.g("merge", "-q", "--no-commit", "main"); r.put("a.txt", "a2 regenerated\n"); r.g("add", "a.txt"); r.g("commit", "-qm", "merge");
    assert.equal(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).ok, false);
    // A mode-only change hidden in the merge is caught.
    r.g("checkout", "-q", "-b", "pr2c", reviewed);
    r.g("merge", "-q", "--no-commit", "main"); chmodSync(join(r.dir, "a.txt"), 0o755); r.g("add", "a.txt"); r.g("commit", "-qm", "merge");
    assert.equal(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).ok, false);

    // A non-merge commit after the reviewed head: no carry, even when it is followed by a clean main merge.
    r.g("checkout", "-q", "-b", "pr3", m1);
    r.put("d.txt", "new\n"); r.g("add", "d.txt"); r.g("commit", "-qm", "extra");
    assert.match(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).why, /is not a merge of main/);
    r.g("merge", "-q", "--no-edit", "main");
    assert.equal(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).ok, false);
    // An empty non-merge commit is still a non-merge commit.
    r.g("checkout", "-q", "-b", "pr3b", m1); r.g("commit", "-q", "--allow-empty", "-m", "empty");
    assert.equal(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).ok, false);

    // A merge of a branch that is not on main: no carry.
    r.g("checkout", "-q", "-b", "side", "main~1"); r.put("e.txt", "side\n"); r.g("add", "e.txt"); r.g("commit", "-qm", "side");
    r.g("checkout", "-q", "-b", "pr4", reviewed); r.g("merge", "-q", "--no-edit", "side");
    assert.match(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).why, /second parent is not on main/);

    // Not a descendant, the same commit, or an unknown commit: no carry.
    assert.equal(G.verifyMainMerges(r.dir, m1, reviewed, MAINREF).ok, false);
    assert.equal(G.verifyMainMerges(r.dir, reviewed, reviewed, MAINREF).ok, false);
    assert.equal(G.verifyMainMerges(r.dir, reviewed, "f".repeat(40), MAINREF).ok, false);
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
  const prPathList = JSON.parse(/^  pull_request:\n    paths: (\[.*\])$/m.exec(desktop)[1]).filter((p) => !p.startsWith("!"));
  const scope = new RegExp(/^\s+QUEUE_PATHS: (.+)$/m.exec(desktop)[1]);
  for (const p of prPathList) assert.match(p.replace(/\*\*$/, "x"), scope, `queue-scope misses ${p}`);
  assert.doesNotMatch("docs/mac-ci.md", scope);
  assert.match(/^  native-headless:\n(?:.*\n){1,3}/m.exec(desktop)[0], /needs: (queue-scope|\[queue-scope, pr-scope\])/);
  // D112: every other queue workflow is Linux-only and decides with its own pull_request path list.
  for (const path of R.QUEUE_WORKFLOWS.filter((p) => !/\/(ci|desktop)\.yml$/.test(p))) {
    const text = readFileSync(join(root, path), "utf8");
    assert.doesNotMatch(text, /macos|trusted-mac\.yml/i, `${path}: no Mac time in the merge queue`);
    const block = /^  pull_request:\n    paths:\n((?:      - .*\n)+)/m.exec(text);
    assert.ok(block, `${path}: pull_request paths list`);
    const list = block[1].trim().split("\n").map((l) => l.replace(/^\s*- /, "").replace(/^['"]|['"]$/g, "")).filter((p) => !p.startsWith("!"));
    const re = new RegExp(/^\s+QUEUE_PATHS: (.+)$/m.exec(text)[1]);
    for (const p of list) assert.match(p.replace(/\*\*$/, "x"), re, `${path}: queue-scope misses ${p}`);
    assert.doesNotMatch("docs/unrelated.md", re, `${path}: queue-scope is too wide`);
    const jobs = text.slice(text.indexOf("\njobs:\n"));
    const names = [...jobs.matchAll(/^  ([a-z0-9-]+):\n/gm)].map((m) => m[1]);
    assert.ok(names.includes("queue-scope") && names.length >= 2, `${path}: queue-scope plus the checked job(s)`);
    for (const job of names.filter((n) => n !== "queue-scope")) {
      const body = new RegExp(`^  ${job}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(jobs)[1];
      assert.match(body, /needs: queue-scope/, `${path}: ${job} must wait for queue-scope`);
      assert.match(body, /needs\.queue-scope\.outputs\.run == 'true'/, `${path}: ${job} must follow queue-scope`);
    }
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

test("data-sync: with a REVIEWER assignment only the assigned lane's merge admits the PR", () => {
  const rv = comment("REVIEWER: macrevd");
  assert.equal(evalSync({ comments: [rv, comment(v("merge", H, "macrev2"))] }).state, R.FAILURE, "unassigned lane's merge does not admit");
  assert.equal(evalSync({ comments: [rv, comment(v("merge", H, "macrevd"))] }).state, R.SUCCESS);
  assert.equal(evalSync({ comments: [rv, comment(v("merge", H, "macrevd")), comment(v("block", H, "macrevd"))] }).state, R.FAILURE, "assigned block fails");
  for (const bad of ["sonnet", "nosuchlane"]) {
    assert.equal(evalSync({ comments: [comment(`REVIEWER: ${bad}`), comment(v("merge", H, bad)), comment(v("merge", H, "macrev2"))] }).state, R.FAILURE, `assigned ${bad} does not admit`);
  }
  assert.equal(evalSync({ comments: [comment("REVIEWER: macrevc"), comment(v("merge", H, "macrevc"))] }).state, R.SUCCESS, "Terra is fine on tier 1");
  assert.equal(evalSync({ files: [file("cli/internal/quota/x.go")], comments: [comment("REVIEWER: macrevc"), comment(v("merge", H, "macrevc"))] }).state, R.FAILURE, "Terra cannot admit a tier 2 data-sync PR");
  assert.equal(evalSync({ comments: [comment(v("merge", H, "macrev2"))] }).state, R.SUCCESS, "no REVIEWER keeps old behaviour");
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

test("data-sync: a failing run or status on the head still fails; a GPT block still blocks", () => {
  assert.equal(evalSync({ runs: [...syncChecks(), run(".github/workflows/u6-engine-store-core.yml", "failure", 9, "completed", { head_branch: `data/sync-0.5.21-${RUN_ID}`, pull_requests: [] })] }).state, R.FAILURE);
  assert.equal(evalSync({ comments: [comment(v("merge", H, "")), comment(v("block", H, "macrevc"))] }).state, R.FAILURE);
  assert.equal(evalSync({ comments: [comment(v("merge", H, "")), comment(v("block", H, "glm"))] }).state, R.SUCCESS, "D243: a GLM block is input");
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

test("D239: reader, detection and metric PRs name the reference app they follow, or none with a reason (advisory, D243)", () => {
  const ok = (body, files) => evalPr({ p: pr({ body }), files, comments: [comment(v("merge", H, "macrev2")), comment(`GLMREV: OK @ ${H}`)], verified: () => true });
  // Scope: the reader packages and the reader-cause copy table; everything else is untouched by the rule.
  for (const p of ["cli/internal/quota/claude.go", "cli/internal/detect/catalogue.go", "cli/internal/localusage/codex.go",
    "cli/internal/speed/summary.go", "cli/internal/consent/consent.go", "cli/internal/quota/claude_test.go",
    "desktop/native/ModelPlanSettings/Sources/ModelPlanSettings/ReaderCauseTable.swift", "desktop/cockpit/src/reader-causes.ts"])
    assert.equal(R.referenceTouch([p]), true, p);
  for (const p of ["cli/internal/quotafix/a.go", "cli/internal/rows/rows.go", "docs/readers/integration-standard.md",
    "desktop/native/ModelPlanSettings/Sources/ModelPlanSettings/Catalogue.swift", "scripts/merge-gates/rules.mjs"])
    assert.equal(R.referenceTouch([p]), false, p);

  const reader = [file("cli/internal/quota/claude.go")];
  // D243 step 3: a missing or malformed line is reported in the description, never a FAILURE.
  const missing = ok("Scenarios: none", reader);
  assert.equal(missing.state, R.SUCCESS);
  assert.match(missing.why, /info: .*reader PR: no Reference: line \(D239\)$/);
  const draft = evalPr({ p: pr({ draft: true, body: "Scenarios: none" }), files: reader });
  assert.equal(draft.state, R.PENDING, "a draft only waits");
  assert.match(draft.why, /^draft; info: .*no Reference: line/, "and sees the note at once");
  // A renamed-away reader file counts too.
  const renamed = ok("Scenarios: none", [file("cli/internal/old/a.go", { previous_filename: "cli/internal/detect/a.go" })]);
  assert.equal(renamed.state, R.SUCCESS);
  assert.match(renamed.why, /info: .*no Reference: line/);
  // Out of scope: no line needed.
  assert.equal(ok("Scenarios: none", [file("cli/internal/rows/rows.go")]).state, R.SUCCESS);
  assert.doesNotMatch(ok("Scenarios: none", [file("cli/internal/rows/rows.go")]).why, /Reference/);

  const good = {
    "Reference: CodexBar@0827f30 Sources/CodexBarCore/Providers/Claude/ClaudeUsageFetcher.swift": [["CodexBar", "0827f30"]],
    "Reference: Pulse@v1.12.4 Sources/Pulse/Providers/Kiro.swift; ccusage@e42e1b4 src/data-loader.ts": [["Pulse", "v1.12.4"], ["ccusage", "e42e1b4"]],
    "**Reference:** Token Monitor@0c7dd85 docs/providers/codex.md": [["TokenMonitor", "0c7dd85"]],
    "Reference: token-monitor@0c7dd85 src/providers/codex.js, src/providers/shared.js": [["TokenMonitor", "0c7dd85"]],
    "Reference: tokei@1.2.0 README.md": [["Tokei", "1.2.0"]],
    "Reference: none (process reasons here, long enough)": [],
    "Reference: None (test-only refactor; behaviour unchanged)": [],
  };
  for (const [line, refs] of Object.entries(good)) {
    const parsed = R.parseReference(`Intro\n${line}\nReference: nonsense`);
    assert.equal(parsed.malformed, null, line);
    assert.deepEqual(parsed.refs.map((r) => [r.app, r.ref]), refs, line);
    const r = ok(`Scenarios: none\n${line}`, reader);
    assert.equal(r.state, R.SUCCESS, `${line}: ${r.why}`);
    assert.doesNotMatch(r.why, /Reference/, line);
  }
  for (const line of [
    "Reference:",
    "Reference: none",
    "Reference: none ()",
    "Reference: none, CodexBar is close",
    "Reference: CodexBar",
    "Reference: CodexBar@0827f30",
    "Reference: CodexBar 0827f30 Sources/a.swift",
    "Reference: CodexBar@main Sources/a.swift",
    "Reference: Tokscale@abc1234 src/a.ts",
    "Reference: OpenUsage@abc1234 src/a.ts",
    "Reference: CodexBar@0827f30 the Claude fetcher",
    "Reference: CodexBar@0827f30 Sources/a.swift; Pulse",
    "References: CodexBar@0827f30 Sources/a.swift",
  ]) {
    const r = ok(`Scenarios: none\n${line}`, reader);
    assert.equal(r.state, R.SUCCESS, line);
    assert.match(r.why, /info: .*(Reference: line (malformed|none needs)|no Reference: line)/, line);
  }
  // none needs a reason of 20+ characters.
  for (const line of ["Reference: none (process)", "Reference: none (too short)"]) {
    const r = ok(`Scenarios: none\n${line}`, reader);
    assert.match(r.why, /Reference: line none needs a reason of at least 20 characters \(D239\)/, line);
  }
  assert.equal(R.parseReference("Reference: none (nineteen chars!!!)").malformed !== null, true);
  assert.equal(R.parseReference("Reference: none (exactly twenty chars)").malformed, null);
  assert.equal(R.parseReference("no line").declared, false);
  assert.equal(R.parseReference("References: #12").declared, false, "a References line is not the declaration");
});

test("D239: widget, menu-bar and native-shell PRs name an allowed reference (reference-map.json)", () => {
  const ok = (body, files) => evalPr({ p: pr({ body }), files, comments: [comment(v("merge", H, "macrev2")), comment(`GLMREV: OK @ ${H}`)], verified: () => true });
  const AI = "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/";
  const widget = [file("desktop/native/ModelPlanDock/Native/DockCardView.swift")];
  const widgetHost = [file(`${AI}StaticDockPreviewHost.swift`)];
  const shell = [file(`${AI}EngineLifecycleController.swift`)];
  const names = (p) => R.referenceGroups([p]).map((g) => g.name);
  for (const p of ["desktop/native/ModelPlanDock/Logic/DockEdgeGeometry.swift", `${AI}DockEdgeControllerBinding.swift`, `${AI}DockInteractionHostPort.swift`,
    `${AI}CommunityPlacementBinding.swift`, `${AI}StaticDockPreviewApplication.swift`,
    "desktop/native/Sources/ModelPlanShell/Pulse/PulseDockPanel.swift"]) assert.deepEqual(names(p), ["widget"], p);
  for (const p of [`${AI}CommunityMenuBar.swift`, `${AI}U6StatusItemFrameSampler.swift`, `${AI}HelpOverlayRouter.swift`, `${AI}DockHelpPresenter.swift`,
    "desktop/native/ModelPlanCockpitShell/Sources/ModelPlanCockpitShell/CockpitWindowState.swift",
    "desktop/native/ModelPlanCockpitWeb/Sources/ModelPlanCockpitWeb/CockpitWindowController.swift",
    "desktop/native/Sources/ModelPlanShell/SystemEvents.swift", "desktop/native/Sources/ModelPlanShell/StatusItemPlacement.swift",
    "desktop/native/Sources/ModelPlanCommunityHost/CommunityDelegate.swift", "desktop/native/Sources/ModelPlanCommunityHost/CommunityMenuBarPresentation.swift"]) assert.deepEqual(names(p), ["menu-bar and native shell"], p);
  for (const p of [`${AI}CommunityCockpitFactory.swift`, "desktop/native/ModelPlanSelection/Sources/a.swift", "docs/readers/integration-standard.md"]) assert.deepEqual(names(p), [], p);

  for (const files of [widget, widgetHost, shell]) {
    // missing
    assert.match(ok("Scenarios: none", files).why, /PR: no Reference: line/);
    // none with and without a reason
    assert.doesNotMatch(ok("Scenarios: none\nReference: none (no Pulse equivalent exists)", files).why, /Reference/);
    assert.match(ok("Scenarios: none\nReference: none (n/a)", files).why, /at least 20 characters/);
    assert.match(ok("Scenarios: none\nReference: none", files).why, /needs a reason in brackets/);
  }
  // widget: Pulse only
  assert.doesNotMatch(ok("Scenarios: none\nReference: Pulse@v1.12.4 Sources/Pulse/Dock.swift", widget).why, /Reference/);
  assert.match(ok("Scenarios: none\nReference: CodexBar@0827f30 Sources/a.swift", widget).why, /widget PR must follow one of Pulse/);
  // shell: CodexBar, Stats, Maccy or Pulse; ccusage is not a shell reference
  for (const l of ["Stats@v2.11.0 Stats/Modules/a.swift", "Maccy@2.0.0 Maccy/Menu.swift", "CodexBar@0827f30 Sources/a.swift", "Pulse@v1.12.4 a/b.swift"])
    assert.doesNotMatch(ok(`Scenarios: none\nReference: ${l}`, shell).why, /Reference/, l);
  assert.match(ok("Scenarios: none\nReference: ccusage@e42e1b4 src/a.ts", shell).why, /menu-bar and native shell PR must follow one of CodexBar, Stats, Maccy, Pulse/);
  // reader group unchanged: Stats is not a reader reference
  assert.match(ok("Scenarios: none\nReference: Stats@v2.11.0 a/b.swift", [file("cli/internal/quota/claude.go")]).why, /reader PR must follow/);
  // a PR across two groups needs an allowed app for each
  assert.match(ok("Scenarios: none\nReference: Stats@v2.11.0 a/b.swift", [...widget, ...shell]).why, /widget PR must follow/);
  assert.doesNotMatch(ok("Scenarios: none\nReference: Stats@v2.11.0 a/b.swift; Pulse@v1.12.4 c/d.swift", [...widget, ...shell]).why, /Reference/);
});

test("D239: every mapped area carries the generated AGENTS.md and CLAUDE.md for exactly the apps in reference-map.json", async () => {
  const { readFileSync, existsSync } = await import("node:fs");
  const { expectedFiles, mappedDirs } = await import("../merge-gates/reference-docs.mjs");
  const map = JSON.parse(readFileSync(new URL("../merge-gates/reference-map.json", import.meta.url), "utf8"));
  assert.ok(mappedDirs(map).size > 0);
  for (const g of map.groups) {
    assert.ok(g.dirs?.length && g.hint, `${g.name} needs dirs and hint`);
    for (const a of g.apps) assert.ok(map.repos[a], `${a} needs a repos entry`);
  }
  for (const [path, text] of expectedFiles(map)) {
    const full = new URL(`../../${path}`, import.meta.url);
    assert.ok(existsSync(full), `${path} is missing: run node scripts/merge-gates/reference-docs.mjs --write`);
    assert.equal(readFileSync(full, "utf8"), text, `${path} is stale: run node scripts/merge-gates/reference-docs.mjs --write`);
  }
  for (const g of map.groups) for (const d of g.dirs) {
    const text = readFileSync(new URL(`../../${d}/AGENTS.md`, import.meta.url), "utf8");
    for (const a of g.apps) assert.ok(text.includes(a), `${d}/AGENTS.md omits ${a}`);
  }
});

test("D239: check-reference.mjs runs the gate rule on a local diff", async () => {
  const { execFileSync, spawnSync } = await import("node:child_process");
  const { mkdtempSync, writeFileSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const dir = mkdtempSync(join(tmpdir(), "refcheck-"));
  const git = (...a) => execFileSync("git", a, { cwd: dir, encoding: "utf8" });
  git("init", "-q"); git("config", "user.email", "a@b.c"); git("config", "user.name", "t");
  writeFileSync(join(dir, "x"), "1"); git("add", "."); git("commit", "-qm", "base");
  git("checkout", "-qb", "work");
  execFileSync("mkdir", ["-p", join(dir, "desktop/native/ModelPlanDock/Native")]);
  writeFileSync(join(dir, "desktop/native/ModelPlanDock/Native/DockCardView.swift"), "x"); git("add", "."); git("commit", "-qm", "dock");
  const script = new URL("../merge-gates/check-reference.mjs", import.meta.url).pathname;
  const run = (body) => { const f = join(dir, "body.txt"); writeFileSync(f, body); return spawnSync(process.execPath, [script, "--diff", "HEAD~1", "--body", f], { cwd: dir, encoding: "utf8" }); };
  assert.equal(run("Reference: Pulse@v1.12.4 Sources/Dock.swift").status, 0);
  assert.equal(run("Reference: none (no Pulse equivalent for this)").status, 0);
  const bad = run("Reference: none (n/a)");
  assert.equal(bad.status, 1); assert.match(bad.stderr, /at least 20 characters/);
  assert.equal(run("nothing").status, 1);
  assert.equal(run("Reference: CodexBar@0827f30 a/b.swift").status, 1);
});

test("merge-group gate waits for the group's GUI job, fails closed, times out", () => {
  const ok = { state: R.SUCCESS, why: "ok" };
  const steps = [{ pr: 7, prResult: ok, mergeProof: { ok: true } }];
  const runs = R.QUEUE_WORKFLOWS.map((path, i) => qrun(path, "success", 1, "completed", { check_suite_id: 100 + i, created_at: "2026-11-15T15:00:00Z" }));
  const desktopSuite = 100 + R.QUEUE_WORKFLOWS.indexOf(".github/workflows/desktop.yml");
  const gui = (status, conclusion = null) => ({ name: "native (macos-latest) / native (macos-latest)", status, conclusion, check_suite: { id: desktopSuite } });
  const now = Date.parse("2026-11-15T15:31:00Z");
  const ev = (checks, at = now) => R.evaluateGroup({ steps, queueRuns: runs, queueCheckRuns: checks, now: at });
  assert.equal(ev([gui("completed", "success")]).state, R.SUCCESS);
  assert.equal(ev([gui("completed", "skipped")]).state, R.SUCCESS, "skipped by design");
  assert.equal(ev([]).state, R.SUCCESS, "no GUI job when desktop.yml scoped it out");
  const queued = ev([gui("queued")]);
  assert.equal(queued.state, R.PENDING);
  assert.match(queued.why, /native \(macos-latest\)/);
  assert.equal(ev([gui("in_progress")]).state, R.PENDING);
  for (const c of ["failure", "cancelled", "timed_out"]) assert.equal(ev([gui("completed", c)]).state, R.FAILURE, c);
  const late = ev([gui("queued")], now + R.GROUP_WAIT_MS + 60000);
  assert.equal(late.state, R.FAILURE);
  assert.match(late.why, /timed out/);
  assert.equal(ev([{ ...gui("queued"), check_suite: { id: 9999 } }]).state, R.SUCCESS, "another suite's job is not the queue's");
});

test("merge-group GUI leg: skipped is ok only when desktop.yml declared the GUI share not needed", () => {
  const job = (name, conclusion, steps = []) => ({ name, conclusion, steps });
  const none = job("queue-scope", "success", [{ name: "GUI share not needed", conclusion: "success" }]);
  const gui = "native (macos-latest) / native (macos-latest)";
  assert.equal(R.guiLegState([none, job("gui-scope", "skipped"), job(gui, "skipped")]).state, R.SUCCESS, "declared not needed");
  assert.equal(R.guiLegState([job("queue-scope", "success", [{ name: "GUI share not needed", conclusion: "skipped" }]), job(gui, "skipped")]).state, R.FAILURE, "skipped without the declaration");
  assert.equal(R.guiLegState([job("queue-scope", "success"), job("gui-scope", "success"), job(gui, "skipped")]).state, R.FAILURE);
  assert.equal(R.guiLegState([job("queue-scope", "success")]).state, R.FAILURE, "no GUI job at all");
  assert.equal(R.guiLegState([job(gui, "success")]).state, R.SUCCESS);
  assert.equal(R.guiLegState([job(gui, "failure")]).state, R.FAILURE);
  assert.equal(R.guiLegState([job("native (${{ matrix.os }})", "skipped"), job("native-hosted (macos-15) / native-hosted-gui (macos-15)", "success"), job("native-owner-gui (macos-latest) / native-owner-gui (macos-latest)", "success")]).state, R.SUCCESS, "hosted pair green, native skipped whole");
  // macrevb-997-3: the live job list of merge-group run 43781966202 shape, GUI leg green, child jobs skipped by design.
  const live = [job("queue-scope", "success"), job("gui-scope", "success"), job("native-partition", "success"),
    job("native-headless (macos-latest) / native-headless (macos-latest)", "success"), job("native-headless (macos-latest) / probe", "skipped"),
    job(gui, "success"), job("native (macos-latest) / transport", "skipped"), job("native (macos-latest) / sequences", "skipped"), job("native (macos-latest) / probe", "skipped"),
    job("native (macos-latest) / native-headless (${{ inputs.os }})", "skipped"), job("native (macos-latest) / u11-native (${{ inputs.os }})", "skipped"), job("native (macos-latest) / gui-probe", "skipped"),
    job("native-hosted (${{ matrix.os }})", "skipped"), job("native-owner-gui (macos-latest)", "skipped")];
  assert.equal(R.guiLegState(live).state, R.SUCCESS, "child jobs skipped by design do not fail a green GUI leg");
  assert.equal(R.guiLegState(live.map((j) => j.name === gui ? { ...j, conclusion: "failure" } : j)).state, R.FAILURE);
  assert.equal(R.guiLegState(live.filter((j) => j.name !== gui)).state, R.FAILURE, "children alone are not a GUI leg");
  assert.equal(R.guiLegState([job(gui, "skipped"), job("native-hosted (macos-15) / native-hosted-gui (macos-15)", "success"), job("native-owner-gui (macos-latest) / native-owner-gui (macos-latest)", "skipped")]).state, R.FAILURE, "half the hosted pair skipped");
  const ok = { state: R.SUCCESS, why: "ok" };
  const runs = R.QUEUE_WORKFLOWS.map((path, i) => qrun(path, "success", 1, "completed", { check_suite_id: 100 + i }));
  const g = (desktopJobs) => R.evaluateGroup({ steps: [{ pr: 7, prResult: ok, mergeProof: { ok: true } }], queueRuns: runs, desktopJobs });
  assert.equal(g([job(gui, "skipped")]).state, R.FAILURE);
  assert.equal(g([none, job(gui, "skipped")]).state, R.SUCCESS);
});


test("auto-carry proof refuses a relocated-hunk merge: same own-diff text, different code (macrevd-946)", () => {
  const r = repo();
  try {
    const block = (n) => `// c1\n// c2\n// c3\n  return ${n};\n// d1\n// d2\n// d3\n`;
    const file = (a, b) => `head\nh2\nh3\nh4\n${block(a)}mid1\nmid2\nmid3\nmid4\nmid5\n${block(b)}tail\n`;
    r.put("policy.js", file("false", "false")); r.g("add", "."); r.g("commit", "-qm", "policy"); r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-qb", "pr");
    r.put("policy.js", file("true", "false")); r.g("commit", "-qam", "pr change");
    const reviewed = r.sha();
    r.g("checkout", "-q", "main"); r.put("b.txt", "b2\n"); r.g("commit", "-qam", "main change"); r.g("update-ref", MAINREF, "HEAD");
    // Evil merge: the first block goes back to false and the second becomes true; the patch text of the PR's own
    // change is identical because both hunks carry the same context.
    r.g("checkout", "-q", "-b", "evil", reviewed); r.g("merge", "-q", "--no-commit", "main");
    r.put("policy.js", file("false", "true")); r.g("add", "policy.js"); r.g("commit", "-qm", "merge");
    const evil = r.sha();
    assert.equal(G.ownPatch(r.dir, G.mergeBase ? G.mergeBase(r.dir, MAINREF, reviewed) : "main~1", reviewed).length > 0, true);
    const res = G.verifyMainMerges(r.dir, reviewed, evil, MAINREF);
    assert.equal(res.ok, false);
    assert.match(res.why, /differs from a clean merge of its parents/);
    // The same PR with an honest merge still carries.
    r.g("checkout", "-q", "-b", "honest", reviewed); r.g("merge", "-q", "--no-edit", "main");
    assert.equal(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).ok, true);
    // No carried gate success from the refused proof.
    const out = evalPr({ comments: [comment(v("merge", reviewed, "macrev2"))], prove: (o, n) => G.verifyMainMerges(r.dir, o, evil, MAINREF) });
    assert.notEqual(out.state, R.SUCCESS);
  } finally { r.done(); }
});

test("a verdict on the current head beats a carried older-head verdict from the same lane, whatever the posting order (macrevc-946-1)", () => {
  const O = "b".repeat(40);
  const out = evalPr({ comments: [comment(v("block", H, "macrev2")), comment(v("merge", O, "macrev2"))],
    prove: () => ({ ok: true, between: [H] }) });
  assert.notEqual(out.state, R.SUCCESS, out.why);
  const sup = evalPr({ comments: [comment(v("merge", O, "macrev2")), comment(v("block", H, "macrev2")), comment(v("merge", H, "macrev2"))],
    prove: () => ({ ok: true, between: [H] }) });
  assert.equal(sup.state, R.SUCCESS, sup.why);
});

test("no carry without tree equality: hand-resolved conflicts, tree tweaks, octopus merges and replace refs (macrevd-946 class)", () => {
  const r = repo();
  try {
    r.g("checkout", "-qb", "pr");
    r.put("a.txt", "pr\n"); r.g("commit", "-qam", "pr change");
    const reviewed = r.sha();
    r.g("checkout", "-q", "main"); r.put("b.txt", "b2\n"); r.g("commit", "-qam", "main change"); r.g("update-ref", MAINREF, "HEAD");
    const main1 = r.sha();
    const both = (sha, re) => {
      for (const res of [G.verifyMainMerges(r.dir, reviewed, sha, MAINREF), G.verifyCarry(r.dir, reviewed, sha, MAINREF)]) {
        assert.equal(res.ok, false, res.why);
        if (re) assert.match(res.why, re);
      }
    };
    // Clean merge: both carry paths hold.
    r.g("checkout", "-q", "-b", "clean", reviewed); r.g("merge", "-q", "--no-edit", "main");
    const clean = r.sha();
    assert.equal(G.verifyMainMerges(r.dir, reviewed, clean, MAINREF).ok, true);
    assert.equal(G.verifyCarry(r.dir, reviewed, clean, MAINREF).ok, true);
    // The gate maps the synthetic head H to a real commit: a clean merge carries the verdict, a refused proof never does.
    const gate = (sha) => evalPr({ comments: [comment(v("merge", reviewed, "macrev2"))], prove: (o, n) => G.verifyMainMerges(r.dir, o, n === H ? sha : n, MAINREF) });
    assert.equal(gate(clean).state, R.SUCCESS, gate(clean).why);
    assert.match(gate(clean).why, /verdict carried from/);

    // Tree tweak inside the merge (main's own change reverted in the merge): no carry.
    r.g("checkout", "-q", "-b", "tweak", reviewed); r.g("merge", "-q", "--no-commit", "main");
    r.put("b.txt", "b\n"); r.g("add", "b.txt"); r.g("commit", "-qm", "merge");
    both(r.sha());
    assert.match(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).why, /differs from a clean merge of its parents/);

    // Main conflicts with the PR; the merge is resolved by hand, even back to exactly the reviewed text: no carry.
    r.g("checkout", "-q", "main"); r.put("a.txt", "main\n"); r.g("commit", "-qam", "main edits a"); r.g("update-ref", MAINREF, "HEAD");
    r.g("checkout", "-q", "-b", "conflict", reviewed);
    assert.equal(spawnSync("git", ["merge", "-q", "--no-edit", "main"], { cwd: r.dir, env: { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@example.invalid", GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" } }).status !== 0, true, "merge conflicts");
    r.put("a.txt", "pr\n"); r.g("add", "a.txt"); r.g("commit", "-qm", "resolved");
    both(r.sha());
    assert.match(G.verifyMainMerges(r.dir, reviewed, r.sha(), MAINREF).why, /do not merge cleanly/);
    assert.notEqual(gate(r.sha()).state, R.SUCCESS);

    // Octopus merge of main commits: no carry.
    const octo = r.g("commit-tree", `${clean}^{tree}`, "-p", reviewed, "-p", main1, "-p", "main~2", "-m", "octopus");
    both(octo);

    // A replace ref that makes the evil merge look like the clean one is ignored.
    r.g("checkout", "-q", "-b", "evil", reviewed); r.g("merge", "-q", "--no-commit", main1);
    r.put("c.txt", "evil\n"); r.g("add", "c.txt"); r.g("commit", "-qm", "merge");
    const evil = r.sha();
    r.g("replace", evil, clean);
    both(evil);
    assert.notEqual(gate(evil).state, R.SUCCESS);
  } finally { r.done(); }
});

test("auto-carry: a shadow lane's verdict never changes the carry or the gate state (Sol SOL-6)", () => {
  const base = [comment(v("merge", OLD, "macrevc"))];
  const ref = evalPr({ comments: base, prove: proved() });
  assert.equal(ref.state, R.SUCCESS);
  assert.equal(ref.autoCarried, OLD);
  for (const lane of ["ghsolshadow", "ghglmshadow", "gh-terra-shadow"])
    for (const sha of [H, OLD])
      for (const verdict of ["merge", "block"]) {
        const r = evalPr({ comments: [...base, comment(v(verdict, sha, lane))], prove: proved() });
        assert.equal(r.state, ref.state, `${lane} ${verdict} @ ${sha.slice(0, 1)}`);
        assert.equal(r.autoCarried, ref.autoCarried, `${lane} ${verdict} @ ${sha.slice(0, 1)}`);
      }
  // Control: a counting or other named lane at the current head still stops the carry.
  assert.equal(evalPr({ comments: [...base, comment(v("merge", H, "glm"))], prove: proved() }).autoCarried, undefined);
});

test("auto-carry: the latest posted verdict head is the only candidate; when it is the current head nothing carries, whatever the lane (macrevb-946-1)", () => {
  const t2 = [file("scripts/merge-gates/rules.mjs")];
  const ok = () => ({ ok: true, between: [H] });
  const oldSol = comment(v("merge", OLD, "macrev2"));
  // An old Sol merge, then a current-head verdict from a lane that cannot pass tier 2: no carry, tier 2 stays unpassed.
  for (const lane of ["macrevc", "glm", "sonnet"]) {
    const items = R.feed([oldSol, comment(v("merge", H, lane))], []);
    assert.equal(R.autoCarry(items, H, ok), null, lane);
    const out = evalPr({ files: t2, comments: [oldSol, comment(v("merge", H, lane))], prove: ok });
    assert.notEqual(out.state, R.SUCCESS, `${lane}: ${out.why}`);
    assert.doesNotMatch(out.why, /carried/);
  }
  // The same with a sticky reviewer assignment, before or after the verdicts.
  for (const order of ["before", "after"]) {
    const rv = comment("REVIEWER: macrev2"), cur = comment(v("merge", H, "macrevc"));
    const comments = order === "before" ? [rv, oldSol, cur] : [oldSol, cur, rv];
    const out = evalPr({ files: t2, comments, prove: ok });
    assert.notEqual(out.state, R.SUCCESS, `${order}: ${out.why}`);
    assert.doesNotMatch(out.why, /carried/);
  }
  // A current-head verdict in a review counts as posted too.
  assert.notEqual(evalPr({ files: t2, comments: [oldSol], reviews: [review(v("merge", H, "macrevc"))], prove: ok }).state, R.SUCCESS);
  // Control: when the old head is the latest, the proven carry still applies, with or without the sticky reviewer.
  assert.equal(evalPr({ files: t2, comments: [oldSol], prove: ok }).state, R.SUCCESS);
  assert.equal(evalPr({ files: t2, comments: [comment("REVIEWER: macrev2"), oldSol], prove: ok }).state, R.SUCCESS);
  const cur = comment(v("merge", H, "macrevc")), later = comment(v("merge", OLD, "macrev2"));
  assert.equal(R.autoCarry(R.feed([cur, later], []), H, ok)?.from, OLD, "an old-head verdict posted after the current-head one is the candidate");
});

// macrevb-1108-4: a workflow shadow lane never admits a data-sync PR, and (ghglm) never decides tier 0 (or a tier outside REVIEW_GLM_TIERS).
test("gh lanes: shadow lanes never admit data-sync; ghglm counts only on its configured tiers, never tier 0", () => {
  for (const lane of ["ghsolshadow", "ghglmshadow", "gh-terra-shadow"])
    assert.equal(evalSync({ comments: [comment(v("merge", H, lane))] }).state, R.FAILURE, `${lane} merge does not admit a data-sync PR`);
  assert.equal(evalSync({ comments: [comment(v("merge", H, "ghsolshadow")), comment(v("merge", H, "macrev2"))] }).state, R.SUCCESS, "an eligible lane still admits beside a shadow");
  assert.equal(evalSync({ comments: [comment(v("merge", H, "ghsol"))] }).state, R.SUCCESS, "ghsol admits");
  assert.equal(evalSync({ comments: [comment(v("merge", H, "ghglm"))] }).state, R.FAILURE, "ghglm never admits by default (D358/D361: GLM is advisory)");
  assert.equal(evalSync({ files: [file("cli/internal/quota/x.go")], comments: [comment(v("merge", H, "ghglm"))] }).state, R.FAILURE, "ghglm does not admit tier 2 by default");
  assert.deepEqual(R.eligibleLanes(0), R.eligibleLanes(0, [1, 2]), "tier 0 has no GLM lane for any configuration");
  assert.ok(!R.eligibleLanes(0, [1, 2]).includes("(ghglm)") && !R.eligibleLanes(0).includes("(ghglm)"));
  assert.ok(!R.eligibleLanes(1).includes("(ghglm)") && R.eligibleLanes(1, [1]).includes("(ghglm)") && !R.eligibleLanes(2, [1]).includes("(ghglm)") && R.eligibleLanes(2, [2]).includes("(ghglm)"));
  const docs = [file("docs/a.md")];
  assert.equal(evalPr({ files: docs, comments: [comment(v("block", H, "ghglm"))] }).state, R.SUCCESS, "a tier-0 ghglm block is advice");
  // an IMPORTANT tier-1 PR (D482: a credentials/token path); on a NORMAL PR the GLM verdict counts (see the D395 tests)
  assert.equal(evalPr({ files: [file("cli/internal/setup/oauth_flow.go")], comments: [comment(v("block", H, "ghglm"))] }).state, R.PENDING, "a ghglm block never vetoes an important PR by default");
  assert.ok(R.isShadowLane("(ghsolshadow)") && R.isShadowLane("gh-terra-shadow") && !R.isShadowLane("(ghsol)"));
});

// owner D367 addendum: on a PR labelled review:gpt the GPT verdict decides; (ghglm) is advisory whatever REVIEW_GLM_TIERS says.
test("review:gpt: GLM is advisory and a REVIEWER: ghglm assignment pins nothing on a labelled PR", () => {
  const labelled = pr({ labels: [{ name: "review:gpt" }] });
  const files = [file("cli/internal/quota/x.go")];   // tier 2
  const glmTiers = [1, 2];
  const ev = (p, comments) => R.evaluatePr({ pr: p, items: R.feed(comments), files, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, glmTiers });
  // labelled: GLM block + GPT merge -> merge
  assert.equal(ev(labelled, [comment(v("block", H, "ghglm")), comment(v("merge", H, "ghsol"))]).state, R.SUCCESS);
  // labelled: GLM merge only -> pending (does not count for merge, even on a tier GLM may decide)
  assert.equal(ev(labelled, [comment(v("merge", H, "ghglm"))]).state, R.PENDING);
  // labelled: GLM block alone does not block either
  assert.equal(ev(labelled, [comment(v("block", H, "ghglm"))]).state, R.PENDING);
  // unlabelled: unchanged (GLM counts on its tiers: its block vetoes, its merge decides)
  assert.equal(ev(pr(), [comment(v("merge", H, "ghglm"))]).state, R.SUCCESS);
  assert.notEqual(ev(pr(), [comment(v("block", H, "ghglm")), comment(v("merge", H, "ghsol"))]).state, R.SUCCESS);
  // sticky: REVIEWER: ghglm pins an unlabelled PR, but not a labelled one, where ghsol's merge counts
  const pin = comment("REVIEWER: ghglm");
  assert.equal(R.reviewerLane(R.feed([pin])), "(ghglm)");
  assert.equal(R.reviewerLane(R.feed([pin]), true), null);
  assert.equal(ev(labelled, [pin, comment(v("merge", H, "ghsol"))]).state, R.SUCCESS);
  // D396: REVIEWER: ghglm / ghsol assigns the workflow reviewer pair, so ghsol's merge counts there too; another lane's does not
  assert.equal(ev(pr(), [pin, comment(v("merge", H, "ghsol"))]).state, R.SUCCESS);
  assert.equal(ev(pr(), [pin, comment(v("merge", H, "macrev2"))]).state, R.SUCCESS, "D395 stateless: any Sol lane's merge lands");
  // a REVIEWER: assignment to another lane still pins a labelled PR
  assert.equal(R.reviewerLane(R.feed([comment("REVIEWER: ghsol")]), true), "(ghsol)");
});

// macrev2-1254 (supersedes owner 2026-11-21): a GLM fallback verdict NEVER counts on an IMPORTANT PR; a review:gpt label makes a
// PR IMPORTANT. The workflow no longer writes the marker and the gate ignores it, marked or not, labelled or not.
test("review:gpt / IMPORTANT: a GLM fallback verdict (marked or not) is advisory; only an exact-head Sol merge lands the PR", () => {
  const labelled = pr({ labels: [{ name: "review:gpt" }] });
  const files = [file("cli/internal/keychain/x.go")];   // tier 2 and IMPORTANT (credentials)
  const ev = (p, comments) => R.evaluatePr({ pr: p, items: R.feed(comments), files, runs: greenCi, statuses: [], verifiedEdge: () => false, conf });   // REVIEW_GLM_TIERS empty
  const M = R.GPT_FALLBACK_MARKER;
  assert.equal(R.gptFallbackVerdict(R.feed([comment(`x\n${M}\nVERDICT: merge @ ${H} (ghglm)`)]), H), null);
  const marked = (verdict, sha = H) => comment(`GLM review\n\n${M}\n\nVERDICT: ${verdict} @ ${sha} (ghglm)`);
  for (const p of [labelled, pr()]) {
    assert.equal(ev(p, [marked("merge")]).state, R.PENDING, "marked GLM merge does not count");
    assert.equal(ev(p, [comment(v("merge", H, "ghglm"))]).state, R.PENDING, "unmarked GLM merge does not count");
    assert.equal(ev(p, [marked("block")]).state, R.PENDING, "an advisory GLM block does not veto");
    assert.equal(ev(p, [marked("merge"), comment(v("merge", H, "ghsol"))]).state, R.SUCCESS, "an exact-head Sol merge satisfies it");
    assert.equal(ev(p, [marked("merge"), comment(v("block", H, "ghsol"))]).state, R.FAILURE, "a Sol block still blocks");
  }
  assert.equal(R.evaluatePr({ pr: pr(), items: R.feed([comment(v("merge", H, "ghglm"))]), files, runs: greenCi, statuses: [], verifiedEdge: () => false, conf, glmTiers: [2] }).state, R.PENDING, "D482: REVIEW_GLM_TIERS never widens an IMPORTANT PR");
  assert.equal(R.evaluatePr({ pr: pr(), items: R.feed([comment(v("merge", H, "ghglm"))]), files: [file("cli/internal/quota/x.go")], runs: greenCi, statuses: [], verifiedEdge: () => false, conf }).state, R.SUCCESS, "D482: a tier-2 NORMAL PR lands on the GLM verdict");
});

test("D374: a native head cannot merge without a mac-compile success status at its head", () => {
  const native = [file("desktop/native/ModelPlanSettings/Pane.swift")];
  const merge = [comment(v("merge"))];
  const r = (o) => evalPr({ files: native, comments: merge, ...o });
  assert.equal(r({ statuses: [compileOk] }).state, R.SUCCESS, "compile green: the gate passes");
  const missing = r({ statuses: [] });
  assert.equal(missing.state, R.PENDING);
  assert.match(missing.why, /^waiting for mac-compile at this head/);
  assert.equal(r({ statuses: [{ context: "mac-compile", state: "pending" }] }).state, R.PENDING, "a running compile holds it");
  assert.equal(r({ statuses: [{ context: "mac-compile", state: "failure" }] }).state, R.FAILURE, "a failed compile blocks it");
  assert.equal(r({ statuses: [{ context: "other", state: "success" }] }).state, R.PENDING, "only the mac-compile context counts");
  // A rename out of desktop/native is native too; a PR with no native file never waits for it.
  assert.equal(evalPr({ files: [file("cli/x.swift", { previous_filename: "desktop/native/x.swift" })], comments: merge, statuses: [] }).state, R.PENDING);
  assert.equal(evalPr({ files: [file("scripts/tool.mjs")], comments: merge, statuses: [] }).state, R.SUCCESS);
  // A truncated file list could hide a native file: it waits for the compile too.
  const many = Array.from({ length: R.FILE_LIST_LIMIT }, (_, i) => file(`docs/${i}.md`));
  assert.equal(evalPr({ files: many, comments: merge, statuses: [] }).state, R.PENDING);
});

// ---- D395/D396 review routing (owner 2026-11-24) ----
test("D482 routing: privacy/consent/credentials/security, gates/CI/release and ledger PRs are IMPORTANT; the rest is NORMAL", () => {
  const cls = (paths, extra = {}) => R.reviewClass({ paths, ...extra }).cls;
  for (const p of [
    "cli/cmd/modelplan/consent_scopes.go", "cli/internal/keychain/security.go", "cli/internal/diagnostics/bundle.go",
    "cli/internal/cliupdate/update.go", "claude-code/cli-pin.json", "desktop/native/credential-agent-artifact-pin.json",
    ".github/workflows/pr-review-sol.yml", ".github/workflows/ci.yml", "scripts/merge-gates/rules.mjs", "cli/go.sum",
    "desktop/native/ModelPlanApp/ModelPlan.entitlements", "cli/internal/setup/oauth_flow.go", "cli/internal/zai/api_key.go",
  ]) assert.equal(cls([p]), R.IMPORTANT, p);
  // D482: wire, the Swift<->Go seam, readers, timing/lifecycle and path tier 2 alone are NORMAL now
  for (const p of [
    "desktop/native/Sources/ModelPlanCore/Wire.swift", "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/HostDeadlineFence.swift",
    "cli/internal/readers/transport.go", "cli/internal/appserver/server.go", "cli/internal/quota/x.go",
    "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/EngineLifecycleController.swift",
    "desktop/native/Sources/ModelPlanCore/CLITransport.swift", "cli/internal/speed/lock_unix.go", "cli/internal/localusage/codex.go",
    "desktop/native/ModelPlanShell/MainThreadHangWatchdog.swift", "desktop/cockpit/src/bridge/host.ts",
    "desktop/native/ModelPlanDock/Sources/ModelPlanDock/DockRevealMotion.swift", "cli/internal/render/quota.go",
    "desktop/cockpit/src/screens/today.ts", "scripts/tool.mjs", "cli/internal/advise/advise.go", "desktop/tests/cockpit/a.spec.mjs",
    "desktop/tests/cockpit/browser/deadline-refresh.spec.mjs", "desktop/official-visuals/cockpit/throttle/throttle.css",
  ]) assert.equal(cls([p]), R.NORMAL, p);
  assert.equal(R.pathTier(["cli/internal/quota/x.go"]), 2, "a tier-2 path ...");
  assert.equal(cls(["cli/internal/quota/x.go"]), R.NORMAL, "... is no longer IMPORTANT by itself");
  // spanning native Swift and cockpit web is NORMAL
  assert.equal(cls(["desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/StatusItemAnchor.swift", "desktop/cockpit/src/screens/today.ts"]), R.NORMAL);
  // mixed: one important path makes the whole PR important
  assert.equal(cls(["scripts/tool.mjs", "desktop/cockpit/src/screens/today.ts", "cli/cmd/modelplan/consent_scopes.go"]), R.IMPORTANT);
  assert.match(R.reviewClass({ paths: ["scripts/tool.mjs", "cli/cmd/modelplan/consent_scopes.go"] }).why, /^consent: cli\/cmd\/modelplan\/consent_scopes\.go$/);
  // labels, the ledger line, a trusted REVIEW-TIER: 2, an empty or long file list
  assert.equal(cls(["scripts/tool.mjs"], { labels: [{ name: "review:codex" }] }), R.IMPORTANT);
  assert.equal(cls(["scripts/tool.mjs"], { labels: ["review:gpt"] }), R.IMPORTANT);
  assert.equal(cls(["scripts/tool.mjs"], { ledger: true }), R.IMPORTANT);
  assert.equal(cls(["scripts/tool.mjs"], { override: 2 }), R.IMPORTANT);
  assert.equal(cls(["scripts/tool.mjs"], { override: 1 }), R.NORMAL, "a lower override never makes a PR important");
  assert.equal(cls(["cli/cmd/modelplan/consent_scopes.go"], { override: 1 }), R.IMPORTANT, "... nor normal");
  assert.equal(cls([]), R.IMPORTANT);
  assert.equal(cls(["scripts/tool.mjs"], { fileCount: R.REVIEW_ROUTING.maxFiles }), R.IMPORTANT);
  // the table is valid for Python too (the coordinator reads it): no lookbehind, no named groups, no flags inside
  for (const a of R.REVIEW_ROUTING.areas) assert.doesNotMatch(a.re, /\(\?[<=!:P]/, a.area);
  assert.doesNotMatch(R.REVIEW_ROUTING.ledger, /\(\?[<=!:P]/);
});

test("macrevb-1311-1: an IMPORTANT PR is at least tier 1 (prReview); a NORMAL tier-0 PR needs no verdict", () => {
  assert.deepEqual(R.prReview({ paths: [".github/workflows/ci.yml"] }), { tier: 1, cls: R.IMPORTANT, why: "gates-ci: .github/workflows/ci.yml" });
  assert.equal(R.prReview({ paths: ["docs/a.md"], labels: ["review:gpt"] }).tier, 1);
  assert.equal(R.prReview({ paths: ["docs/a.md"], renamed: true }).tier, 1);
  assert.equal(R.prReview({ paths: ["docs/a.md"], override: 0, ledger: true }).tier, 1);
  assert.deepEqual(R.prReview({ paths: ["docs/a.md"] }), { tier: 0, cls: R.NORMAL, why: "no important path" });
  const wf = evalPr({ files: [file(".github/workflows/ci.yml")] });
  assert.deepEqual([wf.state, wf.tier, wf.review], [R.PENDING, 1, R.IMPORTANT], wf.why);
  assert.equal(evalPr({ files: [file(".github/workflows/ci.yml")], comments: [comment(v("merge", H, "macrevb"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ files: [file("docs/a.md")] }).state, R.SUCCESS, "normal tier 0: no review");
});

// The shared vectors: decide.py review_class (the coordinator) runs the same "examples" of review-routing.json.
test("D482 shared examples: reviewClass answers every example of review-routing.json", () => {
  assert.equal(R.REVIEW_ROUTING.version, 2);
  assert.ok(R.REVIEW_ROUTING.examples.length >= 20);
  for (const x of R.REVIEW_ROUTING.examples) {
    const r = R.reviewClass({ paths: x.paths, labels: x.labels ?? [], override: x.override ?? null, ledger: R.ledgerPr({ body: x.body ?? "" }), renamed: x.renamed ?? false });
    assert.equal(r.cls, x.cls, JSON.stringify(x));
    if (x.why) assert.ok(r.why.startsWith(x.why) || r.why.includes(x.why), `${JSON.stringify(x)} -> ${r.why}`);
  }
});

test("D395 gate: a NORMAL PR lands on the GLM verdict; an IMPORTANT one still needs a GPT lane", () => {
  const normal = [file("scripts/tool.mjs")], important = [file("cli/cmd/modelplan/consent_scopes.go")];
  const mixed = [file("scripts/tool.mjs"), file("cli/internal/setup/oauth_flow.go")];
  // normal: the exact-head (ghglm) merge is enough; its block blocks; a stale-head GLM verdict is not enough
  const n = evalPr({ files: normal, comments: [comment(v("merge", H, "ghglm"))] });
  assert.equal(n.state, R.SUCCESS); assert.equal(n.review, R.NORMAL); assert.match(n.why, /D482 normal/);
  assert.equal(evalPr({ files: normal, comments: [comment(v("block", H, "ghglm"))] }).state, R.FAILURE);
  assert.equal(evalPr({ files: normal, comments: [comment(v("merge", "b".repeat(40), "ghglm"))] }).state, R.PENDING);
  // important (tier 2 here) and mixed (tier 1 + one token path): GLM is advice, a GPT lane decides
  for (const files of [important, mixed]) {
    const r = evalPr({ files, comments: [comment(v("merge", H, "ghglm"))] });
    assert.equal(r.state, R.PENDING); assert.equal(r.review, R.IMPORTANT);
    assert.equal(evalPr({ files, comments: [comment(v("merge", H, "ghglm")), comment(v("merge", H, "macrev2"))] }).state, R.SUCCESS);
  }
  // review:codex makes a normal PR important
  assert.equal(evalPr({ files: normal, p: pr({ labels: [{ name: "review:codex" }] }), comments: [comment(v("merge", H, "ghglm"))] }).state, R.PENDING);
});

test("D395 fallback: a NORMAL PR also lands on a Codex verdict, and a GLM verdict counts again on the next head (no sticky state)", () => {
  const normal = [file("scripts/tool.mjs")], H2 = "c".repeat(40);
  // GLM out at head A: a Codex lane reviewed it and became the sticky reviewer; its merge counts
  const codexA = [comment("REVIEWER: macrevb"), comment(v("merge", H, "macrevb"))];
  assert.equal(evalPr({ files: normal, comments: codexA }).state, R.SUCCESS);
  // GLM back at head B: the GLM verdict counts although macrevb is still assigned; a GLM block still blocks
  const atB = (extra) => evalPr({ files: normal, p: pr({ head: { ...pr().head, sha: H2 } }), comments: [...codexA, ...extra] });
  assert.equal(atB([comment(v("merge", H2, "ghglm"))]).state, R.SUCCESS);
  assert.equal(atB([comment(v("block", H2, "ghglm")), comment(v("merge", H2, "macrevb"))]).state, R.FAILURE);
  assert.equal(atB([]).state, R.PENDING);
  // on an IMPORTANT PR any Sol lane lands it too (D395 stateless), but never Terra or GLM outside a D366 fallback
  const imp = [file("cli/cmd/modelplan/consent_scopes.go")];
  assert.equal(evalPr({ files: imp, comments: [comment("REVIEWER: macrevb"), comment(v("merge", H, "ghsol"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ files: [file("cli/internal/setup/oauth_flow.go")], comments: [comment(v("merge", H, "macrevc"))] }).state, R.PENDING, "important tier 1: Terra does not admit");
  assert.equal(evalPr({ files: [file("cli/internal/quota/x.go")], comments: [comment(v("merge", H, "macrevc"))] }).state, R.PENDING, "D482: normal tier 2: Terra does not admit (D149)");
});

test("D396 sticky ghsol: the workflow pair accepts the GLM quota-fallback verdict wherever GLM may decide", () => {
  const pin = comment("REVIEWER: ghsol");
  // normal PR: counts
  assert.equal(evalPr({ files: [file("scripts/tool.mjs")], comments: [pin, comment(v("merge", H, "ghglm"))] }).state, R.SUCCESS);
  // D482: an important PR never lands on GLM, REVIEW_GLM_TIERS=1,2 (D366/D469) included
  const imp = [file("cli/cmd/modelplan/consent_scopes.go")];
  const ev = (glmTiers) => R.evaluatePr({ pr: pr(), items: R.feed([pin, comment(v("merge", H, "ghglm"))]), files: imp, runs: greenCi, statuses: [compileOk], verifiedEdge: () => false, conf, glmTiers });
  assert.equal(ev([1, 2]).state, R.PENDING);
  // important PR outside a fallback: GLM is advice
  assert.equal(ev([]).state, R.PENDING);
  assert.deepEqual(R.stickyLanes("(ghsol)", R.eligibleLanes(1, [], R.NORMAL)), ["(ghsol)", "(ghglm)"]);
  assert.deepEqual(R.stickyLanes("(ghsol)", R.eligibleLanes(1)), ["(ghsol)"]);
  assert.deepEqual(R.stickyLanes("(macrevb)", R.eligibleLanes(1, [], R.NORMAL)), ["(macrevb)"]);
});

test("D395-5/6: on a NORMAL PR no assignment pins a lane (a Codex verdict counts under a workflow sticky); any rename is IMPORTANT", () => {
  const normal = [file("scripts/tool.mjs")];
  assert.equal(evalPr({ files: normal, comments: [comment("REVIEWER: ghsol"), comment(v("merge", H, "macrevb"))] }).state, R.SUCCESS);
  assert.equal(evalPr({ files: normal, comments: [comment("REVIEWER: ghsol"), comment(v("block", H, "macrevb")), comment(v("merge", H, "ghglm"))] }).state, R.FAILURE, "any counting block blocks");
  // an important PR: no pin either (D395 stateless); any Sol lane's merge lands it
  assert.equal(evalPr({ files: [file("cli/cmd/modelplan/consent_scopes.go")], comments: [comment("REVIEWER: ghsol"), comment(v("merge", H, "macrevb"))] }).state, R.SUCCESS);
  // a rename out of an important area, or any rename at all, is important on both gates (the coordinator sees no old path)
  const mv = [file("cli/internal/metrics/frame.go", { status: "renamed", previous_filename: "cli/internal/appserver/frame.go" })];
  const r = evalPr({ files: mv, comments: [comment(v("merge", H, "ghglm"))] });
  assert.equal(r.review, R.IMPORTANT); assert.equal(r.state, R.PENDING);
  assert.equal(R.reviewClass({ paths: ["src/b.ts"], renamed: R.hasRename([{ filename: "src/b.ts", status: "renamed", previous_filename: "src/a.ts" }]) }).why, "renamed file");
});
