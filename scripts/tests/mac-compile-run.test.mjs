// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const runSh = new URL("../mac-compile/run.sh", import.meta.url).pathname;

function setup(version = "Swift 6.0") {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "mcrun-"));
  fs.mkdirSync(path.join(d, "bin"));
  fs.writeFileSync(path.join(d, "bin", "swift"), `#!/bin/bash\nif [ "$1" = --version ]; then echo "${version}"; exit 0; fi\nfor a in "$@"; do case $a in --scratch-path) n=1;; *) [ "\${n:-}" = 1 ] && { mkdir -p "$a"; echo built > "$a/product"; n=0; };; esac; done\nexit 0\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(d, "plan.tsv"), "desktop/native/Pkg\tdesktop_native_Pkg\tbuild-tests\t-\tNone\n");
  return d;
}
const env = (d, extra) => ({ ...process.env, PATH: `${path.join(d, "bin")}:${process.env.PATH}`, RUNNER_TEMP: d, GITHUB_STEP_SUMMARY: path.join(d, "sum"), ...extra });
const run = (d, extra) => spawnSync("bash", [runSh, path.join(d, "plan.tsv"), path.join(d, "scratch"), "abcdef0123"], { cwd: d, encoding: "utf8", env: env(d, extra) });
const seedDir = (d) => path.join(d, "seed");
const pkgSeed = (d) => path.join(seedDir(d), "desktop_native_Pkg");

test("a trusted run publishes the seed; a PR run clones it and never writes it", () => {
  const d = setup();
  let r = run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const [key] = fs.readdirSync(pkgSeed(d)).filter((n) => !n.endsWith(".manifest"));
  assert.ok(fs.existsSync(path.join(pkgSeed(d), key, "product")));
  const before = fs.readdirSync(pkgSeed(d)).join();
  r = run(d, { SEED_ROOT: seedDir(d) });
  assert.match(r.stdout, /seed hit/);
  assert.ok(fs.existsSync(path.join(d, "scratch", "desktop_native_Pkg", "product")));
  assert.equal(fs.readdirSync(pkgSeed(d)).join(), before);
  assert.ok(!fs.existsSync(seedDir(d) + ".lock"));
});

test("a tampered seed fails its manifest and falls back to a cold build", () => {
  const d = setup();
  run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  const [key] = fs.readdirSync(pkgSeed(d)).filter((n) => !n.endsWith(".manifest"));
  fs.chmodSync(path.join(pkgSeed(d), key), 0o755); fs.chmodSync(path.join(pkgSeed(d), key, "product"), 0o644);
  fs.writeFileSync(path.join(pkgSeed(d), key, "product"), "poisoned and longer");
  const r = run(d, { SEED_ROOT: seedDir(d) });
  assert.match(r.stdout, /no usable seed/);
  assert.equal(fs.readFileSync(path.join(d, "scratch", "desktop_native_Pkg", "product"), "utf8"), "built\n");
});

test("a new toolchain removes the old seed completely, hidden entries included", () => {
  const d = setup("Swift 6.0");
  run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  fs.chmodSync(pkgSeed(d), 0o755); fs.writeFileSync(path.join(pkgSeed(d), ".hidden-marker"), "old");
  const d2 = setup("Swift 6.1");
  const r = spawnSync("bash", [runSh, path.join(d, "plan.tsv"), path.join(d, "scratch"), "abcdef0123"], { cwd: d, encoding: "utf8", env: env(d2, { RUNNER_TEMP: d, SEED_ROOT: seedDir(d), SEED_WRITE: "1" }) });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.ok(!fs.existsSync(path.join(pkgSeed(d), ".hidden-marker")));
  assert.equal(fs.readdirSync(pkgSeed(d)).filter((n) => !n.endsWith(".manifest")).length, 1);
});

const publish = (d) => {
  const r = run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const [key] = fs.readdirSync(pkgSeed(d)).filter((n) => !n.includes("."));
  return path.join(pkgSeed(d), key);
};
const coldAfterTamper = (tamper) => {
  const d = setup();
  const seed = publish(d);
  fs.chmodSync(seed, 0o755);
  tamper(seed);
  const r = run(d, { SEED_ROOT: seedDir(d) });
  assert.match(r.stdout, /no usable seed/);
  assert.equal(fs.readFileSync(path.join(d, "scratch", "desktop_native_Pkg", "product"), "utf8"), "built\n");
};

test("the published seed is read-only", () => {
  const seed = publish(setup());
  assert.throws(() => fs.writeFileSync(path.join(seed, "new"), "x"), process.getuid?.() === 0 ? /never/ : /EACCES/);
});

test("manifest probe: a same-size edit with a sub-second mtime change is detected", () => {
  coldAfterTamper((seed) => {
    const f = path.join(seed, "product");
    fs.chmodSync(f, 0o644);
    const st = fs.statSync(f);
    fs.writeFileSync(f, "BUILT\n"); // same size
    fs.utimesSync(f, st.atimeMs / 1000, st.mtimeMs / 1000 + 0.25);
  });
});

test("manifest probe: an added symlink is detected", () => {
  coldAfterTamper((seed) => fs.symlinkSync("/etc/passwd", path.join(seed, "link")));
});

test("lock probe: an existing directory in the lock's place is reclaimed when old", () => {
  const d = setup();
  fs.mkdirSync(seedDir(d) + ".lock", { recursive: true });
  const old = Date.now() / 1000 - 600;
  fs.utimesSync(seedDir(d) + ".lock", old, old);
  const r = run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.ok(!fs.existsSync(seedDir(d) + ".lock"));
});

test("lock probe: a dead owner's pid file is reclaimed", () => {
  const d = setup();
  fs.mkdirSync(seedDir(d) + ".lock", { recursive: true });
  fs.writeFileSync(path.join(seedDir(d) + ".lock", "pid"), "999999");
  const r = run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test("clone probe: a failed first copy leaves no nested seed and still reuses the seed", () => {
  const d = setup();
  publish(d);
  const real = spawnSync("which", ["cp"], { encoding: "utf8" }).stdout.trim();
  fs.writeFileSync(path.join(d, "bin", "cp"), `#!/bin/bash\nif [ ! -e "${d}/cp-failed" ]; then touch "${d}/cp-failed"; for last; do :; done; mkdir -p "$last/partial"; exit 1; fi\nexec ${real} "$@"\n`, { mode: 0o755 });
  const r = run(d, { SEED_ROOT: seedDir(d) });
  assert.ok(fs.existsSync(path.join(d, "cp-failed")));
  assert.match(r.stdout, /seed hit/); assert.doesNotMatch(r.stdout, /clone failed/);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const sp = path.join(d, "scratch", "desktop_native_Pkg");
  assert.ok(fs.existsSync(path.join(sp, "product")));
  assert.ok(!fs.existsSync(path.join(sp, "partial")) && !fs.existsSync(path.join(sp, path.basename(sp))));
});

test("an interrupted run releases its lock", async () => {
  const d = setup();
  fs.writeFileSync(path.join(d, "bin", "swift"), `#!/bin/bash\nif [ "$1" = --version ]; then echo s; exit 0; fi\nsleep 3\n`, { mode: 0o755 });
  const p = spawn("bash", [runSh, path.join(d, "plan.tsv"), path.join(d, "scratch"), "abcdef0123"], { cwd: d, stdio: "ignore", env: env(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" }) });
  for (let i = 0; i < 50 && !fs.existsSync(seedDir(d) + ".lock"); i++) await new Promise((r) => setTimeout(r, 100));
  assert.ok(fs.existsSync(seedDir(d) + ".lock"));
  p.kill("SIGTERM");
  await new Promise((r) => p.on("exit", r));
  assert.ok(!fs.existsSync(seedDir(d) + ".lock"), "lock released after TERM");
});
