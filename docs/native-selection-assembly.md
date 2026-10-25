# Native model-selection runtime

The app's `CommunityRuntime.modelSelection` uses `ModelSelectionRuntime`, which reads `SnapshotStore.modelSelectionFeeds()` on every request. Core keeps the validated last-good public catalog available independently of a personal/scored join. The assembly target depends on Core, Selection and Instruments; the three modules do not gain circular dependencies.

## Current owner-authorized policy

- All: the publication's current/default-selected fleet plus older models with positive usage in the fresh CLI `recent7d` session summary. It does not require subscription entitlements.
- One subscription: published `harnessIds` for that subscription's declared sources form tool-compatible candidates, plus actually observed use. These are labelled **该工具可用 / Available in this tool**, not paid-plan entitlements. Use-only candidates carry **实际用过 / Observed use**.
- Session ownership: an explicit session subscription reference wins. Otherwise only one distinct subscription for the source permits fallback ownership. Ambiguity suppresses that older exception, preserving the normal catalog. The result retains explicit-versus-unique-source provenance.
- Missing personal data, unknown scope, unusable selection or missing revision falls back to the shared selector's public-default fleet with **按公开默认 / Public defaults**. No lineage or revision is fabricated. If no public catalog exists, an explicit loading/unavailable message is returned; nonexistent models are never invented.

`ModelPlanSelection` remains the only ordering/cap implementation. Exact events and untimed recent-window membership are distinct; this runtime uses only the latter for the existing session summary. `recent7d` is the CLI's seven-local-day summary (bounded top sessions/configurations), not a complete rolling per-model event log. Session `lastAt`, snapshot time and day boundaries are never copied into a per-model usage instant, and the instrument payload's exact recent-use timestamps remain empty.

The public-default flag allows a known publication/scope catalog to remain visible without an exact selection revision. Ordinary comparison/trial consumers retain their exact matching gate; fallback catalog availability does not attest current account configuration or scores. Public models/efforts are mapped verbatim; current personal effort and fast tier remain unknown here rather than guessed.

Personal expiry is rechecked and latched. Fresh positive window evidence is required for older exceptions; source-wide buckets, mere configuration, unknown aliases or zero usage cannot create them. Malformed published dominance metadata is quarantined with an explicit mapping issue, and conflicting readable contexts are delegated to the selector's abstention rule.

No CLI command, schema, canonical test fixture, credential, permission, collector or visual layout changes are part of this path. The separate proposal for precise model/subscription/event-time data is review-only and does not block this runtime. Root native XCTest runs the synthetic scope/fallback/ownership/expiry and real-store-binding integration cases.
