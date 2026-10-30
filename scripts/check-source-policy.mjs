import assert from "node:assert/strict";
import { verifyPortholePack } from "./check-porthole-pack.mjs";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import { verifyFontPack } from "./check-font-pack.mjs";
const root = resolve(new URL("..", import.meta.url).pathname);
const read = async (p) => readFile(resolve(root, p));
const hash = (b) => createHash("sha256").update(b).digest("hex");
const policy = JSON.parse(await read("source-policy.json"));
verifyFontPack(root);
verifyPortholePack(root);
const tracked = execFileSync(
  "git",
  ["ls-files", "--cached", "--others", "--exclude-standard"],
  { cwd: root, encoding: "utf8" },
)
  .trim()
  .split("\n")
  .filter(Boolean);
const reserved = policy.reservedVisuals;
const inReserved = (p) => p.startsWith(reserved.prefix);
for (const p of tracked) {
  if (p.startsWith("docs/assets/") || p.startsWith("codex/ui/kit/"))
    assert.ok(
      Object.hasOwn(policy.legacyVisuals, p),
      `new official visual belongs under ${reserved.prefix} with its reserved license: ${p}`,
    );
  assert.ok(
    inReserved(p) || !/(^|\/)official-visuals\//.test(p),
    `official visuals live only under ${reserved.prefix}: ${p}`,
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
    `legacy visual changed: ${p}; put new official assets under ${reserved.prefix}`,
  );
// Reserved official visuals: LicenseRef-ModelPlan-Visuals-1.0 under one prefix, never MIT-labelled.
// Exceptions are exact historical MIT bytes and hash-listed binaries.
assert.equal(reserved.prefix, "desktop/official-visuals/");
assert.equal(reserved.license, "LicenseRef-ModelPlan-Visuals-1.0");
assert.equal(reserved.licenseFile, reserved.prefix + "LICENSE.md", "reserved prefix must contain LICENSE.md");
assert.ok(tracked.includes(reserved.licenseFile), "reserved prefix must contain LICENSE.md: " + reserved.licenseFile);
const licenseBytes = await read(reserved.licenseFile);
assert.ok(licenseBytes.toString().includes(reserved.license), "reserved license must name " + reserved.license);
assert.ok(
  licenseBytes.equals(await read(reserved.licenseText)),
  `${reserved.licenseText} must equal ${reserved.licenseFile}`,
);
const spdxReserved = new RegExp(
  String.raw`^\W{0,8}SPDX-License-Identifier"?:\s*"?` + reserved.license.replaceAll(".", "\\.") + String.raw`\b`,
  "m",
);
const listed = { ...reserved.historicalMit, ...reserved.binaries };
for (const [p, sha] of Object.entries(listed)) {
  assert.ok(inReserved(p) && tracked.includes(p), "listed reserved-visual file missing: " + p);
  assert.equal(
    hash(await read(p)),
    sha,
    Object.hasOwn(reserved.historicalMit, p)
      ? `historical MIT visual changed: ${p}; the change is reserved: drop it from historicalMit and add the ${reserved.license} header (or list a binary)`
      : `reserved binary changed: ${p}; audit it and update its hash in reservedVisuals.binaries`,
  );
}
for (const p of tracked) {
  const bytes = await read(p);
  if (!inReserved(p)) {
    assert.ok(
      !spdxReserved.test(bytes.toString()),
      `${reserved.license} files belong under ${reserved.prefix}: ${p}`,
    );
    continue;
  }
  if (p === reserved.licenseFile || Object.hasOwn(listed, p)) continue;
  const text = bytes.toString();
  assert.ok(
    !bytes.includes(0) && Buffer.from(text).equals(bytes),
    `reserved binary must be listed with its SHA-256 in reservedVisuals.binaries: ${p}`,
  );
  assert.ok(spdxReserved.test(text), `reserved visual must carry SPDX-License-Identifier: ${reserved.license}: ${p}`);
  assert.ok(!/SPDX-License-Identifier"?:\s*"?MIT\b/.test(text), `reserved visual must not carry an MIT header: ${p}`);
}
// The community build never reads the reserved prefix: only build.mjs's --official branch names it.
for (const p of tracked.filter((p) => p.startsWith("desktop/") && !inReserved(p) && !p.startsWith("desktop/tests/") && !p.endsWith(".md"))) {
  const code = (await read(p)).toString().replace(/^\s*\/\/.*$/gm, "");
  if (!code.includes("official-visuals")) continue;
  assert.equal(p, "desktop/build.mjs", "community build must not read the reserved visuals: " + p);
  const branch = code.slice(code.indexOf("if (official) {"), code.indexOf("} else if (external) {"));
  assert.ok(
    code.indexOf("if (official) {") >= 0 && code.split("official-visuals").length === branch.split("official-visuals").length,
    "community build must not read the reserved visuals outside the --official branch",
  );
}
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
