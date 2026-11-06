// SPDX-License-Identifier: MIT
// Minimal GitHub REST client for the merge-queue gate (built-in fetch, no dependencies).
export function client({ token, repo, api = "https://api.github.com" }) {
  const headers = { accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28", "user-agent": "modelplan-merge-gates" };
  if (token) headers.authorization = `Bearer ${token}`;
  async function req(method, path, body) {
    const url = path.startsWith("http") ? path : `${api}/repos/${repo}${path}`;
    for (let attempt = 0; ; attempt++) {
      const r = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
      if (r.status >= 500 && attempt < 2) { await new Promise((ok) => setTimeout(ok, 2000 * (attempt + 1))); continue; }
      if (!r.ok) throw new Error(`${method} ${path}: HTTP ${r.status} ${(await r.text()).slice(0, 200)}`);
      return { json: r.status === 204 ? null : await r.json(), link: r.headers.get("link") ?? "" };
    }
  }
  const get = async (path) => (await req("GET", path)).json;
  // Follows rel="next"; `key` picks the array out of an object page (e.g. workflow_runs).
  async function all(path, key, max = 3000) {
    const out = [];
    let next = path + (path.includes("?") ? "&" : "?") + "per_page=100";
    while (next && out.length < max) {
      const { json, link } = await req("GET", next);
      out.push(...(key ? json[key] : json));
      next = /<([^>]+)>;\s*rel="next"/.exec(link)?.[1] ?? null;
    }
    return out;
  }
  const post = async (path, body) => (await req("POST", path, body)).json;
  return { get, all, post };
}
