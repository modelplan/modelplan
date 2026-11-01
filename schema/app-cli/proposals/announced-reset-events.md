<!-- SPDX-License-Identifier: MIT -->
# Draft: announced public reset events in rows

This is a proposal for an additive rows-wire extension, not an implemented
producer or a claim of S4 acceptance. `rows/subscribe` and `rows/changed` would
carry optional `resetEvents` alongside `rows`, `rowsVersion` and `rowsSummary`.
Omission means the producer has not supplied the feature; an empty array means
it supplied no eligible events. Existing rows version 1 and prior clients remain
unchanged until the contract and its consumers are reviewed together.

Each event has `version: 1`, a stable published `id`, affected `rowId`,
`status` (`announced` or `confirmed`), `publishedAt`, optional bounded schedule
(`from`, `through`), `expiresAt`, and `source` (`kind: publication`, verified
`publicationId`, and optional HTTPS `url`). The publication ID establishes
provenance, not a notification identity. Event IDs must be bounded safe public
identifiers and remain stable across publication refreshes; row IDs must refer
to existing tool rows. No account identifiers, private quota values, arbitrary
provider text or local paths belong in this public event.

An announced event is *announced* before a scheduled window and *active* during
it; neither state establishes an account reset. A confirmed event represents an
upstream-reported completion and expires 24 hours after its confirmation was
published. An announcement expires at its scheduled window end, or 48 hours
after publication when unscheduled. After expiry it cannot trigger a notice.
Events withdrawn by the verified publication cease to be eligible. The source
must not join an announcement and a later confirmation merely because their
provider or times match; a trustworthy link remains an open question.

Acknowledgement is a local per-surface overlay, not a shared event state:
opening the dock can acknowledge the sliver notice, opening the cockpit or dock
can acknowledge the menu notice, and notification delivery is deduplicated per
event key. None of these actions asserts the provider reset an account. A real
new reading remains the only evidence for updating quota values. M4 owns those
consumer behaviors, clock transitions, storage and accessibility.

The existing verified client publication exposes public `resets` records, while
quota `resetsAt` values describe normal per-window reset times and the optional
calendar supplement describes multiplier windows. Neither is sufficient to
invent a public announcement. A future engine adapter must map explicitly
verified eligible publication events, fail closed on unknown identities or
invalid/unavailable source data, and produce an actual normal-path snapshot.
This proposal does not add that adapter, fetch new data, change Swift, or create
notifications. See the draft PR for review contract, seam and open questions.
