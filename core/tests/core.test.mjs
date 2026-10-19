import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { calculateMetrics } from "../metrics.mjs";
import { recommendBalancedV5, priceTimeRegion } from "../effort.ts";
import { lineup } from "../lineup.ts";
import {
  ClientDataReader,
  encodePublicJSON,
  publicContentHash,
} from "../public-reader.mjs";
const preferences = [
  {
    preferred: { id: "higher", score: 43, cost: 2, seconds: 2 },
    alternative: { id: "base", score: 40, cost: 1, seconds: 1 },
    provenance: "synthetic",
  },
];
test("all shipped core bytes have explicit license and integrity metadata", async () => {
  const m = JSON.parse(
    await readFile(new URL("../manifest.json", import.meta.url), "utf8"),
  );
  for (const [name, record] of Object.entries(m.files)) {
    assert.equal(record.license, "MIT");
    assert.equal(
      createHash("sha256")
        .update(await readFile(new URL("../" + name, import.meta.url)))
        .digest("hex"),
      record.sha256,
      name,
    );
  }
});
test("pure supplied-input scoring and abstention are reproducible without source APIs", () => {
  const input = {
    methodId: "synthetic",
    builtAt: "2026-01-01",
    versions: {},
    sources: {
      s: {
        label: "Synthetic",
        publisher: "Synthetic",
        ability: 1,
        cost: 1,
        time: 1,
      },
    },
    references: {
      s: {
        ability: { status: "ready", mu: 50, sd: 10 },
        cost: { status: "ready", mu: 1, geometricReference: 1 },
        time: { status: "ready", mu: 10, geometricReference: 10 },
      },
    },
    models: [
      {
        id: "synthetic",
        name: "Synthetic",
        developer: "Synthetic",
        recommended: null,
        rows: [
          {
            effort: "medium",
            observations: [
              {
                source: "s",
                model: "synthetic",
                effort: "medium",
                ability: 60,
                cost: 2,
                seconds: 20,
                reliability: 1,
                cohort: "synthetic",
                note: "not measured",
                url: "https://example.com/synthetic",
              },
            ],
          },
        ],
      },
    ],
  };
  assert.deepEqual(
    calculateMetrics(input),
    calculateMetrics(structuredClone(input)),
  );
  assert.ok(calculateMetrics(input)[0].rows[0].ability.value !== null);
  const missing = structuredClone(input);
  missing.models[0].rows[0].observations = [];
  assert.equal(calculateMetrics(missing)[0].rows[0].ability.value, null);
});
test("balanced effort is deterministic, exposes bounds and rejects malformed candidates", () => {
  assert.equal(priceTimeRegion(preferences).status, "bounded");
  const candidates = [
    { id: "medium", score: 40, cost: 1, time: [1, 1] },
    { id: "high", score: 40, cost: 2, time: [2, 2] },
  ];
  const r = recommendBalancedV5(candidates, preferences);
  assert.equal(r.compromise.id, "medium");
  assert.deepEqual(
    r,
    recommendBalancedV5(candidates.toReversed(), preferences),
  );
  assert.throws(
    () => recommendBalancedV5([{ ...candidates[0], cost: 0 }], preferences),
    /invalid_v5_candidate/,
  );
  assert.equal(
    recommendBalancedV5(candidates, []).status,
    "calibration-unresolved",
  );
});
test("lineup output is the same public rule, not a client-specific ranker", () => {
  const rows = [
    { id: "low", ability: 20, cost: 0.1 },
    { id: "high", ability: 40, cost: 0.5 },
    { id: "waste", ability: 39, cost: 1 },
    { id: "missing", ability: null, cost: null },
  ];
  const r = lineup(rows);
  assert.ok(r.members.find((x) => x.id === "low").tags.includes("cheapest"));
  assert.ok(r.members.find((x) => x.id === "high").tags.includes("strongest"));
  assert.ok(r.members.find((x) => x.id === "waste").dominatedBy);
  assert.equal(r.members.find((x) => x.id === "missing").status, "incomplete");
});
test("public reader rejects credential-bearing/nonlocal plain HTTP bases", async () => {
  for (const base of [
    "http://example.com",
    "https://user:password@example.com",
    "https://example.com/?token=x",
  ])
    assert.throws(() => new ClientDataReader({ baseUrl: base }));
  assert.equal(
    (await publicContentHash(encodePublicJSON({ synthetic: true }))).length,
    64,
  );
});
