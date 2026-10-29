# The engine owns each tool's displayed row

Status: accepted by the owner on 2026-10-29. The design (`schema/app-cli/rows-design.md` v4) was reviewed in four rounds.

## Context

The app rebuilt "one row per tool" from `accounts`, `sources`, `connections`, `subscriptions` and consent. It did this in four surfaces, with four tool-id canonicalisers, five title tables and several state and reason tables. Rows vanished, ages were lost, and new CLI reason codes went unmapped.

## Decision

- The engine computes one `Row` per tool: membership, a total classifier, closed reason codes, next-step actions, per-account value state, clock fields and privacy-safe ids.
- The app renders rows. It applies only presentation preferences and the clock rules the row carries.
- A tool that is missing or retired is classified before `no_reader`.
- Consent editing facts stay on the consent methods and are joined to rows by tool id.

## Consequences

- Every tool, title, state and reason rule lives in one Go function with table tests and an oracle test written from the design.
- The Dock, the menu bar and Settings cannot disagree, because they read the same rows.
- Generated captures and the e2e job must cover every state in the design, including the owner-shaped cases.
