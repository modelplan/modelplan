# Reader, detection and metric work follows a reference app

Status: accepted by the owner (D239) on 2026-11-13. It restates research that had been done once and then forgotten.

## Context

Readers, tool detection and usage metrics were repeatedly rebuilt from scratch even though mature open-source quota monitors had already solved the same problems, including the pitfalls (token refresh that logs users out, missed archived sessions, wrong window meanings). The comparison of those projects was done and then lost between sessions.

## Decision

- **The panel.** Reader, detection and metric work follows one of these apps:
  - **CodexBar** (MIT): per-tool reader routes, detection signals, re-read timing, error causes and their sign-in remedy.
  - **Pulse** (Apache-2.0): the no-renew credential stance, presence-only detection, structured tool seams; the Dock shell (ADR 0004).
  - **Token Monitor** (MIT): tie-breaker between CodexBar and Pulse; detection of tools installed later.
  - **ccusage** (MIT): local usage logs (Claude and Codex JSONL, archived and compressed sessions, dedupe, periods) and cost validation.
  - **Tokei** (no licence file): behaviour only — metric definitions and local-file routes as a tie-breaker. Never copy its code.
- **How we borrow.** Pick the panel app whose route for the tool wins, at a pinned commit or tag. Then choose a mode:
  - **PORT** copies MIT or Apache-2.0 code with its licence header and an upstream citation, recorded in `docs/borrowed/`;
  - **MATCH** writes our own code for the same behaviour and cites the source;
  - **PATTERN** borrows an interface idea only.

  Our red lines (no token refresh, no credential copies, no paid calls, presence-only detection) beat parity whenever a panel app disagrees with them. User-facing strings are never copied verbatim.
- **Name it in the PR.** A PR that touches reader, detection, local-usage, speed or consent code carries a body line
  `Reference: <app>@<commit-or-tag> <path>` or `Reference: none (<reason>)`. The merge gate fails a PR in that scope without it (#926).
- **Keep it fresh.** A low-cost model runs a watch weekly and before each release: it diffs each panel app's files for our tools from the pinned commit, scans new issues, and proposes card updates. A release does not ship with an unreviewed watch report.

The full table, the per-tool decision procedure and the watch steps are in [`docs/readers/integration-standard.md` §3](../readers/integration-standard.md#3-reference-projects) and §7.

## Consequences

- Before writing a reader, read the tool's integration card (`docs/readers/<tool>.md`) and the panel app's code for that tool; do not repeat research the card already holds.
- A new reader costs one card plus the reference it follows; a changed reference costs one card update.
