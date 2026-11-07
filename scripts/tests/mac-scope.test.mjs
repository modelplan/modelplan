// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));

// The exact pipeline shipped in a workflow's mac-scope job.
function shipped(workflow) {
  const text = readFileSync(join(root, ".github/workflows", workflow), "utf8");
  const match = /^\s*if (git diff .*); then$/m.exec(text);
  assert.ok(match, `${workflow} has no mac-scope pipeline`);
  return match[1];
}

// Runs it on a merge commit whose second parent adds one file, as a pull_request checkout does.
function selects(workflow, path) {
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
      execFileSync("bash", ["-c", shipped(workflow)], { cwd: repo, stdio: "pipe" });
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

test("third-party-notices.yml selects manifests, including under quoted paths", () => {
  assert.equal(selects("third-party-notices.yml", "desktop/native/Package.swift"), true);
  assert.equal(selects("third-party-notices.yml", "desktop/模块/Package.resolved"), true);
  assert.equal(selects("third-party-notices.yml", "desktop/third-party/é.json"), true);
  assert.equal(selects("third-party-notices.yml", "cli/main.go"), false);
});
