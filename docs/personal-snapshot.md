# Personal snapshot (schema v1)

`modelplan desktop --json` (CLI 0.5.25+) prints the **personal snapshot**: one document holding the user's own state that a desktop client renders. A mobile client will later receive the same document through sync. It is built on the user's machine from what the harnesses already write locally. Public recommendations are not in it: clients read the verified publication themselves (`/v1/client`, through the shared client reader).

Each run also does what the plugin hooks do:

- refreshes the Codex account reading, CodexBar and a stale publication in the background;
- records the local quota history and Codex speed measurement;
- arms switch-back.

It marks no advice as told. A client keeps its own notified keys.

`modelplan desktop --json --read-only` (CLI 0.5.27+) builds the same document without any of that. It reads the harness logs and Model Plan's own caches as they are, and it writes no file, starts no background process, asks Codex for no account reading and uses no network. It is read-only, not cache-only: it still parses the Codex rollouts. The advice comes from the stored readings and the current clock; nothing is armed or remembered. What keeps the data fresh is the default form, the status line and its hook, and `modelplan sync`. A client calls the default form on a slow cadence and the read-only form for frequent reads.

`--offline` keeps its meaning (no network and no background refresh); it still records history and speed and saves the advice state, so it is not read-only.

`cli/internal/snapshot/testdata/snapshot.json` is a complete example, kept in step with the CLI by its tests (`go test ./internal/snapshot -update` rewrites it). The desktop app's tests read it, so a change that breaks a client fails there.

## Top level

| Field | Meaning |
|---|---|
| `schemaVersion` | `1`. Later versions only add fields; a breaking change gets a new kind or version |
| `kind` | `"modelplan.personal-snapshot"` |
| `generatedAt` | When it was built (UTC) |
| `cliVersion` | The CLI that built it |
| `publication` | `{publicationId, publishedAt, checkedAt, verifiedAt, stale, lastError}` of the verified publication the figures come from; `null` before the first sync. `stale`: not checked for 48 hours |
| `sessions[]` | Each harness's current configuration (below) |
| `accounts[]` | The quota accounts, exactly as `modelplan quota --json` gives them: windows with pace, run-out, pools (Codex `reserve`), reset cards; `codexbar:<provider>` accounts when the user enabled CodexBar |
| `sources[]` | The status of each reader (`ok`, `missing`, …, with a reason) |
| `events[]` | Advice events (below), most urgent first |
| `measured[]` | The measured speed per configuration over the last 28 days, as in `modelplan history --json` |
| `recording` | Local quota history and speed measurement are on (`MODELPLAN_HISTORY` is not `off`) |
| `note` | The data boundary, in English |
| `dataRevision` | CLI 0.5.27+. A hash of what was observed: the accounts' readings (time, used share, reset, limit, window length, cards), the sessions' configuration, the readers' status, the speed ledger's rows, the publication id and `recording`. It leaves out `generatedAt` and everything the clock derives (`resetsInMinutes`, `elapsedPercent`, `projectedPercent`, `ageMinutes`, pace, staleness, events). The same revision means the same inputs, not the same document |
| `validUntil` | CLI 0.5.27+. The next instant at which the clock alone changes a verdict: a window's reset or pace threshold, its recent rate lapsing, an account reading going stale (60 minutes) or out of use (6 hours, for cached CodexBar and Codex account readings), a card expiry or its 48-hour lead, an advice lead (a public reset, a rate boundary, a switch-back's or better model's time in the menu bar), the publication going stale, and local midnight while `measured[]` has rows. `null` when nothing is due. Read again at or after it even when `dataRevision` is unchanged; never reuse an expired event or the allowance of a passed reset. Shares that move every minute (elapsed, projected) have no boundary, so a client showing them refreshes on its own cadence too |

A cached reading that ages out of use (a CodexBar or Codex account reading after 6 hours) changes the accounts, so it changes `dataRevision` too.

## `sessions[]`

One entry per harness that reported a model (`claude-code`, `codex`):

- `source`, `observedAt`, `attribution` (`current-thread` | `recent-thread`), `origin`, `stale`;
- `model`: `{harnessId, id, name, developerId}`. `id`, `name` and `developerId` are the publication's and are empty when the model is not listed there;
- `effort` and `recommended`: `{key, label, star}` for the effort in use (the harness default counts as ★) and the ★ effort. Both are `null` when the model is not listed. The ★ fallback in `effort` is kept for older clients only;
- `effortStatus` (CLI 0.5.27+): `reported` when the harness reported an effort, `unreported` when it did not (then `effort` is only the ★ fallback). A client draws an effort marker as the user's own only when it is `reported`;
- `vsRecommended`: `{abilityDelta, costRatio}` of the effort in use against ★, or `null` at ★;
- `speed`: `""` for standard, else the mode (`fast`, …);
- `headroom`, `deciding`, `pool`: the quota verdict of the session's account for the allowance it draws from.

## `events[]`

The events of `modelplan advise --json` (types, `suggest`, `alternative`, `current`, … as in the Skill reference), plus:

- `key`: the once-only key. Configuration advice (tight, surplus) is keyed per model and effort, a better model per model, effort and target. Notify once per key.
- `text`: `{zh, en}`, the full sentence.
- `short`: `{zh, en}` for a menu bar, such as `↑High ×1.37`, `↓★Med ×0.73`, `→Opus 5.5 ★Med ×0.52` or `↺★Med`. Absent when the event has none.
- `inMenuBar`: whether the Claude Code status line would show it now. A switch-back shows for a while after it appeared, a better model for a week.

## Privacy

The snapshot holds no prompts, replies, tool output, credentials, file paths or session ids. It carries window meters, the harness's model, effort and speed mode, and the measured figures. A Claude Code session on a custom endpoint also carries that endpoint's scheme, host and path (`ANTHROPIC_BASE_URL` without query or credentials), as `modelplan quota --json` does. Anything that sends it off the machine, such as a future mobile sync, must encrypt it end to end.
