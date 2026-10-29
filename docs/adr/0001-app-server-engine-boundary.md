# The app talks to one long-lived engine process

Status: accepted by the owner on 2026-10-29.

## Context

The Mac app ran a short-lived `modelplan` subcommand for each request: `desktop`, `consent`, `consent grant`, `quota --refresh-account`, `detect` and `publication`. Every call had its own timeout, `busy` handling, environment, size cap and hand-written decoder. Beta07 respin1 to respin5 each failed on one of these seams. Respin5 failed because a hand-written Swift type required a field that Go omits, which emptied the Dock.

CodexBar links one Swift core library into both its app and its CLI. That design needs readers in the app's language. Codex connects its IDE and desktop clients to `codex app-server` over JSON-RPC on stdio. Our Go readers also serve the CLI, the Claude Code and Codex plugins and the Skill, so moving the readers into Swift would give us two reader implementations that drift apart.

## Decision

- Go stays the only data engine.
- The app starts the bundled `modelplan app-server` as a private child process. It speaks JSON-RPC 2.0 over stdio and is versioned with a handshake.
- The app-server pushes rows and serves consent, credentials, refresh, history, cockpit, publication, plugin install and diagnostics. See `schema/app-cli/app-server.md`.
- Swift types are generated from the Go types. Decoding is isolated per feature.
- The standalone CLI commands stay unchanged for other clients.

## Consequences

- Per-command timeouts and detached refresh workers disappear from the app path, and one scheduler applies the shared budget.
- Cross-process safety stays, because independent CLI copies still run: provider locks, `consent.ReaderLock` admission, the atomic `consent.Publish`, and Forget synchronization.
- Each child gets an app-generated `sessionId`. Message ordering is compared only within a session, and the consent-generation floor survives restarts.
- The app gains a process to supervise: handshake, restart with backoff, and an "engine restarting" summary state.
- Hand-written engine decoders and the Swift merge code are deleted in the wave that completes their replacement. The new call chain, its consent fence, the real package and its regressions must pass first. Historical regression scenarios stay.
- A future Windows or Linux UI can use the same process and protocol.
