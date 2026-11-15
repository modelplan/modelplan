// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { collated, fragmentProblem } from "../changelog.mjs";

const root = fileURLToPath(new URL("../..", import.meta.url));
const base = "# Changelog\n\nIntro.\n\n## Unreleased\n\nThese ship next.\n\n- Old entry.\n  中文行。\n\n## CLI v0.5.46 (2026-10-29)\n\n- Earlier.\n";

test("a fragment is one English paragraph", () => {
  assert.equal(fragmentProblem("a-change.md", "Fix the reader.\n"), null);
  assert.match(fragmentProblem("a-change.md", "修复读取。\n"), /English only/);
  assert.match(fragmentProblem("a-change.md", "One.\n\nTwo.\n"), /one paragraph/);
  assert.match(fragmentProblem("a-change.md", "- Fix.\n"), /list marker/);
  assert.match(fragmentProblem("a-change.md", "## Fix\n"), /heading/);
  assert.match(fragmentProblem("a-change.md", " \n"), /empty/);
  assert.match(fragmentProblem("Bad Name.txt", "Fix.\n"), /lower-case/);
});

test("collating keeps history and leaves Unreleased ready for the next release", () => {
  const out = collated(base, ["New one.\n", "Wrapped\nline.\n"], "v0.5.54", "2026-11-08");
  assert.equal(out, "# Changelog\n\nIntro.\n\n## Unreleased\n\nThese ship next.\n\n## CLI v0.5.54 (2026-11-08)\n\n- Old entry.\n  中文行。\n\n- New one.\n\n- Wrapped line.\n\n## CLI v0.5.46 (2026-10-29)\n\n- Earlier.\n");
  const next = collated(out, ["Later.\n"], "v0.5.55", "2026-11-09");
  assert.match(next, /## Unreleased\n\nThese ship next\.\n\n## CLI v0\.5\.55 \(2026-11-09\)\n\n- Later\.\n\n## CLI v0\.5\.54/);
});

test("nothing to collate fails instead of writing an empty release", () => {
  assert.throws(() => collated("## Unreleased\n\nThese ship next.\n\n## CLI v1.0.0 (2026-01-01)\n", [], "v1.0.1", "2026-01-02"), /nothing to collate/);
});

test("the command collates and removes fragments, and rejects a bad one", () => {
  const repo = mkdtempSync(join(tmpdir(), "changelog-"));
  try {
    mkdirSync(join(repo, "scripts"));
    mkdirSync(join(repo, "changelog.d"));
    cpSync(join(root, "scripts/changelog.mjs"), join(repo, "scripts/changelog.mjs"));
    writeFileSync(join(repo, "CHANGELOG.md"), base);
    writeFileSync(join(repo, "changelog.d/README.md"), "Docs.\n");
    writeFileSync(join(repo, "changelog.d/one.md"), "Fix one.\n");
    const run = (...args) => execFileSync(process.execPath, ["scripts/changelog.mjs", ...args], { cwd: repo, stdio: "pipe" }).toString();
    assert.match(run("--check"), /1 changelog fragments valid/);
    writeFileSync(join(repo, "changelog.d/bad.md"), "修复。\n");
    assert.throws(() => run("--check"));
    assert.throws(() => run("--collate", "v0.5.54"));
    assert.equal(readFileSync(join(repo, "CHANGELOG.md"), "utf8"), base, "a rejected fragment changes nothing");
    rmSync(join(repo, "changelog.d/bad.md"));
    run("--collate", "v0.5.54", "--date", "2026-11-08");
    assert.match(readFileSync(join(repo, "CHANGELOG.md"), "utf8"), /## CLI v0\.5\.54 \(2026-11-08\)[\s\S]*- Fix one\./);
    assert.equal(existsSync(join(repo, "changelog.d/one.md")), false);
    assert.equal(existsSync(join(repo, "changelog.d/README.md")), true);
  } finally {
    rmSync(repo, { recursive: true, force: true });
  }
});
