# "Fixed" means proven in the owner's environment; review is risk-tiered

Status: accepted by the owner on 2026-10-29.

## Context

Two owner-reported issues (Dock side, red-key ring) returned after their PRs had merged. Each fix covered a narrower case than the one the owner saw. Every proof ran on fresh synthetic homes and the neutral path. Reviews ran three full passes per PR, yet missed seam bugs, and the back-and-forth stalled the lanes.

## Decision

- **Proof levels.**
  - **L1:** CI green, including fixture replay and decode-mutation tests.
  - **L2:** passes in the owner-shaped synthetic home, generated from the owner's sanitized shape export.
  - **L3:** passes the real-Mac checklist on the real candidate, with local screenshots and a diagnostics export.
- **What counts as done.**
  - A merged PR is L1. An owner-reported issue is closed only at L3, compared against the original report.
  - Every fix lands with a test that fails before it.
  - The required level depends on the change: docs L0, internal L1, contract or decode L2, UI or permission L3.
- **Smoke before integrated review.** Every candidate gets a 5-minute real-Mac smoke before the integrated review.
- **Review tiers.**
  - A normal PR gets automated checks plus one main independent review.
  - Credential, migration, process and release changes add a specialist review.
  - Each candidate gets one open-ended review, and any disagreement between reviewers counts as risk.

## Consequences

- An owner-shaped fixture generator and the shape export become part of CI.
- M1 keeps a standing list of owner-reported issues as numbered L3 checks.
- Small changes stop paying for three full reviews.
