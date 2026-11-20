// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { MARKER, blockersOf, wake } from "../dependency-wake.mjs";

test("blockers come from Depends-on and Blocked-by lines only", () => {
  assert.deepEqual(blockersOf("x\nDepends-on: #1104\nblocked-by: #7, modelplan/modelplan#9 and #8\n- Depends-on: #3"), [3, 7, 8, 1104]);
  assert.deepEqual(blockersOf("Mentions #5 in prose. See Depends-on: later\nnot a Depends-on: #6 line"), []);
  assert.deepEqual(blockersOf(null), []);
});

// A fake repository: merged = {n: sha}; open PRs with bodies; comments per PR.
function fake({ merged, open, comments = {}, pulls }) {
  const posted = [];
  const api = async (method, path, body) => {
    if (method === "POST") { const n = Number(path.match(/issues\/(\d+)\//)[1]); posted.push([n, body.body]); (comments[n] ??= []).push({ body: body.body }); return {}; }
    if (path.startsWith("/compare/")) return { commits: [{ sha: "c1" }] };
    let m = path.match(/^\/commits\/(\w+)\/pulls/);
    if (m) return (pulls[m[1]] ?? []);
    m = path.match(/^\/pulls\/(\d+)$/);
    if (m) return { merged_at: merged[m[1]] ? "2026-11-20T00:00:00Z" : null };
    throw new Error(path);
  };
  const pages = async (path) => path.startsWith("/pulls?") ? open : (comments[Number(path.match(/issues\/(\d+)\//)[1])] ?? []);
  return { api, pages, posted };
}
const mergedPull = (number, sha) => ({ number, merged_at: "t", base: { ref: "main" }, merge_commit_sha: sha });

test("one comment when the last blocker merges, none while another remains, none twice", async () => {
  const f = fake({
    merged: { 1104: true },
    pulls: { aaaa: [mergedPull(1104, "aaaa")] },
    open: [
      { number: 1096, body: "Depends-on: #1104" },
      { number: 1200, body: "Depends-on: #1104\nBlocked-by: #1300" },
      { number: 1201, body: "no deps" },
    ],
  });
  const logs = [];
  const run = () => wake({ api: f.api, pages: f.pages, before: "0".repeat(40), after: "aaaa", log: (m) => logs.push(m) });
  assert.deepEqual(await run(), [1096]);
  assert.equal(f.posted.length, 1);
  assert.match(f.posted[0][1], /^<!-- dependency-wake:unblocked:1096:1104 -->\nUnblocked: #1104 merged at aaaa; ready to continue$/);
  assert.ok(logs.some((l) => l.includes("#1200 still blocked by #1300")));
  assert.deepEqual(await run(), []); // deduped by the hidden marker
  assert.equal(f.posted.length, 1);
});

test("a blocker that merged earlier does not hold the PR back; a closed unmerged one does", async () => {
  const f = fake({
    merged: { 5: true, 6: false },
    pulls: { bbbb: [mergedPull(7, "bbbb")] },
    open: [{ number: 20, body: "Depends-on: #5, #7" }, { number: 21, body: "Blocked-by: #6\nBlocked-by: #7" }],
  });
  assert.deepEqual(await wake({ api: f.api, pages: f.pages, before: "", after: "bbbb" }), [20]);
});

test("a push that merged nothing, or a PR into another branch, wakes nobody", async () => {
  const f = fake({ merged: {}, pulls: { cccc: [{ number: 9, merged_at: "t", base: { ref: "other" }, merge_commit_sha: "cccc" }] }, open: [{ number: 1, body: "Depends-on: #9" }] });
  assert.deepEqual(await wake({ api: f.api, pages: f.pages, before: "", after: "cccc" }), []);
  assert.equal(MARKER(1, 2), "<!-- dependency-wake:unblocked:1:2 -->");
});
