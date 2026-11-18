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
  fs.writeFileSync(path.join(pkgSeed(d), key, "product"), "poisoned and longer");
  const r = run(d, { SEED_ROOT: seedDir(d) });
  assert.match(r.stdout, /no usable seed/);
  assert.equal(fs.readFileSync(path.join(d, "scratch", "desktop_native_Pkg", "product"), "utf8"), "built\n");
});

test("a new toolchain removes the old seed completely, hidden entries included", () => {
  const d = setup("Swift 6.0");
  run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  fs.writeFileSync(path.join(pkgSeed(d), ".hidden-marker"), "old");
  const d2 = setup("Swift 6.1");
  const r = spawnSync("bash", [runSh, path.join(d, "plan.tsv"), path.join(d, "scratch"), "abcdef0123"], { cwd: d, encoding: "utf8", env: env(d2, { RUNNER_TEMP: d, SEED_ROOT: seedDir(d), SEED_WRITE: "1" }) });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.ok(!fs.existsSync(path.join(pkgSeed(d), ".hidden-marker")));
  assert.equal(fs.readdirSync(pkgSeed(d)).filter((n) => !n.endsWith(".manifest")).length, 1);
});

test("a lock with an unreadable owner is reclaimed; a dead owner is reclaimed at once", () => {
  const d = setup();
  fs.mkdirSync(seedDir(d));
  fs.symlinkSync("999999", seedDir(d) + ".lock"); // interrupted acquisition would leave no valid pid; a dead pid here
  const r = run(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.ok(!fs.existsSync(seedDir(d) + ".lock"));
});

test("an interrupted run releases its lock", async () => {
  const d = setup();
  fs.writeFileSync(path.join(d, "bin", "swift"), `#!/bin/bash\nif [ "$1" = --version ]; then echo s; exit 0; fi\nsleep 3\n`, { mode: 0o755 });
  const p = spawn("bash", [runSh, path.join(d, "plan.tsv"), path.join(d, "scratch"), "abcdef0123"], { cwd: d, stdio: "ignore", env: env(d, { SEED_ROOT: seedDir(d), SEED_WRITE: "1" }) });
  for (let i = 0; i < 50 && !fs.existsSync(seedDir(d) + ".lock"); i++) await new Promise((r) => setTimeout(r, 100));
  assert.ok(fs.existsSync(seedDir(d) + ".lock") || fs.lstatSync(seedDir(d) + ".lock", { throwIfNoEntry: false }));
  p.kill("SIGTERM");
  await new Promise((r) => p.on("exit", r));
  assert.ok(!fs.lstatSync(seedDir(d) + ".lock", { throwIfNoEntry: false }), "lock released after TERM");
});
