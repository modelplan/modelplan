// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));

// The exact pipeline shipped in a workflow's scope step; `index` picks among several (repo-checks.yml has two).
function shipped(workflow, index = 0) {
  const text = readFileSync(join(root, ".github/workflows", workflow), "utf8");
  const match = [...text.matchAll(/^\s*if (git diff .*); then$/gm)][index];
  assert.ok(match, `${workflow} has no scope pipeline ${index}`);
  return match[1];
}

// Runs it on a merge commit whose second parent adds one file, as a pull_request checkout does.
function selects(workflow, path, index = 0) {
  const repo = mkdtempSync(join(tmpdir(), "mac-scope-"));
  const git = (...args) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", ...args], { cwd: repo, stdio: "pipe" });
  try {
    git("init", "-q", "-b", "main");
    git("commit", "-q", "--allow-empty", "-m", "base");
    git("checkout", "-q", "-b", "pr");
    mkdirSync(dirname(join(repo, path)), { recursive: true });
    writeFileSync(join(repo, path), "x");
    git("add", "-A");
    git("commit", "-q", "-m", "change");
    git("checkout", "-q", "main");
    git("commit", "-q", "--allow-empty", "-m", "main moved");
    git("merge", "-q", "--no-ff", "--no-edit", "pr");
    try {
      execFileSync("bash", ["-c", shipped(workflow, index)], { cwd: repo, stdio: "pipe" });
      return true;
    } catch (error) {
      assert.equal(error.status, 1);
      return false;
    }
  } finally {
    rmSync(repo, { recursive: true, force: true });
  }
}

test("ci.yml selects claude-code paths, including ones Git quotes", () => {
  assert.equal(selects("ci.yml", "claude-code/tests/fixture.txt"), true);
  assert.equal(selects("ci.yml", "claude-code/测试.txt"), true);
  assert.equal(selects("ci.yml", "codex/hooks/é.sh"), true);
  assert.equal(selects("ci.yml", "cli/main.go"), false);
  assert.equal(selects("ci.yml", "cli/测试.txt"), false);
});

test("repo-checks.yml selects manifests for the notices macOS leg, including under quoted paths", () => {
  assert.equal(selects("repo-checks.yml", "desktop/native/Package.swift"), true);
  assert.equal(selects("repo-checks.yml", "desktop/模块/Package.resolved"), true);
  assert.equal(selects("repo-checks.yml", "desktop/third-party/é.json"), true);
  assert.equal(selects("repo-checks.yml", "cli/main.go"), false);
});

test("repo-checks.yml runs the Linux notices check for every input of scripts/third-party-notices.py", () => {
  for (const path of ["desktop/cockpit/src/a.ts", "cli/internal/测试.go", "clients/swift/a.swift", "LICENSES/CodexBar-MIT.txt",
    "tools/u10/Package.swift", ".github/workflows/release.yml", "scripts/third-party-notices.py", "scripts/tests/test_third_party_notices.py"]) {
    assert.equal(selects("repo-checks.yml", path, 1), true, path);
  }
  for (const path of ["docs/a.md", "codex/server.mjs", "claude-code/hooks/a.sh", "scripts/check-source-policy.mjs", ".github/workflows/ci.yml"]) {
    assert.equal(selects("repo-checks.yml", path, 1), false, path);
  }
});
