// Pins the plugins to a CLI release: writes cli-pin.json (version, release URL and the SHA-256 of
// each macOS/Linux archive, from the release's checksums.txt) into both plugins.
//   node scripts/pin-cli.mjs v0.5.10   pin that release
//   node scripts/pin-cli.mjs --check   the pins agree and match the release's checksums (CI)
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = fileURLToPath(new URL("..", import.meta.url));
const targets = ["claude-code/cli-pin.json", "codex/cli-pin.json"];
const keys = ["darwin_arm64", "darwin_amd64", "linux_arm64", "linux_amd64"];
const repo = "https://github.com/modelplan/modelplan/releases/download";

async function pinFor(tag) {
  const res = await fetch(`${repo}/${tag}/checksums.txt`);
  if (!res.ok) throw Error(`${tag}: checksums.txt ${res.status}`);
  const sums = Object.fromEntries((await res.text()).trim().split("\n").map(l => l.trim().split(/\s+/).reverse()));
  const sha256 = Object.fromEntries(keys.map(k => {
    const s = sums[`modelplan_${k}.tar.gz`];
    if (!/^[0-9a-f]{64}$/.test(s ?? "")) throw Error(`${tag}: no checksum for ${k}`);
    return [k, s];
  }));
  return { version: tag.replace(/^v/, ""), release: `${repo}/${tag}`, sha256 };
}

// One asset per line, so the hooks' POSIX sh can read it with sed.
const render = p => `{\n  "version": "${p.version}",\n  "release": "${p.release}",\n  "sha256": {\n${keys.map(k => `    "${k}": "${p.sha256[k]}"`).join(",\n")}\n  }\n}\n`;

const arg = process.argv[2];
if (arg === "--check") {
  const pins = await Promise.all(targets.map(t => readFile(path.join(root, t), "utf8")));
  if (new Set(pins).size !== 1) throw Error("the plugins pin different CLI releases");
  const pin = JSON.parse(pins[0]);
  if (render(await pinFor("v" + pin.version)) !== pins[0]) throw Error(`cli-pin.json does not match release v${pin.version}`);
  console.log(`CLI pin v${pin.version} matches its release`);
} else if (/^v\d+\.\d+\.\d+$/.test(arg ?? "")) {
  const text = render(await pinFor(arg));
  for (const t of targets) await writeFile(path.join(root, t), text);
  console.log(`pinned ${arg} in ${targets.join(", ")}`);
} else {
  console.error("usage: node scripts/pin-cli.mjs vX.Y.Z | --check");
  process.exit(2);
}
