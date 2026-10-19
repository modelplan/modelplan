import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
const root = resolve(new URL("..", import.meta.url).pathname);
const read = async (p) => readFile(resolve(root, p));
const hash = (b) => createHash("sha256").update(b).digest("hex");
const policy = JSON.parse(await read("source-policy.json"));
const tracked = execFileSync(
  "git",
  ["ls-files", "--cached", "--others", "--exclude-standard"],
  { cwd: root, encoding: "utf8" },
)
  .trim()
  .split("\n")
  .filter(Boolean);
for (const p of tracked) {
  if (p.startsWith("docs/assets/") || p.startsWith("codex/ui/kit/"))
    assert.ok(
      Object.hasOwn(policy.legacyVisuals, p),
      `new official visual requires private placement: ${p}`,
    );
  assert.ok(
    !policy.privatePrefixes.some((prefix) => p.startsWith(prefix)),
    `private source path: ${p}`,
  );
  assert.ok(
    !/(^|\/)\.env(?:$|\.)|\.(pem|key)$/.test(p),
    `credential-like file: ${p}`,
  );
}
for (const [p, sha] of Object.entries(policy.legacyVisuals))
  assert.equal(
    hash(await read(p)),
    sha,
    `legacy visual changed: ${p}; route new official assets to the private package`,
  );
const core = JSON.parse(await read("reader/manifest.json"));
assert.deepEqual(Object.keys(core.files).sort(), ["LICENSE", "public-reader.d.mts", "public-reader.mjs"], "only publication verification may be exported here");
for (const [p, meta] of Object.entries(core.files)) {
  assert.match(p, /^[a-z0-9.-]+$/i);
  assert.equal(meta.license, "MIT");
  const bytes = await read("reader/" + p);
  assert.equal(hash(bytes), meta.sha256, "public reader integrity: " + p);
  assert.ok(
    !/aa_[A-Za-z0-9]{28,}|sk-or-v1-[a-f0-9]{40,}/.test(bytes.toString()),
    "credential-like content in " + p,
  );
}
// Legacy BY exports remain historical grants. New SA exports must obey the narrowed allowlist.
const dataManifest = JSON.parse(await read("data/manifest.json"));
if (dataManifest.license.id === "CC-BY-SA-4.0") {
 const allowed = new Set(["data/client-harness-aliases.json", "data/model-developers.json", "data/model-identities.json", "data/calibration/official-guidance.json", "data/schemas/ranker-input.schema.json", "data/schemas/ranker-output.schema.json", "data/vendor-effort-defaults.json"]);
 for (const item of dataManifest.files) assert.ok(allowed.has(item.path) || item.path.startsWith("data/real-api-pricing/"), "production data must not re-enter the open package: " + item.path);
}
for (const p of ["AGENTS.md", "CLAUDE.md"])
  assert.match((await read(p)).toString(), /AGENTS\.md|source-policy/);
for (const p of tracked.filter(
  (p) => p.startsWith(".github/workflows/") && p.endsWith(".yml"),
)) {
  const s = (await read(p)).toString();
  assert.ok(
    !s.includes("self-hosted") && !s.includes("modelplans-publish"),
    "public workflow must not access private runners: " + p,
  );
}
assert.ok(
  !(await read("desktop/build.mjs"))
    .toString()
    .includes("kit('kit/tokens.css')"),
  "community build must not silently load official visual kit",
);
console.log(
  "source, license, public-reader integrity and community-build policy verified",
);
