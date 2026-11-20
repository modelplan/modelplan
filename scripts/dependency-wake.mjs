// SPDX-License-Identifier: MIT
// Dependency wake (throughput D352, change 5a). On every push to main, reconcile the open pull requests (drafts included)
// whose body has a `Depends-on: #N` or `Blocked-by: #N` line: when every named pull request has merged (the last one within
// the last 72 hours), post ONE comment "Unblocked: #N merged at <sha>; ready to continue" on that pull request. The local
// coordinator raises its own event from the same lines (stuck-scan.sh --unblocked), because a comment alone may sit unread.
//
// The decision reads the current state of GitHub, never the range of one push, so a run that GitHub replaced in its
// concurrency queue loses nothing: the next run sees the same pull requests. A reference that cannot be read (mistyped,
// deleted) keeps that one pull request blocked and never stops the others. The "already told" marker names the pull
// request and its exact blocker set and counts only when the comment was posted by this workflow's token (a bot), so a
// human quoting it does not suppress the notice and a pull request whose blockers merged in separate pushes is told once.
//
// Read-only except for that comment: the token needs contents: read and pull-requests: write, nothing else. A body is
// untrusted text: it is only parsed for `#N` numbers here, never run or passed to a shell.
//
// Usage (workflow): GITHUB_TOKEN=... GITHUB_REPOSITORY=owner/repo node scripts/dependency-wake.mjs

const LINE = /^[ \t]*(?:[-*][ \t]+)?(?:depends-on|blocked-by)[ \t]*:[ \t]*(.*)$/gim;
export const WINDOW_HOURS = 72;
export const MARKER = (pr, blockers) => `<!-- dependency-wake:unblocked:${pr}:${blockers.join(",")} -->`;

/** Pull request numbers named by the Depends-on / Blocked-by lines of a body (sorted, unique). */
export function blockersOf(body) {
  const found = new Set();
  for (const m of String(body ?? "").matchAll(LINE)) {
    for (const n of m[1].matchAll(/(?:^|[^\w/])#(\d{1,7})\b/g)) found.add(Number(n[1]));
  }
  return [...found].sort((a, b) => a - b);
}

export function commentText(prNumber, blockers, last) {
  return `${MARKER(prNumber, blockers)}\nUnblocked: #${last.number} merged at ${last.sha.slice(0, 12)}; ready to continue`;
}

/** A comment counts as this workflow's own notice only when a bot posted it and it starts with the marker. */
export function isOurNotice(comment, marker) {
  return comment?.user?.type === "Bot" && String(comment.body ?? "").startsWith(marker);
}

/** Run one reconcile. `api(method, path, body?)` returns parsed JSON; `pages(path)` lists every page. */
export async function wake({ api, pages, now = Date.now(), log = () => {} }) {
  const open = await pages("/pulls?state=open&per_page=100");
  const cache = new Map();
  const blocker = async (n) => { // { merged, at, sha } or null when it cannot be read
    if (!cache.has(n)) {
      try {
        const p = await api("GET", `/pulls/${n}`);
        cache.set(n, { merged: Boolean(p.merged_at), at: p.merged_at ? Date.parse(p.merged_at) : 0, sha: p.merge_commit_sha || "" });
      } catch (e) { log(`#${n}: ${e.message}`); cache.set(n, null); }
    }
    return cache.get(n);
  };
  const posted = [];
  for (const pr of open) {
    const blockers = blockersOf(pr.body);
    if (!blockers.length) continue;
    try {
      const infos = [];
      for (const n of blockers) infos.push([n, await blocker(n)]);
      const waiting = infos.filter(([, i]) => !i || !i.merged).map(([n]) => n);
      if (waiting.length) { log(`#${pr.number} still blocked by ${waiting.map((n) => `#${n}`).join(", ")}`); continue; }
      const [number, last] = infos.reduce((a, b) => (b[1].at > a[1].at ? b : a));
      if (now - last.at > WINDOW_HOURS * 3600e3) continue; // long unblocked: nobody is waiting for this news
      const marker = MARKER(pr.number, blockers);
      const comments = await pages(`/issues/${pr.number}/comments?per_page=100`);
      if (comments.some((c) => isOurNotice(c, marker))) { log(`#${pr.number} already told`); continue; }
      await api("POST", `/issues/${pr.number}/comments`, { body: commentText(pr.number, blockers, { number, sha: last.sha }) });
      log(`#${pr.number} unblocked by #${number}`);
      posted.push(pr.number);
    } catch (e) { log(`#${pr.number}: ${e.message}`); } // one pull request never stops the others
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
  const { GITHUB_TOKEN: token, GITHUB_REPOSITORY: repo } = process.env;
  if (!token || !repo) { console.error("usage: GITHUB_TOKEN= GITHUB_REPOSITORY= dependency-wake.mjs"); process.exit(2); }
  await wake({ ...githubApi(repo, token), log: (m) => console.log(m) });
}
