# "Fixed" means proven in the owner's environment; review is risk-tiered

Status: accepted by the owner on 2026-10-29. Revised the same day so that its proof and review rules match foundation v2 revision 3.

## Context

Two owner-reported issues (the Dock side and the red-key ring) returned after their PRs had merged. Each fix covered a narrower case than the one the owner saw. Every proof ran on fresh synthetic homes and the neutral path. Reviews ran three full passes per PR, yet they missed seam bugs, and the back-and-forth stalled the lanes.

## Decision

- **A level is earned by checks, never by an action.** A merge, a machine name or a "synthetic home" label earns nothing. A result carries:
  - its subject: source SHAs, package hashes, the asset manifest, the publication revision;
  - its profile and environment;
  - the scenario ids;
  - an outcome per scenario: `pass`, `fail`, `not-run`, `unsupported` or `timeout`.

  Only `pass` counts.
- **Proof levels.**
  - **L1.** The checks that apply to a stated subject, inputs and policy pass: logic, generated contracts through the production decoder, behaviour regressions, security negative controls.
  - **L2.** The declared capabilities and scenarios pass:
    - on hosted macOS and the dedicated test Mac;
    - with the owner-shaped synthetic home where the scenario needs it;
    - on the real package where the scenario needs it.

    An engine replay does not prove package UI, OS paths or real input. A capability that is missing stays `pending`.
  - **L3.** The owner's Mac, on the same bundle that passed L2. It covers the scenarios of the original reports, real logins and the owner's visual confirmation, inside one GUI run of at most 20 minutes.
- **What counts as done.**
  - An owner-reported issue closes only when its scenario passes at L3, compared against the original report.
  - A fix that changes behaviour lands with a test that fails before it, at the seam where the failure belongs. Docs fixes and refactors with no behaviour change need no new test.
  - The required level follows the risk and the capabilities a change touches:

    | Change | Required level |
    |---|---|
    | Docs | L0 |
    | Internal code with no contract change | L1 |
    | Contract, decoding, consent, readers, migration | L2 |

    UI and permission changes need the L2 scenarios for what they touch. Real-account and visual-confirmation parts are L3 items on the next candidate. A normal UI PR does not wait for the owner.
- **Before the owner.** Each candidate passes L2 on its final package, a 5-minute smoke and one integrated review before it goes to the owner for L3.
- **Review tiers.**

  | Change | Review |
  |---|---|
  | Normal PR | Automated checks plus one independent main review |
  | Protocol, consent, storage migration, process supervision | The main review covers the specialty. An independent specialist is added only when the main reviewer lacks it |
  | Credentials, privacy, release, signing | The coordinator is the main or specialist review, not an extra queue (owner rule) |
  | Public seam PRs and candidates | GLM-5.3 checks them in parallel (owner rule). It blocks only on a blocking finding |
  | Candidate | One integrated review that reuses the PR evidence for the same SHAs. A disagreement between reviewers is recorded as a risk |

  Only an unresolved blocking finding stops a merge.

## Consequences

- The owner-shaped home is built from an approved, versioned shape baseline, not re-exported before each beta.
- M1 keeps the owner-reported issues as numbered L3 items, each with its L2 prerequisite (foundation v2, Appendix A).
- Small changes stop paying for three full reviews.
