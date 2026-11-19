// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const script = new URL("../mac-compile/headless-seed.sh", import.meta.url).pathname;

function setup() {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "hlseed-"));
  fs.mkdirSync(path.join(d, "bin"));
  fs.writeFileSync(path.join(d, "bin", "swift"), '#!/bin/bash\necho "Swift 6.0"\n', { mode: 0o755 });
  const ws = path.join(d, "ws"); fs.mkdirSync(path.join(ws, "desktop/native/ModelPlanAppIntegration"), { recursive: true });
  fs.mkdirSync(path.join(d, "tmp"));
  return { d, ws, native: path.join(ws, "desktop/native/.build"), app: path.join(d, "tmp", "app-integration-tests"), seed: path.join(d, "seed") };
}
const run = (s, mode, extra = {}) =>
  spawnSync("bash", [script, mode], { cwd: s.ws, encoding: "utf8", env: { ...process.env, PATH: `${path.join(s.d, "bin")}:${process.env.PATH}`, RUNNER_TEMP: path.join(s.d, "tmp"), SEED_ROOT: s.seed, ...extra } });
const build = (s, tag) => { for (const p of [s.native, s.app]) { fs.mkdirSync(p, { recursive: true }); fs.writeFileSync(path.join(p, "product"), tag); } };

test("a trusted publish seeds both scratch paths; restore clones them and the job's copy is writable", () => {
  const s = setup(); build(s, "warm");
  let r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  fs.rmSync(s.native, { recursive: true }); fs.rmSync(s.app, { recursive: true }); // git clean + empty RUNNER_TEMP
  r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal((r.stdout.match(/seed hit/g) ?? []).length, 2);
  for (const p of [s.native, s.app]) { assert.equal(fs.readFileSync(path.join(p, "product"), "utf8"), "warm"); fs.writeFileSync(path.join(p, "new"), "x"); }
  assert.ok(!fs.existsSync(s.seed + ".lock"));
});

test("restore never writes the seed and clears stale state; without a seed it is a cold start that still exits 0", () => {
  const s = setup(); build(s, "stale");
  const r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /no usable seed/);
  assert.ok(!fs.existsSync(s.native) && !fs.existsSync(s.app));
  assert.ok(!fs.existsSync(s.seed));
});

test("a tampered seed falls back to cold", () => {
  const s = setup(); build(s, "warm"); run(s, "publish");
  const dir = path.join(s.seed, "headless_native");
  const key = fs.readdirSync(dir).find((n) => !n.includes("."));
  fs.chmodSync(path.join(dir, key), 0o755); fs.chmodSync(path.join(dir, key, "product"), 0o644);
  fs.writeFileSync(path.join(dir, key, "product"), "poisoned and longer");
  const r = run(s, "restore");
  assert.equal(r.status, 0);
  assert.ok(!fs.existsSync(s.native), "the poisoned seed is not used");
  assert.equal(fs.readFileSync(path.join(s.app, "product"), "utf8"), "warm");
});

test("publish with no build state warns and exits 0; a bad mode is refused", () => {
  const s = setup();
  const r = run(s, "publish");
  assert.equal(r.status, 0); assert.match(r.stdout, /not published/);
  assert.equal(run(s, "other").status, 2);
});

test("a scratch path that survives cleanup is moved aside into a fresh directory, then restored cleanly", () => {
  const s = setup(); build(s, "warm"); run(s, "publish");
  fs.writeFileSync(path.join(s.native, "product"), "stale");
  const real = spawnSync("which", ["rm"], { encoding: "utf8" }).stdout.trim();
  fs.writeFileSync(path.join(s.d, "bin", "rm"), `#!/bin/bash\nfor a; do case $a in *"/.build") exit 1;; esac; done\nexec ${real} "$@"\n`, { mode: 0o755 });
  const r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "warm", "restored into a clean path");
  const stale = fs.readdirSync(path.dirname(s.native)).filter((n) => n.startsWith(".build.aside."));
  assert.equal(stale.length, 1);
  assert.equal(fs.readFileSync(path.join(path.dirname(s.native), stale[0], "old", "product"), "utf8"), "stale");
});

test("if the survivor can be neither deleted nor moved aside, restore fails closed and clones nothing onto it", () => {
  const s = setup(); build(s, "warm"); run(s, "publish");
  fs.writeFileSync(path.join(s.native, "product"), "stale");
  const real = spawnSync("which", ["rm"], { encoding: "utf8" }).stdout.trim();
  const mv = spawnSync("which", ["mv"], { encoding: "utf8" }).stdout.trim();
  fs.writeFileSync(path.join(s.d, "bin", "rm"), `#!/bin/bash\nfor a; do case $a in *"/.build") exit 1;; esac; done\nexec ${real} "$@"\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(s.d, "bin", "mv"), `#!/bin/bash\nfor a; do case $a in *"/.build") exit 1;; esac; done\nexec ${mv} "$@"\n`, { mode: 0o755 });
  const r = run(s, "restore");
  assert.equal(r.status, 1, "the job must not build on the survivor");
  assert.match(r.stdout, /cannot establish a clean/);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "stale");
  assert.ok(!fs.existsSync(path.join(s.native, "c")), "no seed nested into the survivor");
});

test("an unavailable seed root or a lock that cannot be taken never fails the step", () => {
  const s = setup(); build(s, "warm");
  fs.writeFileSync(path.join(s.d, "file"), "x");
  let r = run(s, "publish", { SEED_ROOT: path.join(s.d, "file", "seed") }); // parent is a file
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /unavailable/);
  // a live owner holds the lock: after the wait the step still exits 0 (shortened by a sleep shim)
  fs.mkdirSync(s.seed + ".lock", { recursive: true }); fs.writeFileSync(path.join(s.seed + ".lock", "pid"), String(process.pid));
  fs.mkdirSync(s.seed);
  fs.writeFileSync(path.join(s.d, "bin", "sleep"), "#!/bin/bash\nexit 0\n", { mode: 0o755 });
  r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /unavailable/);
  assert.ok(fs.existsSync(s.seed + ".lock"), "the other owner's lock is untouched");
  r = run(s, "restore", { SEED_ROOT: path.join(s.d, "file", "seed") });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

test("a hosted runner is a silent no-op", () => {
  const s = setup(); build(s, "keep");
  const r = run(s, "restore", { RUNNER_ENVIRONMENT: "github-hosted" });
  assert.equal(r.status, 0);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "keep");
});
