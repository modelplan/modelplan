// SPDX-License-Identifier: MIT
// Local version of the merge gate's reference rule (D239), same logic as rules.mjs, to run before pushing:
//   node scripts/merge-gates/check-reference.mjs --diff origin/main --body <file with the PR body>
// Exit 0: the diff touches no mapped area, or the body declares an allowed reference. Exit 1: it says what is missing.
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { referenceGroups, referenceProblem } from "./rules.mjs";

const argv = process.argv.slice(2);
const flag = (n) => { const i = argv.indexOf(n); return i < 0 ? null : argv[i + 1] ?? null; };
const base = flag("--diff");
const bodyFile = flag("--body");
if (!base) { console.error("usage: check-reference.mjs --diff <base> [--body <file>]"); process.exit(2); }

const out = execFileSync("git", ["diff", "--name-status", "-M", "-z", `${base}...HEAD`], { encoding: "utf8" }).split("\0").filter(Boolean);
const paths = [];
for (let i = 0; i < out.length;) {
  const status = out[i++];
  const n = /^[RC]/.test(status) ? 2 : 1;
  paths.push(...out.slice(i, i + n));  // renamed-from paths count, like the gate
  i += n;
}
const body = bodyFile ? readFileSync(bodyFile, "utf8") : "";
const groups = referenceGroups(paths).map((g) => g.name);
const problem = referenceProblem({ body }, paths);
if (problem) { console.error(`Reference check: ${problem}`); process.exit(1); }
console.log(groups.length ? `Reference check: ok (${groups.join(", ")})` : "Reference check: no mapped area touched");
