// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { MARKER, blockersOf, wake } from "../dependency-wake.mjs";

test("blockers come from Depends-on and Blocked-by lines only", () => {
  assert.deepEqual(blockersOf("x\nDepends-on: #1104\nblocked-by: #7, modelplan/modelplan#9 and #8\n- Depends-on: #3"), [3, 7, 8, 1104]);
  assert.deepEqual(blockersOf("Mentions #5 in prose. See Depends-on: later\nnot a Depends-on: #6 line"), []);
  assert.deepEqual(blockersOf(null), []);
});

const NOW = Date.parse("2026-11-20T12:00:00Z");
const hoursAgo = (h) => new Date(NOW - h * 3600e3).toISOString();
// prs: { n: { merged_at?, sha? } }; a number missing from prs answers 404. open: PRs; comments: { pr: [...] }.
function fake({ prs, open, comments = {} }) {
  const posted = [];
  const api = async (method, path, body) => {
    if (method === "POST") { const n = Number(path.match(/issues\/(\d+)\//)[1]); posted.push([n, body.body]); (comments[n] ??= []).push({ body: body.body, user: { type: "Bot", login: "github-actions[bot]" } }); return {}; }
    const m = path.match(/^\/pulls\/(\d+)$/);
    if (!m) throw new Error(path);
    if (!prs[m[1]]) throw new Error(`GET ${path}: 404`);
    return { merged_at: prs[m[1]].merged_at ?? null, merge_commit_sha: prs[m[1]].sha ?? "", base: { ref: prs[m[1]].base ?? "main" } };
  };
  const pages = async (path) => path.startsWith("/pulls?") ? open : (comments[Number(path.match(/issues\/(\d+)\//)[1])] ?? []);
  return { api, pages, posted };
}
const run = (f, logs = []) => wake({ api: f.api, pages: f.pages, now: NOW, log: (m) => logs.push(m) });

test("one notice when the last blocker has merged, none while one remains or is closed unmerged, none twice", async () => {
  const f = fake({
    prs: { 1104: { merged_at: hoursAgo(1), sha: "abcdef0123456789" }, 1300: {} },
    open: [{ number: 1096, body: "Depends-on: #1104" }, { number: 1200, body: "Depends-on: #1104\nBlocked-by: #1300" }, { number: 1201, body: "no deps" }],
  });
  const logs = [];
  assert.deepEqual(await run(f, logs), [1096]);
  assert.match(f.posted[0][1], /^<!-- dependency-wake:unblocked:1096:1104 -->\nUnblocked: #1104 merged at abcdef012345; ready to continue$/);
  assert.ok(logs.some((l) => l.includes("#1200 still blocked by #1300")));
  assert.deepEqual(await run(f), []);
  assert.equal(f.posted.length, 1);
});

test("macrev2-1105-2: blockers merged in separate pushes give one notice, naming the last merge, in any run order", async () => {
  const f = fake({ prs: { 1: { merged_at: hoursAgo(5), sha: "aaaaaaaaaaaaaa" }, 2: { merged_at: hoursAgo(1), sha: "bbbbbbbbbbbbbb" } }, open: [{ number: 9, body: "Depends-on: #1\nDepends-on: #2" }] });
  assert.deepEqual(await run(f), [9]);
  assert.deepEqual(await run(f), []);
  assert.match(f.posted[0][1], /Unblocked: #2 merged at bbbbbbbbbbbb/);
});

test("macrev2-1105-1: the decision reads the current state, so a skipped run loses nothing", async () => {
  // Pushes P1 and P2 merged #1 and #2; the run for P1 was replaced in the concurrency queue. The run for P3 still wakes both dependents.
  const f = fake({ prs: { 1: { merged_at: hoursAgo(3), sha: "a" }, 2: { merged_at: hoursAgo(2), sha: "b" } }, open: [{ number: 10, body: "Depends-on: #1" }, { number: 11, body: "Depends-on: #2" }] });
  assert.deepEqual(await run(f), [10, 11]);
});

test("macrev2-1105-3: an unreadable reference keeps only that PR blocked; later PRs are still told", async () => {
  const f = fake({ prs: { 5: { merged_at: hoursAgo(1), sha: "c" } }, open: [{ number: 20, body: "Depends-on: #5, #999" }, { number: 21, body: "Depends-on: #5" }] });
  const logs = [];
  assert.deepEqual(await run(f, logs), [21]);
  assert.ok(logs.some((l) => l.includes("#20 still blocked by #999")));
});

test("macrev2-1105-4: a human quoting the marker does not suppress the notice; the workflow's own notice does", async () => {
  const comments = { 30: [{ body: MARKER(30, [5]), user: { type: "User" } }] };
  const f = fake({ prs: { 5: { merged_at: hoursAgo(1), sha: "d" } }, open: [{ number: 30, body: "Blocked-by: #5" }], comments });
  assert.deepEqual(await run(f), [30]);
  assert.deepEqual(await run(f), []);
});

test("macrev2-1105-4: a marker from another App bot does not suppress the notice", async () => {
  const comments = { 31: [{ body: MARKER(31, [5]), user: { type: "Bot", login: "some-other-app[bot]" } }] };
  const f = fake({ prs: { 5: { merged_at: hoursAgo(1), sha: "d" } }, open: [{ number: 31, body: "Blocked-by: #5" }], comments });
  assert.deepEqual(await run(f), [31]);
  assert.deepEqual(await run(f), []);
});

test("macrev2-1105-5: a dependency merged only into another base never wakes; one merged to main still does", async () => {
  const f = fake({ prs: { 5: { merged_at: hoursAgo(1), sha: "a", base: "release" }, 6: { merged_at: hoursAgo(1), sha: "b" } }, open: [{ number: 50, body: "Depends-on: #5" }, { number: 51, body: "Depends-on: #6" }] });
  assert.deepEqual(await run(f), [51]);
});

test("a blocker that merged long ago does not produce news, and a changed blocker set is told again", async () => {
  const f = fake({ prs: { 6: { merged_at: hoursAgo(200), sha: "e" }, 7: { merged_at: hoursAgo(1), sha: "f" } }, open: [{ number: 40, body: "Depends-on: #6" }] });
  assert.deepEqual(await run(f), []);
  f.pages = async (p) => p.startsWith("/pulls?") ? [{ number: 40, body: "Depends-on: #6\nDepends-on: #7" }] : [{ body: MARKER(40, [6]), user: { type: "Bot", login: "github-actions[bot]" } }];
  assert.deepEqual(await run(f), [40]);
});
