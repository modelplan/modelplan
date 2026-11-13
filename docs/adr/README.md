# Architecture decision records

Durable decisions the owner has accepted. Read the index before starting work; read the ADRs that touch your task in full. If your plan contradicts an ADR, say which one and why, and get the owner's decision before acting on it. Do not re-derive a decided question.

| ADR | Decision | Read before |
|---|---|---|
| [0001](0001-app-server-engine-boundary.md) | The app talks to one long-lived engine process | Engine, CLI or app-server work |
| [0002](0002-engine-owned-rows.md) | The engine owns each tool's displayed row | Row model or rendering work |
| [0003](0003-keychain-identity-and-token-handoff.md) | Keychain reads use the app's own identity; tokens reach Go in memory only | Credentials, Keychain or consent work |
| [0004](0004-native-shell-borrows-pulse.md) | The native shell ports Pulse's placement code | Dock or shell work |
| [0005](0005-web-cockpit-prerendered-porthole.md) | Web cockpit; prerendered porthole | Cockpit or porthole work |
| [0006](0006-proof-levels-and-review-tiers.md) | Proof levels and review tiers | Declaring anything fixed or done |
| [0007](0007-maker-colours-one-table.md) | Maker colours come from one table (`livery-table.ts`) | Any design, visual or colour work |
| [0008](0008-reference-apps-for-readers.md) | Reader, detection and metric work follows a reference app | Reader, detection, local-usage or metric work |

New ADRs take the next number, a `Status:` line with the owner's acceptance date and decision ID, and sections Context, Decision, Consequences.
