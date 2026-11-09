import { test } from "node:test";
import assert from "node:assert/strict";
import { releaseAssetText } from "../release-asset.mjs";

const resp = (status, body = "", json) => ({ ok: status >= 200 && status < 300, status, text: async () => body, json: async () => json });
const noWait = async () => {};

test("direct download is used when it works", async () => {
  const calls = [];
  const text = await releaseAssetText("o/r", "v1.0.0", "checksums.txt", { wait: noWait, fetchImpl: async u => { calls.push(u); return resp(200, "abc"); } });
  assert.equal(text, "abc");
  assert.deepEqual(calls, ["https://github.com/o/r/releases/download/v1.0.0/checksums.txt"]);
});

test("5xx on the download host falls back to the API asset after retries", async () => {
  const calls = [];
  const fetchImpl = async (u, opts) => {
    calls.push(u);
    if (u.startsWith("https://github.com/")) return resp(504);
    if (u.endsWith("/releases/tags/v1.0.0")) return resp(200, "", { assets: [{ name: "checksums.txt", url: "https://api.github.com/repos/o/r/releases/assets/7" }] });
    assert.equal(opts.headers.accept, "application/octet-stream");
    return resp(200, "sums");
  };
  assert.equal(await releaseAssetText("o/r", "v1.0.0", "checksums.txt", { wait: noWait, fetchImpl }), "sums");
  assert.equal(calls.filter(u => u.startsWith("https://github.com/")).length, 3);
});

test("a 404 on the download host fails at once, without the API", async () => {
  let n = 0;
  await assert.rejects(releaseAssetText("o/r", "v9.9.9", "checksums.txt", { wait: noWait, fetchImpl: async () => { n++; return resp(404); } }), /404/);
  assert.equal(n, 1);
});

test("a missing asset in the API fallback is an error", async () => {
  const fetchImpl = async u => u.startsWith("https://github.com/") ? resp(503) : resp(200, "", { assets: [] });
  await assert.rejects(releaseAssetText("o/r", "v1.0.0", "checksums.txt", { wait: noWait, fetchImpl }), /not among the release assets/);
});
