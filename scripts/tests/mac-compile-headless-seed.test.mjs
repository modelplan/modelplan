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
  // One scratch path for both packages (trusted-mac.yml native-headless: HEADLESS_SCRATCH).
  return { d, ws, native: path.join(d, "tmp", "headless-build"), seed: path.join(d, "seed") };
}
const run = (s, mode, extra = {}) =>
  spawnSync("bash", [script, mode], { cwd: s.ws, encoding: "utf8", env: { ...process.env, PATH: `${path.join(s.d, "bin")}:${process.env.PATH}`, RUNNER_TEMP: path.join(s.d, "tmp"), SEED_ROOT: s.seed, ...extra } });
const build = (s, tag) => { fs.mkdirSync(s.native, { recursive: true }); fs.writeFileSync(path.join(s.native, "product"), tag); };
const seedlib = new URL("../mac-compile/seedlib.sh", import.meta.url).pathname;
const lib = (s, cmd, extra = {}) =>
  spawnSync("bash", ["-c", `. "${seedlib}"; ${cmd}`], { cwd: s.ws, encoding: "utf8", env: { ...process.env, SEED_ROOT: s.seed, SEED_WRITE: "1", ...extra } });

test("a trusted publish seeds the one shared scratch path; restore clones it and the job's copy is writable", () => {
  const s = setup(); build(s, "warm");
  let r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.deepEqual(fs.readdirSync(s.seed), ["headless_build"], "one seed, no staging left behind");
  fs.rmSync(s.native, { recursive: true }); // the runner empties RUNNER_TEMP
  r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal((r.stdout.match(/seed hit/g) ?? []).length, 1);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "warm"); fs.writeFileSync(path.join(s.native, "new"), "x");
  assert.ok(!fs.existsSync(path.join(s.ws, "desktop/native/.build")), "the workspace scratch is no longer used");
  assert.ok(!fs.existsSync(s.seed + ".lock"));
});

test("a publish removes the seeds of the retired two-scratch layout", () => {
  const s = setup(); build(s, "warm");
  for (const old of ["headless_native", "headless_app_integration"]) { fs.mkdirSync(path.join(s.seed, old, "k"), { recursive: true }); fs.chmodSync(path.join(s.seed, old, "k"), 0o555); }
  const r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.deepEqual(fs.readdirSync(s.seed), ["headless_build"]);
});

test("a publish that fails part-way keeps the previous seed; a later publish clears the leftover stage", () => {
  const s = setup(); build(s, "first"); run(s, "publish");
  build(s, "second");
  // The new copy cannot be made read-only (a cancelled or failed publish): the old seed must survive intact.
  const real = spawnSync("which", ["chmod"], { encoding: "utf8" }).stdout.trim();
  fs.writeFileSync(path.join(s.d, "bin", "chmod"), `#!/bin/bash\n[ "$1" = -R ] && [ "$2" = a-w ] && exit 1\nexec ${real} "$@"\n`, { mode: 0o755 });
  let r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /not published/);
  fs.rmSync(path.join(s.d, "bin", "chmod"));
  fs.mkdirSync(path.join(s.seed, ".headless_build.stage.stale"));  // as a killed publish would leave it
  fs.rmSync(s.native, { recursive: true });
  r = run(s, "restore");
  assert.match(r.stdout, /seed hit/);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "first");
  build(s, "third");
  r = run(s, "publish");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.deepEqual(fs.readdirSync(s.seed), ["headless_build"], "stale stages are removed");
  fs.rmSync(s.native, { recursive: true });
  run(s, "restore");
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "third");
});

test("the batched manifest hashes exactly what the per-entry manifest did (existing seeds stay valid)", () => {
  const s = setup();
  const t = path.join(s.d, "tree");
  fs.mkdirSync(path.join(t, "a dir", "sub"), { recursive: true });
  fs.writeFileSync(path.join(t, "a dir", "f 1"), "one");
  fs.writeFileSync(path.join(t, "a dir", "sub", "g"), "two two");
  fs.writeFileSync(path.join(t, "z"), "");
  fs.symlinkSync("a dir/f 1", path.join(t, "link"));
  fs.symlinkSync("missing", path.join(t, "dangling"));
  // The per-entry implementation this change replaced (seedlib.sh before the headless speed-up), verbatim.
  const old = `manifest_old() ( set -o pipefail; cd "$1" || exit 1
    find . -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
      if [ "$(uname)" = Darwin ]; then st=$(stat -f '%HT %z %Fm' -- "$f"); else st=$(stat -c '%F %s %.9Y' -- "$f"); fi || exit 1
      t=; if [ -L "$f" ]; then t=$(readlink -- "$f") || exit 1; fi
      printf '%s\\t%s\\t%s\\n' "$f" "$st" "$t"
    done | sha256 )`;
  const r = lib(s, `${old}; a=$(manifest "${t}") && b=$(manifest_old "${t}") && [ -n "$a" ] && echo "$a $b"`);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const [a, b] = r.stdout.trim().split(" ");
  assert.equal(a, b);
  assert.match(a, /^[0-9a-f]{64}$/);
  // A changed entry changes the hash; an unreadable tree fails instead of hashing a partial list.
  fs.writeFileSync(path.join(t, "z"), "x");
  assert.notEqual(lib(s, `manifest "${t}"`).stdout.trim(), a);
  assert.notEqual(lib(s, `manifest "${path.join(s.d, "nope")}"`).status, 0);
});

test("restore never writes the seed and clears stale state; without a seed it is a cold start that still exits 0", () => {
  const s = setup(); build(s, "stale");
  const r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /no usable seed/);
  assert.ok(!fs.existsSync(s.native));
  assert.ok(!fs.existsSync(s.seed));
});

test("a tampered seed falls back to cold", () => {
  const s = setup(); build(s, "warm"); run(s, "publish");
  const dir = path.join(s.seed, "headless_build");
  const key = fs.readdirSync(dir).find((n) => !n.includes("."));
  fs.chmodSync(path.join(dir, key), 0o755); fs.chmodSync(path.join(dir, key, "product"), 0o644);
  fs.writeFileSync(path.join(dir, key, "product"), "poisoned and longer");
  const r = run(s, "restore");
  assert.equal(r.status, 0);
  assert.ok(!fs.existsSync(s.native), "the poisoned seed is not used");
  assert.match(r.stdout, /no usable seed/);
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
  fs.writeFileSync(path.join(s.d, "bin", "rm"), `#!/bin/bash\nfor a; do case $a in *"/headless-build") exit 1;; esac; done\nexec ${real} "$@"\n`, { mode: 0o755 });
  const r = run(s, "restore");
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(fs.readFileSync(path.join(s.native, "product"), "utf8"), "warm", "restored into a clean path");
  const stale = fs.readdirSync(path.dirname(s.native)).filter((n) => n.startsWith("headless-build.aside."));
  assert.equal(stale.length, 1);
  assert.equal(fs.readFileSync(path.join(path.dirname(s.native), stale[0], "old", "product"), "utf8"), "stale");
});

test("if the survivor can be neither deleted nor moved aside, restore fails closed and clones nothing onto it", () => {
  const s = setup(); build(s, "warm"); run(s, "publish");
  fs.writeFileSync(path.join(s.native, "product"), "stale");
  const real = spawnSync("which", ["rm"], { encoding: "utf8" }).stdout.trim();
  const mv = spawnSync("which", ["mv"], { encoding: "utf8" }).stdout.trim();
  fs.writeFileSync(path.join(s.d, "bin", "rm"), `#!/bin/bash\nfor a; do case $a in *"/headless-build") exit 1;; esac; done\nexec ${real} "$@"\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(s.d, "bin", "mv"), `#!/bin/bash\nfor a; do case $a in *"/headless-build") exit 1;; esac; done\nexec ${mv} "$@"\n`, { mode: 0o755 });
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
