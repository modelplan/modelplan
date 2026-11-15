// The plugins' own versions, which must move whenever their CLI pin does: `claude plugin update`
// and Codex's marketplace upgrade compare these, so a new pin under an old version reaches nobody.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

// Each file with how many leading "version" lines name the plugin (package-lock.json has two).
const files = [["claude-code/.claude-plugin/plugin.json", 1], ["codex/.codex-plugin/plugin.json", 1], ["codex/package.json", 1], ["codex/package-lock.json", 2]];
const line = /"version": "(\d+)\.(\d+)\.(\d+)"/g;

export const pluginVersions = text => Object.fromEntries(files.map(([f]) => [f, JSON.parse(text(f)).version]));

// Moves every plugin version up one patch release.
export async function bumpPlugins(root) {
  for (const [f, count] of files) {
    const p = path.join(root, f);
    let left = count;
    const text = (await readFile(p, "utf8")).replace(line, (m, a, b, c) => (left-- > 0 ? `"version": "${a}.${b}.${+c + 1}"` : m));
    await writeFile(p, text);
  }
}

// The files whose version did not move although the pin did.
export function missedBumps(basePin, pin, baseVersions, versions) {
  if (basePin === pin) return [];
  return Object.keys(versions).filter(f => versions[f] === baseVersions[f]);
}
