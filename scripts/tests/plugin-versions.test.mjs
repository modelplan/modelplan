import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { bumpPlugins, missedBumps, pluginVersions } from "../plugin-versions.mjs";

test("a moved pin needs every plugin version moved", () => {
  const before = { a: "0.7.37", b: "0.15.38" };
  assert.deepEqual(missedBumps("0.5.46", "0.5.46", before, before), [], "same pin: nothing needed");
  assert.deepEqual(missedBumps("0.5.46", "0.5.52", before, before), ["a", "b"], "the 11-04 mistake");
  assert.deepEqual(missedBumps("0.5.46", "0.5.52", before, { a: "0.7.38", b: "0.15.38" }), ["b"]);
  assert.deepEqual(missedBumps("0.5.46", "0.5.52", before, { a: "0.7.38", b: "0.15.39" }), []);
});

test("the bump moves the plugin's versions and no dependency's", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "plugin-versions-"));
  const put = async (f, text) => { await mkdir(path.dirname(path.join(root, f)), { recursive: true }); await writeFile(path.join(root, f), text); };
  await put("claude-code/.claude-plugin/plugin.json", '{\n  "name": "x",\n  "version": "0.7.37"\n}\n');
  await put("codex/.codex-plugin/plugin.json", '{\n  "version": "0.15.38"\n}\n');
  await put("codex/package.json", '{\n  "version": "0.15.38"\n}\n');
  await put("codex/package-lock.json", '{\n  "version": "0.15.38",\n  "packages": {\n    "": {\n      "version": "0.15.38"\n    },\n    "node_modules/dep": {\n      "version": "0.15.38"\n    }\n  }\n}\n');
  await bumpPlugins(root);
  const text = await readFile(path.join(root, "codex/package-lock.json"), "utf8");
  assert.deepEqual(text.match(/"version": "[^"]+"/g), ['"version": "0.15.39"', '"version": "0.15.39"', '"version": "0.15.38"']);
  await rm(root, { recursive: true });
});

test("the real files parse and agree", async () => {
  const root = new URL("../../", import.meta.url).pathname;
  const texts = {};
  for (const f of ["claude-code/.claude-plugin/plugin.json", "codex/.codex-plugin/plugin.json", "codex/package.json", "codex/package-lock.json"]) texts[f] = await readFile(path.join(root, f), "utf8");
  const v = pluginVersions(f => texts[f]);
  assert.equal(new Set([v["codex/.codex-plugin/plugin.json"], v["codex/package.json"], v["codex/package-lock.json"]]).size, 1);
});
