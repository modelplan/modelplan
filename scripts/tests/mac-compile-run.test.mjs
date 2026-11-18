// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const runSh = new URL("../mac-compile/run.sh", import.meta.url).pathname;

function setup(version) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "mcrun-"));
  const bin = path.join(d, "bin");
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, "swift"), `#!/bin/bash\nif [ "$1" = --version ]; then echo "${version}"; exit 0; fi\nexit 0\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(d, "plan.tsv"), "desktop/native/Pkg\tdesktop_native_Pkg\tbuild-tests\t-\tNone\n");
  return d;
}
const run = (d, root, bin = path.join(d, "bin")) =>
  spawnSync("bash", [runSh, path.join(d, "plan.tsv"), root, "abcdef0123"], {
    cwd: d, encoding: "utf8", env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, RUNNER_TEMP: d, GITHUB_STEP_SUMMARY: path.join(d, "sum") },
  });

test("the scratch root persists between jobs and is dropped when the toolchain changes", () => {
  const d = setup("Swift 6.0");
  const root = path.join(d, "cache", "runner-1");
  let r = run(d, root);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /cold cache/);
  fs.mkdirSync(path.join(root, "desktop_native_Pkg"), { recursive: true });
  fs.writeFileSync(path.join(root, "desktop_native_Pkg", "product"), "x");
  r = run(d, root);
  assert.equal(r.status, 0);
  assert.doesNotMatch(r.stdout, /cold cache/);
  assert.ok(fs.existsSync(path.join(root, "desktop_native_Pkg", "product")), "warm cache kept");
  const d2 = setup("Swift 6.1");
  r = run(d, root, path.join(d2, "bin"));
  assert.match(r.stdout, /cold cache/);
  assert.ok(!fs.existsSync(path.join(root, "desktop_native_Pkg", "product")), "cache wiped on a new toolchain");
  assert.ok(!fs.existsSync(root + ".lock"), "lock released");
});

test("a lock left by a dead process is taken over", () => {
  const d = setup("Swift 6.0");
  const root = path.join(d, "cache");
  fs.mkdirSync(root + ".lock", { recursive: true });
  fs.writeFileSync(path.join(root + ".lock", "pid"), "999999");
  const r = run(d, root);
  assert.equal(r.status, 0, r.stdout + r.stderr);
});
