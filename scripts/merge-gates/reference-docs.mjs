// SPDX-License-Identifier: MIT
// Per-directory AGENTS.md / CLAUDE.md for every area in reference-map.json, so coding agents see the reference rule
// while they write, not only when the merge gate runs. The text is generated from the map; a merge-gates test fails
// when a file is missing or differs.
//   node scripts/merge-gates/reference-docs.mjs --write    regenerate the files
//   node scripts/merge-gates/reference-docs.mjs            list the files that are missing or stale
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import referenceMap from "./reference-map.json" with { type: "json" };

export const CLAUDE_MD = "@AGENTS.md\n";

// dir -> groups mapped to it
export function mappedDirs(map = referenceMap) {
  const out = new Map();
  for (const g of map.groups) for (const d of g.dirs ?? []) out.set(d, [...(out.get(d) ?? []), g]);
  return out;
}

export function renderAgentsMd(groups, map = referenceMap) {
  const apps = (g) => g.apps.map((a) => `${a} (${map.repos[a]})`).join(", ");
  const follow = groups.length === 1
    ? [`Behaviour here (${groups[0].hint}) follows ${groups[0].apps.join(", ")}.`, `Where to read them: ${apps(groups[0])}.`]
    : ["Some files here follow a reference app, depending on the area:", ...groups.map((g) => `- ${g.name}: ${g.hint}. Follows ${g.apps.join(", ")}. Read them at ${apps(g)}.`)];
  return [
    "# Reference first",
    "",
    ...follow,
    "Before changing that behaviour, read how the reference does it at a pinned commit or tag, copy the behaviour (own code unless the licence and docs/readers/integration-standard.md section 3 allow a port), and put `Reference: <app>@<commit-or-tag> <path>` in the PR body, or `Reference: none (<reason of 20+ characters>)` when you deviate on purpose.",
    "The merge gate checks this. Check locally before you push: `node scripts/merge-gates/check-reference.mjs --diff origin/main --body <file with the PR body>`.",
    "Generated from scripts/merge-gates/reference-map.json (`node scripts/merge-gates/reference-docs.mjs --write`); do not edit by hand.",
    "",
  ].join("\n");
}

export function expectedFiles(map = referenceMap) {
  const files = new Map();
  for (const [dir, groups] of mappedDirs(map)) {
    files.set(`${dir}/AGENTS.md`, renderAgentsMd(groups, map));
    files.set(`${dir}/CLAUDE.md`, CLAUDE_MD);
  }
  return files;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL("../../", import.meta.url));
  const write = process.argv.includes("--write");
  let stale = 0;
  for (const [path, text] of expectedFiles()) {
    const full = join(root, path);
    if (existsSync(full) && readFileSync(full, "utf8") === text) continue;
    if (write) writeFileSync(full, text); else { console.log(`stale or missing: ${path}`); stale++; }
  }
  process.exit(stale ? 1 : 0);
}
