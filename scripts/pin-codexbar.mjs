// Pins the CodexBar CLI release the modelplan CLI fetches for `modelplan codexbar`: writes
// cli/internal/quota/codexbar-pin.json from the release's per-archive .sha256 files.
//   node scripts/pin-codexbar.mjs v0.76.0   pin that release
//   node scripts/pin-codexbar.mjs --latest  pin the latest release (prints "unchanged" if pinned)
//   node scripts/pin-codexbar.mjs --check   the pin matches its release's checksums
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const file = path.join(fileURLToPath(new URL("..", import.meta.url)), "cli/internal/quota/codexbar-pin.json");
const repo = "steipete/CodexBar";
const assets = { "darwin/arm64": "macos-arm64", "darwin/amd64": "macos-x86_64", "linux/arm64": "linux-aarch64", "linux/amd64": "linux-x86_64" };

async function pinFor(tag) {
  const v = tag.replace(/^v/, "");
  const rows = await Promise.all(Object.entries(assets).map(async ([plat, suffix]) => {
    const name = `CodexBarCLI-v${v}-${suffix}.tar.gz`;
    const res = await fetch(`https://github.com/${repo}/releases/download/v${v}/${name}.sha256`);
    if (!res.ok) throw Error(`${tag}: ${name}.sha256 ${res.status}`);
    const [sum, listed] = (await res.text()).trim().split(/\s+/);
    if (!/^[0-9a-f]{64}$/.test(sum) || (listed && listed !== name)) throw Error(`${tag}: bad checksum line for ${name}`);
    return [plat, [suffix, sum]];
  }));
  return { version: v, release: `https://github.com/${repo}/releases/tag/v${v}`, assets: Object.fromEntries(rows) };
}

const render = p => `{\n  "version": "${p.version}",\n  "release": "${p.release}",\n  "assets": {\n${Object.keys(assets).map(k => `    "${k}": ["${p.assets[k][0]}", "${p.assets[k][1]}"]`).join(",\n")}\n  }\n}\n`;

const arg = process.argv[2];
const current = await readFile(file, "utf8");
if (arg === "--check") {
  const pin = JSON.parse(current);
  if (render(await pinFor("v" + pin.version)) !== current) throw Error(`codexbar-pin.json does not match CodexBar v${pin.version}`);
  console.log(`CodexBar pin v${pin.version} matches its release`);
} else if (arg === "--latest" || /^v\d+\.\d+\.\d+$/.test(arg ?? "")) {
  let tag = arg;
  if (arg === "--latest") {
    const res = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, { headers: { accept: "application/vnd.github+json" } });
    if (!res.ok) throw Error(`latest release: ${res.status}`);
    tag = (await res.json()).tag_name;
  }
  const text = render(await pinFor(tag));
  if (text === current) console.log("unchanged");
  else { await writeFile(file, text); console.log(`pinned CodexBar ${tag}`); }
} else {
  console.error("usage: node scripts/pin-codexbar.mjs vX.Y.Z | --latest | --check");
  process.exit(2);
}
