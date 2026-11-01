<!-- SPDX-License-Identifier: MIT -->
# Draft: announced public reset events in rows

This document records the reviewed proposal. The production schema and producer
are promoted separately in #406; this document does not claim S4 acceptance.
The optional `resetEvents` array belongs to the shared
`RowsProjection` used by `rows/subscribe`, `rows/changed`, and `cockpit/query`.
Omission means unsupported; an empty array means known empty. Both peers must
negotiate `resetEvents` before emitting it on any of those paths: older strict
schemas reject the additional property. The production gate is in #406.

Each version 1 event has a stable `id`, public `provider`, affected `rowId`,
`status` (`announced` or `confirmed`), `publishedAt`, optional bounded
`schedule`, `expiresAt`, and publication `source`. The source's publication ID
is provenance, not notification identity. Optional `planIds` names the plans
explicitly affected; absence means row-wide, not a guessed subscription. Match
plans only against the row's account members. The member display key is the
verified `subscriptionRef`, otherwise `<rowId>#<source>` per #695. The existing
wire account does not expose `source`; do not substitute route, locator, array
position, or a hash. That fallback requires an agreed consumer interface.

An announcement ID is a SHA-256 hash of provider, announced reset instant and
source URL. The review reference uses length-framed UTF-8 fields, a domain tag,
and the instant in UTC RFC3339Nano; it hashes the exact verified source URL,
without exporting an unapproved URL. A confirmation explicitly carries
`confirms` equal to the known announcement ID and replaces that announcement's
snapshot, retaining its ID. Drop and count unlinked confirmations; never show
them. The count is a local aggregate, not automatic telemetry. Unknown statuses
are ignored. Events attach by verified provider/tool mapping, never by inferred
quota times.

When the instant or source URL is absent, use the verified publication record’s
stable event ID instead. The unscheduled fixture exercises this fallback with
no instant or URL. A future adapter must reject an absent or unsafe fallback ID
and must not substitute a publication revision ID. If a later revision adds the
missing hash inputs, stable identity across that transition still needs an
authoritative correlation rule; the stateless CLI cannot invent one.

An announcement is active during its published window and expires at the window
end, or 48 hours after publication without a schedule. Confirmation represents
an explicit public report, expires 24 hours after confirmation publication, and
is not evidence that a personal account was reset. Withdrawn and expired events
are suppressed. App-owned local acknowledgement and notification deduplication
are keyed by event ID; the CLI remains stateless. M4 owns presentation, storage,
clock transitions, and the normal-entry journey test (#697).

A source link is shown only when its host is on the official vendor host list
used by the source registry; otherwise omit the link and retain the event text.
The App never fetches it. The review-only test uses synthetic hosts, not a copy
of the official list. The producer needs a reviewed interface to that list; no
public registry interface has been established by this proposal. No account
identifiers, personal quota values, arbitrary source text or local paths belong
in an event. Rows pick up updates on the existing publication refresh cadence;
there is no new polling.

The verified publication has public reset records. Personal quota `resetsAt` and
calendar multiplier windows are not public reset announcements. The future
adapter must verify the publication, map explicitly eligible records, apply host
policy, and validate provenance, row membership, times, and unique `(rowId,id)`
pairs. The adjacent schema is a review overlay, not the authoritative generated
schema. Tests use the production rows builder and envelope with synthetic event
types; they do not establish production provenance. M4 can consume
`fixtures/app-journey-plan-scoped.json`, a two-account row with a plan-scoped
announcement, and `fixtures/confirmed.json` for the linked confirmation.
