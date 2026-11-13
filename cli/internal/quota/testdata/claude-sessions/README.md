<!-- SPDX-License-Identifier: MIT -->
# Synthetic Claude session field fixtures

Owner confirmation, 2026-10-27: a sanitised probe of the owner's newest Claude Code session reported assistant records with top-level `effort: "high"`, `message.model: "claude-opus-5-5"` and `message.usage.speed: "standard"`. The owner also confirmed the usage key names `service_tier`, `inference_geo` and `iterations`. Only field names and short enum values were supplied; no real transcript was accessed or copied here.

`owner-confirmed.jsonl` is independently written from those facts. Its additional usage values (`null`, `null`, `[]`) are synthetic placeholders, **not observations of their values or a claim that the owner confirmed their types**. The session-state reader ignores these extra usage keys; it must not infer Fast from `service_tier`, geography or iterations. `standard` maps to `fastMode: false`.

`older-optional.jsonl` contains three independent field-projection cases, not one session: model alone; effort and speed without a model; and all three absent. Each absent value is unknown. `expected-fields.json` records logical projections, using `null` for unknown; it does not change the existing wire encoding of optional values. Never carry a previous record's missing model, effort or Fast into a newer turn.

These minimal assistant-record projections test field locations and optionality. They do not assert session IDs, timestamps, interactivity, turn order, content or any other unreported field. The later reader PR supplies separate synthetic envelopes/selection fixtures and consumes these cases; this commit adds no reader implementation. No messages, project names, paths, identities, credentials, plugin or status-line data are in these fixtures.
