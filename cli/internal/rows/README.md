<!-- SPDX-License-Identifier: MIT -->
# Rows core interface

Normative wire contract: [rows-design.md](../../../schema/app-cli/rows-design.md).
`Build(Input)` is a pure projection: membership, classification, normalized
measurements, guidance and clock latches. `Validate` checks each wire field;
`ValidateCapture` additionally rejects unknown input being blessed as an
intentional generic failure. Neither builder nor validator performs I/O,
allocates references, or mutates the supplied facts.

This core change does not yet alter production command output. The reader and
captured-consent adapters are separate lanes; desktop integration and real CLI
captures follow those merges. `quota --json` remains a separate unchanged path.

`Projection` holds the four additive desktop-v1 fields. Nullable wire members
are pointers serialized as explicit null; optional action timing/disable fields
and the unknown plan's name are omitted. `Name.userAuthored` marks declared text
at the localized name; compiled titles and message texts are not user-authored.
The expiry latch has only state, reason and nextStep, never another row.

Adapters populate one `Input` and then stop mutating it until projection finishes.
The package imports only the standard library, so quota and consent adapters may
use it without an import cycle. Input itself serializes as `{}` to prevent raw
adapter facts accidentally becoming a desktop DTO.

- `Catalogue`: evaluated presence, route, retirement and reader-existence facts;
  no remote titles, detection signals, hosts or paths.
- `Consents`: persisted decisions plus established implicit permissions, generation,
  outdated-text and pending-cleanup flags. Reader statuses cannot invent consent.
- `Profiles`: per-profile latest attempt, observed time (including nil/future),
  freshness, last failure, login/generation discards, busy/cooldown, next attempt
  and an existing account locator. No identity is allocated by projection.
- `Accounts`: measurements, raw plan/limit/pool identifiers, beta/estimated flags,
  and an existing verified subscription reference. Before wire export the builder
  must apply allow-lists, field validation and message-table mapping.
- `Sources` and `Admissions`: preserve raw compiled status/reason/error/blocked
  channels and independent admission vetoes for the single mapping table.
- `DeclaredPlanIDs`: the union of stable keys in local.json plans, windows and
  resetCards, including plans without a reading; never array positions.
- `KeychainBlocks`: the actual credential-read-blocked fact and its status.
  A saved Keychain choice alone does not establish a block.

Profiles join accounts by `(ToolID, DeclaredPlanID, ProfileKey)`. Tool accounts
leave DeclaredPlanID empty; declared accounts set it and leave ToolID empty.
ProfileKey is an internal correlation key and must never become a wire id,
locator or account preference key. ProfileState owns attempt/freshness/discard
facts; AccountInput owns the corresponding measurements. With no known profile
failure time the adapter leaves it null rather than borrowing a provider-wide
attempt time. Identity-off adapters supply no refs/locators.

## Projection rules and verification

Candidates come from catalogue entries, persisted/implicit consent, permitted
measurements, and stable declared-plan keys. Detected unset and all denied or
cleanup-pending tools are Settings-only; denied/cleanup/outdated facts never
export values. Globally disabled readers and a failed publication fence keep
only declared rows. Every allowed tool keeps its Dock/menu/Settings membership
when pending, failing, missing or retired.

The classifier follows the normative first-match table. Missing/retired precedes
no_reader as approved by the coordinator; unavailable readers precede pending.
Actual credential-store blocking is separate from saved reader permission. A
current account plus an empty account remains fresh; any retained account makes
the row stale unless an earlier predicate wins. Null/future observations never
become current, and login/generation changes discard the old values and binding.

Reason/state/action and bilingual message text come from one compiled table.
Exact contextual signal lookup keeps Keychain consent-required distinct from
reader consent. Generic error/unavailable statuses require an error companion;
unknown values degrade to other, and only the canonical reader_errors other
code is a permitted intentional generic outcome in deterministic fixtures.
Tests inspect production emitting sites, compare every normative table row,
and separately exercise the unknown fallback.

Window keys and titles are allow-listed. Unknown limits/pools become other,
unknown harness plans become `{id: "unknown"}`, and existing art keys are reused
or left null. Window ids use role, duration and the sanitized keys; collisions
are ordered by reset/observation time and numeric tie-breakers, never provider
text. No positional or hashed account preference key is allocated.

A window's validUntil is bounded by account freshness and its own reset, never
by the snapshot refresh deadline. Row expiry takes the earliest current account
or window boundary. The expiry latch is precomputed conservatively with every
current value retained, using the expiry clock for cooldown guidance; it is
never fresh. A held-snapshot test crosses the session, account and weekly
boundaries without replacement. Offline/read-only/cooldown refresh actions stay
disabled, including cooldowns whose next-attempt time is unknown.

The two `testdata/allowed-*-no-reader.json` files are generated from real
`rows.Build` calls with synthetic typed inputs and are explicitly labelled
model-level fixtures, not CLI stdout. Regenerate them with:

```sh
cd cli
go test ./internal/rows -run TestMissingRetiredNoReaderFixtures -args -update-rows-fixtures
```

CLI command captures and generated Swift wire types remain in the final
integration stage, after the reader-state and consent-fence lanes land.
