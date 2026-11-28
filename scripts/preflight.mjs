// SPDX-License-Identifier: MIT
// Local push preflight (D481): runs only the cheap checks that matter for the diff against origin/main, one at a time,
// and on success writes <git-common-dir>/preflight/<HEAD sha>.ok for the push guard.
//   node scripts/preflight.mjs
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { basename, dirname, posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const STAMP_HEADER = "preflight v1";
const COCKPIT_UNIT = "desktop/tests/cockpit/unit/";
const LANGUAGE_AUDIT = `${COCKPIT_UNIT}host-strings.test.mjs`;
const stem = (p) => basename(p).replace(/\.(test\.)?[^.]+$/, "");

// Relative module paths a test file mentions: import/export-from, dynamic import and new URL('...', import.meta.url).
export function importedPaths(testPath, text) {
  const found = new Set();
  const re = /(?:from\s*|import\s*\(?\s*|new\s+URL\(\s*)['"`](\.{1,2}\/[^'"`]+)['"`]/g;
  for (const m of text.matchAll(re)) {
    const p = posix.normalize(posix.join(posix.dirname(testPath), m[1]));
    found.add(p);
    // The cockpit compiles to <cockpit>/.tmp/compiled/<src path>.js (tsconfig rootDir "."): map back to the TypeScript source.
    const c = p.match(/^(.*?)\/\.tmp\/compiled\/(.+)\.js$/);
    if (c) found.add(`${c[1]}/${c[2]}.ts`);
  }
  return [...found];
}

// Pure selection. input: changed (repo-relative paths), cockpitTests {path: [imported paths]},
// scriptTests {path: file text}, goAvailable. Returns [{name, kind: "run"|"note", cmd?, args?, cwd?, note?}].
export function selectChecks({ changed, cockpitTests = {}, scriptTests = {}, goAvailable = false, cockpitDepsInstalled = true, goExistingDirs = null, goImporters = {} }) {
  const checks = [
    { name: "source policy", kind: "run", cmd: "node", args: ["scripts/check-source-policy.mjs"] },
    { name: "changelog fragments", kind: "run", cmd: "node", args: ["scripts/changelog.mjs", "--check"] },
  ];
  const changedSet = new Set(changed);
  const nodeTest = (name, files) => files.length && checks.push({ name, kind: "run", cmd: "node", args: ["--test", ...files] });

  if (changed.some((f) => f.startsWith("desktop/cockpit/") || f.startsWith(COCKPIT_UNIT))) {
    // Unit tests import the compiled output; rebuild it from this commit's TypeScript (what `npm test` does) so a missing
    // build cannot fail and a stale ignored build cannot pass.
    const cockpit = "desktop/cockpit";
    if (!cockpitDepsInstalled) checks.push({ name: "cockpit dependencies", kind: "run", cmd: "npm", args: ["ci", "--ignore-scripts"], cwd: cockpit });
    checks.push({ name: "cockpit wire check", kind: "run", cmd: "node", args: ["generate-wire.mjs", "--check"], cwd: cockpit });
    checks.push({ name: "cockpit livery check", kind: "run", cmd: "node", args: ["sync-livery.mjs", "--check"], cwd: cockpit });
    checks.push({ name: "cockpit compile", kind: "run", cmd: "node", args: ["node_modules/typescript/bin/tsc"], cwd: cockpit, clean: `${cockpit}/.tmp/compiled` });
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
      const dirOf = (f) => posix.relative("cli", posix.dirname(f)) || ".";
      const changedDirs = new Set(goFiles.map(dirOf));
      const exists = (d) => (goExistingDirs ? goExistingDirs.has(d) : true);
      const gone = [...changedDirs].filter((d) => !exists(d));
      // Surviving packages that import a deleted package must still build.
      const importers = Object.entries(goImporters).filter(([d, imps]) => exists(d) && imps.some((i) => gone.includes(i))).map(([d]) => d);
      const pkgs = [...new Set([...changedDirs].filter(exists).concat(importers))].sort().map((d) => (d === "." ? "." : `./${d}`));
      if (pkgs.length) {
        checks.push({ name: "go vet (changed packages)", kind: "run", cmd: "go", args: ["vet", ...pkgs], cwd: "cli" });
        checks.push({ name: "go test (changed packages)", kind: "run", cmd: "go", args: ["test", ...pkgs], cwd: "cli" });
      } else checks.push({ name: "go", kind: "note", note: "only deleted Go packages changed and nothing imports them" });
    } else checks.push({ name: "go", kind: "note", note: "cli/** Go files changed; Go tests run in CI (go is not on PATH)" });
  }
  checks.push({ name: "swift", kind: "note", note: "Swift is never checked here (not available on Linux); it runs in Mac CI" });
  return checks;
}

const git = (args, cwd) => execFileSync("git", args, { cwd, encoding: "utf8" }).trim();

// Go directories (relative to cli/) present in the tree, and for each the cli packages it imports.
function goInfo(root) {
  const files = git(["ls-files", "cli"], root).split("\n").filter((f) => f.endsWith(".go"));
  const mod = (readFileSync(resolve(root, "cli/go.mod"), "utf8").match(/^module\s+(\S+)/m) || [])[1];
  const goExistingDirs = new Set();
  const goImporters = {};
  for (const f of files) {
    const d = posix.relative("cli", posix.dirname(f)) || ".";
    goExistingDirs.add(d);
    if (!mod) continue;
    const text = readFileSync(resolve(root, f), "utf8");
    const set = (goImporters[d] ??= []);
    for (const m of text.matchAll(new RegExp(`"${mod.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:/([^"]+))?"`, "g"))) set.push(m[1] ?? ".");
  }
  return { goExistingDirs, goImporters };
}

// Runs fn(snapshotDir) inside a temporary detached worktree of exactly `sha`, and always removes it. Checks read this
// snapshot, never the user's worktree, so the user can switch branches mid-run and the receipt still describes `sha`.
export function withSnapshot(root, sha, fn) {
  const common = resolve(root, git(["rev-parse", "--git-common-dir"], root));
  const snap = resolve(common, "preflight", `snap-${sha.slice(0, 12)}-${process.pid}`);
  mkdirSync(dirname(snap), { recursive: true });
  git(["worktree", "add", "--detach", "--force", snap, sha], root);
  try {
    return fn(snap);
  } finally {
    try { git(["worktree", "remove", "--force", snap], root); } catch { /* fall through */ }
    rmSync(snap, { recursive: true, force: true });
    try { git(["worktree", "prune"], root); } catch { /* best effort */ }
  }
}

function main() {
  const root = git(["rev-parse", "--show-toplevel"], process.cwd());
  if (git(["status", "--porcelain"], root)) {
    console.error("preflight: refusing to run with uncommitted changes. Commit (or move them out) first; the stamp must describe a commit.");
    return 2;
  }
  const head = git(["rev-parse", "HEAD"], root);
  const base = git(["merge-base", "origin/main", head], root);
  const changed = git(["diff", "--name-only", `${base}..${head}`], root).split("\n").filter(Boolean);
  const goAvailable = spawnSync("go", ["version"], { stdio: "ignore" }).status === 0;
  const userModules = resolve(root, "desktop/cockpit/node_modules");
  const common = resolve(root, git(["rev-parse", "--git-common-dir"], root));
  const ran = [];
  let failed = 0;
  withSnapshot(root, head, (snap) => {
    // Reuse the user's installed cockpit dependencies read-only through a symlink; never mutate the user's tree.
    const snapModules = resolve(snap, "desktop/cockpit/node_modules");
    if (existsSync(resolve(userModules, "typescript")) && !existsSync(snapModules)) symlinkSync(userModules, snapModules);
    const list = (dir, ok) => (existsSync(resolve(snap, dir)) ? readdirSync(resolve(snap, dir)).filter(ok).map((f) => `${dir}${f}`) : []);
    const cockpitTests = Object.fromEntries(
      list(COCKPIT_UNIT, (f) => f.endsWith(".test.mjs")).map((t) => [t, importedPaths(t, readFileSync(resolve(snap, t), "utf8"))]),
    );
    const scriptTests = Object.fromEntries(
      [...list("scripts/tests/", (f) => f.endsWith(".test.mjs")), ...list("scripts/", (f) => f.endsWith(".test.mjs"))].map((t) => [t, readFileSync(resolve(snap, t), "utf8")]),
    );
    const cockpitDepsInstalled = existsSync(resolve(snapModules, "typescript"));
    const { goExistingDirs, goImporters } = goInfo(snap);
    const checks = selectChecks({ changed, cockpitTests, scriptTests, goAvailable, cockpitDepsInstalled, goExistingDirs, goImporters });
    console.log(`preflight: ${changed.length} changed file(s) vs ${base.slice(0, 9)} (merge-base with origin/main), HEAD ${head.slice(0, 9)}, checked in a detached snapshot of that commit`);
    for (const c of checks) {
      if (c.kind === "note") { console.log(`NOTE  ${c.name}: ${c.note}`); continue; }
      if (c.clean) rmSync(resolve(snap, c.clean), { recursive: true, force: true });
      const label = `${c.name}: ${[c.cmd, ...c.args].join(" ")}`;
      const args = c.args[0] === "--test" ? ["--test", "--test-concurrency=1", ...c.args.slice(1)] : c.args; // never parallel
      const r = spawnSync(c.cmd, args, { cwd: resolve(snap, c.cwd ?? "."), encoding: "utf8" });
      if (r.status === 0) { console.log(`PASS  ${label}`); ran.push(label); }
      else {
        failed++;
        console.log(`FAIL  ${label}`);
        process.stdout.write(`${r.stdout ?? ""}${r.stderr ?? ""}${r.error ? `${r.error.message}\n` : ""}`.split("\n").slice(-40).join("\n"));
      }
    }
  });
  if (failed) { console.error(`preflight: ${failed} check(s) failed; no stamp written`); return 1; }
  const dir = resolve(common, "preflight");
  mkdirSync(dir, { recursive: true });
  writeFileSync(resolve(dir, `${head}.ok`), `${STAMP_HEADER}\n${ran.join("\n")}\n`);
  console.log(`preflight: all ${ran.length} check(s) passed; stamp ${resolve(dir, `${head}.ok`)}`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main());
