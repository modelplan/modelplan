// SPDX-License-Identifier: MIT
// Which Mac jobs a PR runs, by changed file. Path-filtered workflows are read from their own pull_request.paths;
// desktop.yml's two Mac jobs (app-smoke, native-headless) and the ci.yml / repo-checks.yml legs use the shipped scope.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { touchesDesktopMac } from "../desktop-mac-scope.mjs";

const root = fileURLToPath(new URL("../..", import.meta.url));
const read = (workflow) => readFileSync(join(root, ".github/workflows", workflow), "utf8");

// Workflows whose every job is Mac and which carry their own pull_request path filter.
const PATH_FILTERED = ["u10-candidate", "u4-swift-wire", "dock-host-port", "official-dock", "macos-distribution",
  "u6-engine-store-core", "u4b-engine-client", "u11-native"];

function prPaths(workflow) {
  const text = read(`${workflow}.yml`);
  const block = /^  pull_request:\n((?:    .*\n)+)/m.exec(text)[1];
  const inline = /^    paths: (\[.*\])$/m.exec(block);
  const list = inline ? JSON.parse(inline[1]) : [...block.matchAll(/^      - ['"]?(.+?)['"]?$/gm)].map((m) => m[1]);
  assert.ok(list.length, `${workflow} has a pull_request path filter`);
  return list.map((glob) => new RegExp("^" + glob.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*\*/g, "\u0000").replace(/\*/g, "[^/]*").replace(/\u0000/g, ".*") + "$"));
}
const filters = Object.fromEntries(PATH_FILTERED.map((w) => [w, prPaths(w)]));

// The two scope pipelines shipped in ci.yml (claude-code-macos) and repo-checks.yml (notices-macos).
const ciScope = /grep -qzE '(\^\(claude-code[^']*)'/.exec(read("ci.yml"))[1];
const noticesScope = /if git diff --name-only -z HEAD\^1 HEAD \| grep -qzE '([^']*Package[^']*repo-checks[^']*)'; then\n\s+echo "notices-mac=true"/.exec(read("repo-checks.yml"))[1];
const grepZ = (re, file) => { try { execFileSync("bash", ["-c", `printf '%s\\0' "$1" | grep -qzE "$2"`, "x", file, re], { stdio: "pipe" }); return true; } catch { return false; } };

function macJobs(files) {
  const jobs = new Set();
  for (const [workflow, regexes] of Object.entries(filters)) if (files.some((f) => regexes.some((re) => re.test(f)))) jobs.add(workflow);
  if (touchesDesktopMac(files)) { jobs.add("desktop/app-smoke"); jobs.add("desktop/native-headless"); }
  if (files.some((f) => grepZ(ciScope, f))) jobs.add("ci/claude-code-macos");
  if (files.some((f) => grepZ(noticesScope, f))) jobs.add("repo-checks/notices-macos");
  return [...jobs].sort();
}

test("e2e-journey triggers on cli/** but its Mac job runs on manual dispatch only", () => {
  assert.match(read("e2e-journey.yml"), /if: \$\{\{ github\.event_name == 'workflow_dispatch' \}\}\n\s+runs-on: macos-latest/);
});

test("docs, data and site-only PRs run no Mac job", () => {
  assert.deepEqual(macJobs(["README.md", "docs/mac-ci.md", "data/plans.json", "skills/model-plan/SKILL.md", "reader/src/x.ts"]), []);
});

test("a CLI Go-only PR skips the Swift jobs and the packaging jobs", () => {
  // The app bundles the released CLI named by codex/cli-pin.json, never one built from cli/; e2e-journey (dispatch-only)
  // (dispatch-only) is the only job that builds the same-commit CLI.
  assert.deepEqual(macJobs(["cli/internal/quota/limits.go", "cli/internal/quota/limits_test.go"]), ["u4b-engine-client"]);
  assert.deepEqual(macJobs(["cli/internal/render/table.go"]), []);
  assert.deepEqual(macJobs(["cli/internal/connections/x.go"]), []);
});

test("a Tauri-app, codex UI or snapshot-contract PR skips the desktop Mac jobs", () => {
  for (const file of ["desktop/app/main.ts", "desktop/src-tauri/src/main.rs", "desktop/tests/app.test.ts", "desktop/scripts/x.mjs",
    "codex/ui/panel.tsx", "codex/lib/x.mjs", "cli/internal/snapshot/s.go", "cli/internal/digest/d.go", "schema/snapshot.json"]) {
    const jobs = macJobs([file]);
    assert.ok(!jobs.includes("desktop/app-smoke") && !jobs.includes("desktop/native-headless"), file);
  }
});

test("a cockpit-web-only PR keeps the jobs that package or test the cockpit bundle", () => {
  const jobs = macJobs(["desktop/cockpit/src/main.ts"]);
  assert.deepEqual(jobs, ["desktop/app-smoke", "desktop/native-headless", "u10-candidate"]);
  assert.ok(!jobs.includes("macos-distribution") && !jobs.includes("u4-swift-wire"));
});

test("a Swift change under desktop/native runs the native jobs", () => {
  const jobs = macJobs(["desktop/native/ModelPlanDock/Native/DockInstrumentView.swift"]);
  for (const job of ["desktop/native-headless", "desktop/app-smoke", "dock-host-port", "official-dock", "macos-distribution", "u10-candidate"]) assert.ok(jobs.includes(job), job);
  assert.ok(!jobs.includes("u4-swift-wire") && !jobs.includes("u6-engine-store-core"));
});

test("Swift client packages and the wire schema reach the engine jobs", () => {
  assert.ok(macJobs(["clients/swift/ModelPlanWire/Sources/x.swift"]).includes("u6-engine-store-core"));
  assert.ok(macJobs(["clients/swift/ModelPlanWire/Sources/x.swift"]).includes("desktop/native-headless"));
  assert.ok(macJobs(["schema/app-cli/app-server.json"]).includes("u4-swift-wire"));
  assert.ok(macJobs(["schema/app-cli/app-server.json"]).includes("desktop/native-headless"));
});

test("the plugin CLI pin reaches app-smoke, claude-code and the Mac workflows' own files reach themselves", () => {
  assert.ok(macJobs(["codex/cli-pin.json"]).includes("desktop/app-smoke"));
  assert.ok(macJobs(["codex/cli-pin.json"]).includes("ci/claude-code-macos"));
  assert.ok(macJobs(["claude-code/hooks/x.mjs"]).includes("ci/claude-code-macos"));
  assert.ok(macJobs([".github/workflows/desktop.yml"]).includes("desktop/native-headless"));
  assert.ok(macJobs([".github/workflows/trusted-mac.yml"]).includes("desktop/native-headless"));
  assert.ok(macJobs(["desktop/native/Package.resolved"]).includes("repo-checks/notices-macos"));
  assert.ok(!macJobs(["cli/main.go"]).includes("repo-checks/notices-macos"));
});

test("desktop.yml's Mac jobs wait for the scope job and treat only an explicit false as skip", () => {
  const text = read("desktop.yml");
  for (const name of ["app-smoke", "native-headless"]) {
    const body = new RegExp(`^  ${name}:\\n((?:(?:    .*)?\\n)+)`, "m").exec(text)[1];
    assert.match(body, /needs: .*queue-scope/, name);
    assert.match(body, /needs\.queue-scope\.outputs\.mac != 'false'/, name);
  }
  const scope = /^  queue-scope:\n((?:(?:    .*)?\n)+)/m.exec(text)[1];
  assert.match(scope, /github\.event_name == 'merge_group' \|\| github\.event_name == 'pull_request'/, "pushes and dispatches skip the scope job, so the Mac jobs always run there");
});
