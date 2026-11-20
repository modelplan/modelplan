// SPDX-License-Identifier: MIT
// Dependency wake (throughput D352, change 5a). On every push to main, find the open pull requests (drafts included)
// whose body has a `Depends-on: #N` or `Blocked-by: #N` line naming a pull request that the push merged. When none of
// that pull request's named blockers is still unmerged, post ONE comment "Unblocked: #N merged at <sha>; ready to
// continue", deduplicated by a hidden marker. The local coordinator raises its own event from the same lines
// (stuck-scan.sh --unblocked), because a comment alone may sit unread.
//
// Read-only except for that comment: the token needs contents: read and pull-requests: write, nothing else. A body is
// untrusted text: it is only parsed for `#N` numbers here, never run or passed to a shell.
//
// Usage (workflow): GITHUB_TOKEN=... GITHUB_REPOSITORY=owner/repo node scripts/dependency-wake.mjs <before-sha> <after-sha>

const LINE = /^[ \t]*(?:[-*][ \t]+)?(?:depends-on|blocked-by)[ \t]*:[ \t]*(.*)$/gim;
export const MARKER = (pr, merged) => `<!-- dependency-wake:unblocked:${pr}:${merged} -->`;

/** Pull request numbers named by the Depends-on / Blocked-by lines of a body (sorted, unique). */
export function blockersOf(body) {
  const found = new Set();
  for (const m of String(body ?? "").matchAll(LINE)) {
    for (const n of m[1].matchAll(/(?:^|[^\w/])#(\d{1,7})\b/g)) found.add(Number(n[1]));
  }
  return [...found].sort((a, b) => a - b);
}

/**
 * What to do for one open PR after `mergedNow` (a Set of PR numbers) merged.
 * `isMerged(n)` says whether blocker n has merged (before or in this push). Returns null when the PR does not name a
 * merged PR of this push; otherwise { cleared: [..], remaining: [..] } (remaining empty = unblocked).
 */
export async function assess(body, mergedNow, isMerged) {
  const blockers = blockersOf(body);
  const cleared = blockers.filter((n) => mergedNow.has(n));
  if (!cleared.length) return null;
  const remaining = [];
  for (const n of blockers) if (!mergedNow.has(n) && !(await isMerged(n))) remaining.push(n);
  return { cleared, remaining };
}

export function commentText(prNumber, mergedPr, sha) {
  return `${MARKER(prNumber, mergedPr)}\nUnblocked: #${mergedPr} merged at ${sha.slice(0, 12)}; ready to continue`;
}

/** Run one wake. `api(method, path, body?)` returns parsed JSON (GET list pages are handled by `pages`). */
export async function wake({ api, pages, before, after, log = () => {} }) {
  const shas = new Set([after]);
  if (before && !/^0+$/.test(before)) {
    const cmp = await api("GET", `/compare/${before}...${after}?per_page=250`);
    for (const c of cmp.commits ?? []) shas.add(c.sha);
  }
  const merged = new Map(); // PR number -> merge commit sha
  for (const sha of shas) {
    for (const p of await api("GET", `/commits/${sha}/pulls`)) {
      if (p.merged_at && p.base?.ref === "main" && (p.merge_commit_sha === sha || sha === after)) merged.set(p.number, p.merge_commit_sha || sha);
    }
  }
  if (!merged.size) { log("no merged pull request in this push"); return []; }
  const mergedNow = new Set(merged.keys());
  const open = await pages("/pulls?state=open&per_page=100");
  const state = new Map();
  const isMerged = async (n) => {
    if (!state.has(n)) state.set(n, Boolean((await api("GET", `/pulls/${n}`)).merged_at));
    return state.get(n);
  };
  const posted = [];
  for (const pr of open) {
    const r = await assess(pr.body, mergedNow, isMerged);
    if (!r) continue;
    if (r.remaining.length) { log(`#${pr.number} still blocked by ${r.remaining.map((n) => `#${n}`).join(", ")}`); continue; }
    const last = r.cleared[r.cleared.length - 1];
    const marker = MARKER(pr.number, last);
    const comments = await pages(`/issues/${pr.number}/comments?per_page=100`);
    if (comments.some((c) => String(c.body ?? "").includes(marker))) { log(`#${pr.number} already told`); continue; }
    await api("POST", `/issues/${pr.number}/comments`, { body: commentText(pr.number, last, merged.get(last)) });
    log(`#${pr.number} unblocked by #${last}`);
    posted.push(pr.number);
  }
  return posted;
}

export function githubApi(repo, token, fetchImpl = fetch) {
  const base = `https://api.github.com/repos/${repo}`;
  const headers = { authorization: `Bearer ${token}`, accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28", "user-agent": "dependency-wake" };
  const api = async (method, path, body) => {
    const res = await fetchImpl(base + path, { method, headers: body ? { ...headers, "content-type": "application/json" } : headers, body: body ? JSON.stringify(body) : undefined });
    if (!res.ok) throw new Error(`${method} ${path}: ${res.status}`);
    return res.json();
  };
  const pages = async (path) => {
    const all = [];
    for (let page = 1; page <= 20; page++) {
      const rows = await api("GET", `${path}${path.includes("?") ? "&" : "?"}page=${page}`);
      all.push(...rows);
      if (rows.length < 100) break;
    }
    return all;
  };
  return { api, pages };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [before, after] = process.argv.slice(2);
  const { GITHUB_TOKEN: token, GITHUB_REPOSITORY: repo } = process.env;
  if (!token || !repo || !after) { console.error("usage: GITHUB_TOKEN= GITHUB_REPOSITORY= dependency-wake.mjs <before> <after>"); process.exit(2); }
  await wake({ ...githubApi(repo, token), before, after, log: (m) => console.log(m) });
}
