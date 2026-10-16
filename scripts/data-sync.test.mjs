import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";
import { describe, summary, validate } from "./data-sync.mjs";

const sha = text => createHash("sha256").update(text).digest("hex");
const file = (path, content) => ({ path, content, sha256: sha(content), description: "d", license: "CC-BY-4.0" });
const bundle = files => ({ schemaVersion: 1, version: "1.2.3", license: { id: "CC-BY-4.0", url: "https://x" }, files });

test("the export is checked before anything is written", () => {
  validate(bundle([file("data/a.json", "{}\n"), file("data/sub/b.md", "x")]));
  const bad = file("data/a.json", "{}\n");
  bad.content = "{ }\n";
  assert.throws(() => validate(bundle([bad])), /sha256/);
  for (const path of ["data/../x.json", "README.md", "data/.hidden", "data/README.md", "data/manifest.json"])
    assert.throws(() => validate(bundle([file(path, "x")])), /path/);
  assert.throws(() => validate(bundle([file("data/a.json", "1"), file("data/a.json", "1")])), /repeated/);
  assert.throws(() => validate({ ...bundle([file("data/a.json", "1")]), schemaVersion: 2 }), /format/);
});

test("changes are told in records added, removed and changed", () => {
  const before = JSON.stringify({ plans: [{ id: "pro", price: 20 }, { id: "max", price: 100 }, { id: "old" }] });
  const after = JSON.stringify({ plans: [{ id: "pro", price: 22 }, { id: "max", price: 100 }, { id: "team" }] });
  assert.equal(describe("data/p.json", before, after), "added `team`; removed `old`; changed `pro`");
  assert.equal(describe("data/p.json", '{"a":1,"b":[1,2]}', '{"a":2,"b":[1,3]}'), "2 values changed");
  assert.equal(describe("data/p.json", '{"a":1}', '{ "a": 1 }'), "formatting only");
  assert.equal(describe("data/p.json", null, "{}"), "new file");
  const many = n => JSON.stringify(Array.from({ length: n }, (_, i) => ({ id: `m${i}` })));
  assert.match(describe("data/p.json", "[]", many(10)), /`m7` and 2 more$/);
});

test("the pull request body names the release and each file", () => {
  const body = summary({ version: "1.2.3", previous: "1.2.2", changes: [{ path: "data/a.json", what: "changed `pro`" }] });
  assert.match(body, /Model Plan 1\.2\.3 \(was 1\.2\.2\)/);
  assert.match(body, /\| `data\/a\.json` \| changed `pro` \|/);
});
