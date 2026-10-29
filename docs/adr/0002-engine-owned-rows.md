# The engine owns each tool's displayed row

Status: accepted by the owner on 2026-10-29. The design (`schema/app-cli/rows-design.md` v4) was reviewed in four rounds.

## Context

The app rebuilt "one row per tool" from `accounts`, `sources`, `connections`, `subscriptions` and consent. It did this in four surfaces, with four tool-id canonicalisers, five title tables and several state and reason tables. Rows vanished, ages were lost, and new CLI reason codes went unmapped.

## Decision

- The engine computes one `Row` per tool: membership, a total classifier, closed reason codes, next-step actions, per-account value state, clock fields and privacy-safe ids.
- The app renders rows. It applies only presentation preferences and the clock rules the row carries. Go never reads app preferences.
- A tool that is missing or retired is classified before `no_reader`.
- Consent is per read scope, not per tool. Consent facts carry their generation, and the app never joins facts and rows from different generations.
- Each account carries a safe `route` code that names its source.
- Empty states are explicit, and each has one owner.
  - The engine emits the full row set, never filtered by app preferences, with the engine states `readers_off`, `pending`, `no_consent` and empty.
  - The app applies hidden rows and order. When every row is hidden, it shows its own "all hidden" state, which never goes back into the engine snapshot.
  - The check: after the surface's filter, the shown stable ids equal the expected ids, each once.
- This ADR supersedes `rows-design.md` v4 in its classifier order and its display-only scope.

## Consequences

- Every tool, title, state and reason rule lives in one Go function with table tests and an oracle test written from the design.
- The Dock, the menu bar and Settings cannot disagree, because they read the same rows.
- Generated captures and the e2e job must cover every state in the design, including the owner-shaped cases.
