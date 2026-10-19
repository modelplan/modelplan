# Model Plan public computation core

Original computation and a public-data reader. MIT licensed, with no brand/visual grant. Source ownership is this public repository; private production imports a pinned, hash-verified revision. Changes need compatibility tests, never a private-first editable copy.

- `metrics.mjs`: the production multi-source normalization/aggregation function. Input identity, protocol eligibility, frozen references and source weights are explicit inputs; no raw benchmark observations are bundled.
- `effort.ts`: the production balanced-v5 minimax-regret selector, price/time calibration region, interval treatment and deterministic ties.
- `lineup.ts`: the published frontier, strongest/best-value/cheapest tags and tie policy.
- `public-reader.mjs`: the verification implementation already shipped in the Codex plugin, including the public schema. This initial canonicalization retains its exact bytes. Its modular TypeScript source extraction is a separate follow-up; do not regenerate it from private schema builders.

Run: `node --test core/tests/*.test.mjs` (Node 24+).

The module computes results for supplied inputs. The private producer acquires and reviews inputs, forms native-effort candidates, applies protocol/availability admission, then publishes results. These adapters are not secretly represented as part of this standalone module. Reproducing the live website requires the same legally acquired input snapshot, admission, parameters and reference values; synthetic tests are not model evaluations. No paid inference, collection, publication pipeline, private snapshot or official 3D/visual source is included.

Policy configuration already released as open data remains in `data/calibration/`. Third-party input data keeps its original terms. Method descriptions are in the repository methodology; code visibility does not imply a raw-data redistribution right.
