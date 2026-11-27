// SPDX-License-Identifier: MIT
// Local push preflight (D481): runs only the cheap checks that matter for the diff against origin/main, one at a time,
// and on success writes <git-common-dir>/preflight/<HEAD sha>.ok for the push guard.
//   node scripts/preflight.mjs
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { basename, dirname, posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const STAMP_HEADER = "preflight v1";
const COCKPIT_UNIT = "desktop/tests/cockpit/unit/";
const LANGUAGE_AUDIT = `${COCKPIT_UNIT}host-strings.test.mjs`;
const stem = (p) => basename(p).replace(/\.(test\.)?[^.]+$/, "");

// Relative module paths a test file mentions: import/export-from, dynamic import and new URL('...', import.meta.url).
export function importedPaths(testPath, text) {
  const found = new Set();
  const re = /(?:from\s*|import\s*\(\s*|new\s+URL\(\s*)['"`](\.{1,2}\/[^'"`]+)['"`]/g;
  for (const m of text.matchAll(re)) found.add(posix.normalize(posix.join(posix.dirname(testPath), m[1])));
  return [...found];
}

// Pure selection. input: changed (repo-relative paths), cockpitTests {path: [imported paths]},
// scriptTests {path: file text}, goAvailable. Returns [{name, kind: "run"|"note", cmd?, args?, cwd?, note?}].
export function selectChecks({ changed, cockpitTests = {}, scriptTests = {}, goAvailable = false }) {
  const checks = [
    { name: "source policy", kind: "run", cmd: "node", args: ["scripts/check-source-policy.mjs"] },
    { name: "changelog fragments", kind: "run", cmd: "node", args: ["scripts/changelog.mjs", "--check"] },
  ];
  const changedSet = new Set(changed);
  const nodeTest = (name, files) => files.length && checks.push({ name, kind: "run", cmd: "node", args: ["--test", ...files] });

  if (changed.some((f) => f.startsWith("desktop/cockpit/") || f.startsWith(COCKPIT_UNIT))) {
    checks.push({ name: "cockpit language audit", kind: "run", cmd: "node", args: ["--test", LANGUAGE_AUDIT] });
    const related = Object.keys(cockpitTests)
      .filter((t) => t !== LANGUAGE_AUDIT)
      .filter((t) => {
        if (changedSet.has(t)) return true;
        const imports = cockpitTests[t].flatMap((p) => [p, ...changed.filter((c) => c.startsWith(`${p}/`))]);
        return imports.some((p) => changedSet.has(p)) || changed.some((c) => c.startsWith("desktop/cockpit/") && stem(c) === stem(t));
      })
      .sort();
    nodeTest("cockpit unit tests for changed files", related);
  }
  if (changed.some((f) => f.startsWith("scripts/") || f.startsWith(".github/"))) {
    const names = changed.filter((f) => f.startsWith("scripts/") || f.startsWith(".github/")).map((f) => basename(f));
    const related = Object.keys(scriptTests)
      .filter((t) => changedSet.has(t) || names.some((n) => n !== basename(t) && scriptTests[t].includes(n)))
      .sort();
    nodeTest("script tests for changed files", related);
  }
  const goFiles = changed.filter((f) => f.startsWith("cli/") && f.endsWith(".go"));
  if (goFiles.length) {
    if (goAvailable) {
      const pkgs = [...new Set(goFiles.map((f) => `./${posix.relative("cli", posix.dirname(f)) || "."}`))].sort();
      checks.push({ name: "go vet (changed packages)", kind: "run", cmd: "go", args: ["vet", ...pkgs], cwd: "cli" });
      checks.push({ name: "go test (changed packages)", kind: "run", cmd: "go", args: ["test", ...pkgs], cwd: "cli" });
    } else checks.push({ name: "go", kind: "note", note: "cli/** Go files changed; Go tests run in CI (go is not on PATH)" });
  }
  checks.push({ name: "swift", kind: "note", note: "Swift is never checked here (not available on Linux); it runs in Mac CI" });
  return checks;
}

const git = (args, cwd) => execFileSync("git", args, { cwd, encoding: "utf8" }).trim();

function main() {
  const root = git(["rev-parse", "--show-toplevel"], process.cwd());
  if (git(["status", "--porcelain"], root)) {
    console.error("preflight: refusing to run with uncommitted changes. Commit (or move them out) first; the stamp must describe a commit.");
    return 2;
  }
  const head = git(["rev-parse", "HEAD"], root);
  const base = git(["merge-base", "origin/main", "HEAD"], root);
  const changed = git(["diff", "--name-only", `${base}..HEAD`], root).split("\n").filter(Boolean);
  const list = (dir, ok) => (existsSync(resolve(root, dir)) ? readdirSync(resolve(root, dir)).filter(ok).map((f) => `${dir}${f}`) : []);
  const cockpitTests = Object.fromEntries(
    list(COCKPIT_UNIT, (f) => f.endsWith(".test.mjs")).map((t) => [t, importedPaths(t, readFileSync(resolve(root, t), "utf8"))]),
  );
  const scriptTests = Object.fromEntries(
    [...list("scripts/tests/", (f) => f.endsWith(".test.mjs")), ...list("scripts/", (f) => f.endsWith(".test.mjs"))].map((t) => [t, readFileSync(resolve(root, t), "utf8")]),
  );
  const goAvailable = spawnSync("go", ["version"], { stdio: "ignore" }).status === 0;
  const checks = selectChecks({ changed, cockpitTests, scriptTests, goAvailable });
  console.log(`preflight: ${changed.length} changed file(s) vs ${base.slice(0, 9)} (merge-base with origin/main), HEAD ${head.slice(0, 9)}`);
  const ran = [];
  let failed = 0;
  for (const c of checks) {
    if (c.kind === "note") { console.log(`NOTE  ${c.name}: ${c.note}`); continue; }
    const label = `${c.name}: ${[c.cmd, ...c.args].join(" ")}`;
    const r = spawnSync(c.cmd, c.args, { cwd: resolve(root, c.cwd ?? "."), encoding: "utf8" });
    if (r.status === 0) { console.log(`PASS  ${label}`); ran.push(label); }
    else {
      failed++;
      console.log(`FAIL  ${label}`);
      process.stdout.write(`${r.stdout ?? ""}${r.stderr ?? ""}${r.error ? `${r.error.message}\n` : ""}`.split("\n").slice(-40).join("\n"));
    }
  }
  if (failed) { console.error(`preflight: ${failed} check(s) failed; no stamp written`); return 1; }
  const dir = resolve(root, git(["rev-parse", "--git-common-dir"], root), "preflight");
  mkdirSync(dir, { recursive: true });
  writeFileSync(resolve(dir, `${head}.ok`), `${STAMP_HEADER}\n${ran.join("\n")}\n`);
  console.log(`preflight: all ${ran.length} check(s) passed; stamp ${resolve(dir, `${head}.ok`)}`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main());
