<!-- SPDX-License-Identifier: MIT -->
# Rows core interface

Normative wire contract: [rows-design.md](../../../../schema/app-cli/rows-design.md).
This package initially defines types only. No production command imports it yet.
The pure builder and desktop integration follow in a separate PR; quota output
and all reader/consent storage formats stay unchanged.

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
