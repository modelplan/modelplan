// Fetches a small text asset (checksums) from a GitHub release. The download host
// (github.com/<repo>/releases/download/...) sometimes answers 5xx for every repository at once; the
// REST asset endpoint keeps working then. So: try the download URL a few times, then fall back to
// api.github.com (releases/tags/<tag> -> asset id -> application/octet-stream). Same bytes either way;
// callers still verify the content (hex checksums), so the fallback cannot weaken a pin check.
// A token in GITHUB_TOKEN or GH_TOKEN is used for the API when present (higher rate limit); without one
// the anonymous limit (60/h per IP) is plenty for a CI check.
const sleep = ms => new Promise(r => setTimeout(r, ms));

export async function releaseAssetText(repo, tag, name, { attempts = 3, fetchImpl = fetch, wait = sleep } = {}) {
  const direct = `https://github.com/${repo}/releases/download/${tag}/${name}`;
  let last = "";
  for (let i = 0; i < attempts; i++) {
    const res = await fetchImpl(direct);
    if (res.ok) return await res.text();
    last = `${res.status}`;
    if (res.status < 500 && res.status !== 429) throw Error(`${tag}: ${name} ${res.status}`);
    if (i < attempts - 1) await wait(1000 * 2 ** i);
  }
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  const auth = token ? { authorization: `Bearer ${token}` } : {};
  const rel = await fetchImpl(`https://api.github.com/repos/${repo}/releases/tags/${tag}`, { headers: { accept: "application/vnd.github+json", ...auth } });
  if (!rel.ok) throw Error(`${tag}: ${name} ${last} (download), release lookup ${rel.status} (API)`);
  const asset = (await rel.json()).assets?.find(a => a.name === name);
  if (!asset) throw Error(`${tag}: ${name} ${last} (download), not among the release assets (API)`);
  const res = await fetchImpl(asset.url, { headers: { accept: "application/octet-stream", ...auth } });
  if (!res.ok) throw Error(`${tag}: ${name} ${last} (download), ${res.status} (API)`);
  return await res.text();
}
