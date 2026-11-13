// Pins the plugins and Skill to a CLI release: writes cli-pin.json (version, release URL and the SHA-256 of
// each macOS/Linux archive, from the release's checksums.txt), including bundled Skill copies, and moves
// the plugins' own versions up when the pin changes, so that plugin updates carry it to users.
//   node scripts/pin-cli.mjs v0.5.10   pin that release
//   node scripts/pin-cli.mjs --check   the pins agree and match the release's checksums, and a pin
//                                      changed since HEAD^1 came with new plugin versions (CI)
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { bumpPlugins, missedBumps, pluginVersions } from "./plugin-versions.mjs";
import { releaseAssetText } from "./release-asset.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const targets = ["claude-code/cli-pin.json", "codex/cli-pin.json", "skills/model-plan/cli-pin.json", "claude-code/skills/model-plan/cli-pin.json", "codex/skills/model-plan/cli-pin.json"];
const keys = ["darwin_arm64", "darwin_amd64", "linux_arm64", "linux_amd64"];
const repo = "https://github.com/modelplan/modelplan/releases/download";

async function pinFor(tag) {
  const text = await releaseAssetText("modelplan/modelplan", tag, "checksums.txt");
  const sums = Object.fromEntries(text.trim().split("\n").map(l => l.trim().split(/\s+/).reverse()));
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
  if (new Set(pins).size !== 1) throw Error("the plugins and Skill pin different CLI releases");
  const pin = JSON.parse(pins[0]);
  if (render(await pinFor("v" + pin.version)) !== pins[0]) throw Error(`cli-pin.json does not match release v${pin.version}`);
  // On a pull request's merge commit, and on a push to main, HEAD^1 is the base.
  const base = f => execFileSync("git", ["show", `HEAD^1:${f}`], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  const missed = missedBumps(JSON.parse(base(targets[0])).version, pin.version, pluginVersions(base), pluginVersions(f => readFileSync(path.join(root, f), "utf8")));
  if (missed.length) throw Error(`the CLI pin moved to v${pin.version} but these keep their version, so plugin updates would not deliver it: ${missed.join(", ")}`);
  console.log(`CLI pin v${pin.version} matches its release`);
} else if (/^v\d+\.\d+\.\d+$/.test(arg ?? "")) {
  const text = render(await pinFor(arg));
  const moved = JSON.parse(await readFile(path.join(root, targets[0]), "utf8")).version !== arg.slice(1);
  for (const t of targets) await writeFile(path.join(root, t), text);
  if (moved) await bumpPlugins(root);
  console.log(`pinned ${arg} in ${targets.join(", ")}${moved ? "; plugin versions moved up" : ""}`);
} else {
  console.error("usage: node scripts/pin-cli.mjs vX.Y.Z | --check");
  process.exit(2);
}
