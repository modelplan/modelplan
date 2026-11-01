<!-- SPDX-License-Identifier: MIT -->
# Draft: announced public reset events in rows

This is a proposal for an additive rows-wire extension, not an implemented
producer or a claim of S4 acceptance. `rows/subscribe` and `rows/changed` would
carry optional `resetEvents` alongside `rows`, `rowsVersion` and `rowsSummary`.
Omission means the producer has not supplied the feature; an empty array means
it supplied no eligible events. The proposed `reset_events_v1` initialize
capability must be explicitly advertised by both peers before the producer emits
this field. Existing strict v1 schema validators reject unknown properties, so
an additive field alone is not sufficient compatibility. The current server
records client capabilities but does not implement this gate. `RowsProjection`
is also used by `cockpit/query`; capability gating must cover every use.
Existing rows version 1 and prior clients remain unchanged in this draft.

Each event has `version: 1`, a stable published `id`, affected `rowId`,
`status` (`announced` or `confirmed`), `publishedAt`, optional bounded schedule
(`precision`, `from`, `through`), `expiresAt`, and `source` (`kind: publication`, verified
`publicationId`, and optional HTTPS `url`). The publication ID establishes
provenance, not a notification identity. Event IDs must be bounded safe public
identifiers and remain stable across publication refreshes; row IDs must refer
to existing tool rows. No account identifiers, private quota values, arbitrary
provider text or local paths belong in this public event. A source URL is an
untrusted optional user action: no automatic fetch, and M4 must apply an
approved host policy before opening it. If no safe URL is available, omit it.

An announced event is *announced* before a scheduled window and *active* during
it; neither state establishes an account reset. `precision` preserves the
published window/date/approximate/deadline qualifier, so a window is not an
asserted exact reset instant. A confirmed event represents an
upstream-reported completion and expires 24 hours after its confirmation was
published. For `confirmed`, `publishedAt` refers to the confirmation record,
not an earlier announcement. An announcement expires at its scheduled window
end, or 48 hours after publication when unscheduled. After expiry it cannot trigger a notice.
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

The adjacent JSON Schema is an overlay for review. Its `resetEvents` property
and definitions are applied to the generated `RowsProjection` schema by the
Go proposal tests, without changing the authoritative generated schema or Swift
bindings. The fixture generator uses the production Go rows builder and envelope
plus test-only proposal types. It is not a live event producer. Consumers must
ignore unsupported event versions rather than treating them as an account reset.
Temporal ordering, verified-source provenance, row membership and unique
`(rowId, id)` pairs also require semantic validation beyond JSON Schema.

Event identity and acknowledgement are separate: `(source.kind, id)` is the
proposed cross-publication notification key, and `(rowId, id)` associates an
event with a tool row. A capability-gated consumer must preserve missing versus
known-empty, suppress expired and withdrawn entries, and never infer quota
refills from the public status. The producer and M4 must agree on stable IDs and
on the authoritative association of an announced item with a later confirmation.

The Go tests exercise a synthetic overlay and compare supplied publication IDs;
they do not establish cryptographic verification or production provenance. The
future adapter must verify the publication and source record, reject duplicates
and unmatched rows, and only mark a reset confirmed on an approved explicit
public confirmation. The exact provider/status mapping and safe source-host
policy need review before wiring this into the live engine.
