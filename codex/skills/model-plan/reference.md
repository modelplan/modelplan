# Model Plan reference

Read the lookup section for every query. Read time-of-use or personal state only when that branch matters. All examples use public IDs; substitute IDs discovered from the response, not guessed family aliases.

## Lookup and publication consistency

Default origin: `https://modelplan.ai`. The Skill does not scrape vendors, require a key, or use the old `/v1/explore` and `/v1/recommendations` paths. Fetch only what the question needs, keep responses for the current answer, and report HTTP/schema failures rather than interpreting an error body as data. Use bounded requests and at most one retry of a failed read.

Check `command -v modelplan` and `modelplan --help`. CLI commands:

```sh
modelplan sync
modelplan doctor --json
modelplan lineup --dev openai --json --offline
modelplan models --dev openai --json --offline
modelplan effort '<exact model id>' --json --offline
modelplan quota --json            # v0.3+: local quota report, see "Personal state"
modelplan advise --json           # v0.4+: current hints derived from quota + publication
```

`modelplan effort --json` adds `speedTiers` for the model (v0.4+): `{id, harness, tier, label, toggle, eligibility, model:{vendorModelId, modelId, speed}, billing[], caveats[]}`; the text view prints them under the ladder (`⚡ Codex Fast  plan quota ×2.5 · credits ×2 · speed-up not stated`). Within one model on one plan, an effort's quota burn under a tier is roughly its cost ratio × the tier's `plan-quota` ratio; say it is an estimate. A `usage-credits` tier (Claude Code fast mode) costs money even with plan allowance left.

`advise` events (most urgent first): `window_exhausted`, `window_tight`, `reset_passed_switch_back`, `reset_soon_with_surplus`, `peak_starts_soon`, `offpeak_starts_soon`, `cards_expiring`, `public_reset_announced`. Each has `source`, `window`, `at`/`inMinutes`, `remainingPercent`, the harness `model`/`effort`, and `suggest` = `{action, model, effort, label, recommended, abilityDelta, costRatio}` against the current configuration (`step_up`, `stronger_model`, `step_down`, `switch_back`, `wait`, `use_card`, `none`), plus `text.zh`/`text.en`. Use them as the starting point for quota questions and relay the arithmetic as given. `reset_passed_switch_back` exists only because the CLI remembers windows it advised on; the Skill alone cannot know it.

Without `--json`, `modelplan effort` prints the ladder with both views: each effort against ★ and against the step below (`↑ +3.7分 ×1.45`).

One sync followed by offline reads pins the verified cache for the answer. A CLI older than v0.2.2 cannot read the current publication (`manifest: incompatible graph`); suggest updating it and use HTTPS meanwhile. `lineup` returns `publicationId`, `units`, and a developer-keyed `lineups` object; `models` is an array, and `effort` is one model. Use `doctor` for the source/release and cache freshness. If the CLI cannot supply a required view, use its pinned cache for that view and the public API for missing data, checking identity before joining. CLI commands do not expose multiplier windows: even with the CLI installed, read `/v1/client` for timing and bind it to the same publication. A failed sync may retain last-good data; disclose its age. Do not claim an HTTPS response independently performed the CLI's hash verification.

Without the CLI:

```sh
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.ai/v1/client'
```

REST JSON is an envelope: `schemaVersion`, `releaseVersion`, `publication`, `asOf`, `sourceSnapshots`, `data`. The publication ID is **`publication.publicationId`**, not a top-level field. Reject unsupported schema. CLI JSON and REST data have different wrappers but the same published model/lineup semantics. REST `data.lineups` is an array keyed by `developerId`; CLI `lineups` is an object. Never rebuild an absent lineup.

Use one publication for joined numbers. Supplementary requests should match `publication.publicationId`. Some legacy calendar envelopes omit that ID: compare `publication.publicationVersion`, release and as-of to the client envelope, and disclose the weaker binding. If identities differ, retry the affected reads once; if still inconsistent, retain one complete view and label the other supplementary/unjoined. Query generation time is not source freshness; preserve source evidence dates and stale/review flags.

## Model and lineup fields

| Field                                    | Meaning                                                                                              |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `data.units`                             | `ability=websiteAbility`, `cost=usdPerReferenceTask`, `time=taskTimeCrossModel`                      |
| `models[].id`, `developerId`, `name`     | Exact model-version identity and研发厂商; not a plan/channel                                         |
| `current`                                | Published current selection; not a guarantee of account entitlement                                  |
| `recommended`                            | Model Plan native ★ effort ID, or null; no model-specific fallback invented by the Skill             |
| `harnessIds`, `harnessEvidence`          | Reviewed exact aliases, qualification and required endpoint conditions; not proof of personal access |
| `efforts[].effort`, `label`, `available` | Native measured/available configuration in this view; do not invent missing efforts                  |
| `ability`, `abilityBasis`                | Published points; not a percentage success rate. Never use `abilityIndex` instead                    |
| `cost`, `costBasisId`                    | Approximate USD per declared reference task; not a subscription deduction or arbitrary task quote    |
| `time`, `timeEstimated`, `timeBasis`     | Task-time multiplier with source/cohort/boundary/reference seconds; not AA generation time or TTFT   |

The Go CLI uses the same model keys; its `cost` is USD, not the old unitless expense index. Null is unknown; real zero remains zero. A zero-cost configuration cannot define a cost ratio. For effort comparisons, show each configuration's own ability/cost. Compute simple differences/ratios only with a shared basis and positive denominator; identify the baseline, and do not modify ★. Compare time only with compatible source, cohort and boundary; an estimated ratio remains estimated. Do not turn a benchmark time into a promised completion deadline.

★ and lineup tags are Model Plan's published advisory policy, not the vendor's official effort default or a task-fit guarantee.

`lineups[]`: `developerId`, `costBasisId`, `method`, `tie`, `baseline`, `frontier`, `steps`, `members`.

- `members[].tags`: `cheapest`, `strongest`, `best_value`, `equivalent_costlier`, `dominated`; one member can have several.
- `dominatedBy` is the published comparison, including its `equivalent`/`weaker` kind. “Equivalent” follows the declared product tolerance, not a statistical confidence interval.
- `costRelative` is relative to the lineup baseline, not this model's ★ effort. `steps[].abilityDelta` and `costRatio` describe published frontier steps.
- `status=incomplete` cannot prove sufficiency or a cheapest/best-value verdict. Missing lineup means no published verdict, not permission to rebuild it.
- Across makers, compare available configurations on a shared cost basis without inventing a global frontier/tag. State task-fit reasoning and any missing evidence separately.

## Plans, access and time of use

Use public IDs only; never place balances, reset-card counts, tokens or task text in URLs.

```sh
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.ai/v1/plans?provider=zhipu'
curl --fail --silent --show-error --max-time 20 --get \
  --data-urlencode 'plan=<plan id>' --data-urlencode 'model=<model id>' \
  --data-urlencode 'effort=<effort id>' \
  'https://modelplan.ai/v1/plan-coverage'
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.ai/v1/rules?provider=zhipu'
```

`/v1/plans` data is an array; read the precise plan's `provider`, `region`, `generation`, `models`, `clients`, `quotaTerms`, conditions and source dates. Domestic `zhipu` and international `zai` are distinct scopes. Coverage data is an array: check `modelStatus` and `effortStatus` (or selected `effortStatuses`), `channel`, qualification, validity and source flags. Unknown is not available, and conditional is not confirmed entitlement. A model's harness alias and a plan's advertised list do not replace exact coverage.

### Published multiplier windows (first)

`/v1/client` projection `client-v1.1` publishes `data.multipliers` and `data.multiplierHorizon = {from, to, selection:"highest-priority-no-stacking"}`. These are producer-resolved quota coefficients, including generation-specific holiday and other-client fallbacks. Use them as published; do not expand raw recurring rules, apply relative factors or perform timezone/DST arithmetic for a covered instant.

1. Check the requested instant is in `[multiplierHorizon.from, multiplierHorizon.to)`. Keep this published horizon, normally 48 hours from build; do not extend it from the current clock. A missing pack in an older projection means timing unavailable, not an empty verified forecast.
2. Match `startsAt <= at < endsAt` using absolute ISO instants. `timezone` is for display/provenance. Match `provider`, `planIds`, `generations`, `region`, `models`, `clients` exactly. Model/tool selectors are published labels (e.g. `GLM-5.3`, `Claude Code`), not necessarily client model/harness IDs; use reviewed plan/model identities rather than substrings. Empty scope arrays are unrestricted; unknown required context is unknown, not a wildcard.
3. Respect `minClientVersions`, `requiresQuotaAvailable` and `conditions`. A confirmed mismatch excludes that scenario; missing required version/quota/context retains uncertainty. Only an explicitly compatible normal/fallback entry may replace it. Do not borrow a lower coefficient from another generation, plan, region or tool.
4. Choose one highest numeric `priority` among matching and possibly matching scenarios. A possibly applicable higher-priority entry cannot be silently discarded in favour of a confirmed cheaper one. `TENTATIVE`, null multiplier, unknown conditions, or conflicting top-priority coefficients give an unknown resolved rate (`needs_confirmation`). You may cite a TENTATIVE coefficient as a clearly provisional reported value, never a guaranteed discount or free entitlement. Even `CONFIRMED` public evidence does not prove account entitlement.
5. To consider waiting, use the published future boundaries and re-select the applicable entry there, within the same horizon. Give the absolute next-start time and elapsed wait. A lower future rate with uncertain evidence stays conditional; a published end is exclusive. Do not equate “peak ends” with an assured new discount.

### Condition details and beyond-horizon lookup (second)

`/v1/rules` has `data.rules` and `data.unresolved`; consult it for qualifications/source explanations or when the requested time lies beyond the digest's horizon. Do not use it to replace a covered published multiplier, promote tentative evidence, multiply rules, or invent an unresolved factor. Raw records retain plan/generation/region/models/clients, kind, priority, validity, timezone, hour/minute/weekday bounds and tool/quota requirements. These are evidence details, not a second client ranking policy.

Outside the horizon, prefer server-expanded `/v1/calendar` intervals for the explicitly requested public scope/date; check raw rule conditions and source validity as supplementary evidence. If a compatible future interval/coefficient is not published or needs unverified expansion, keep it unknown and say a refresh/confirmation is needed. Never imply an expired 48-hour pack covers the requested future day. A new credits-plan rate cannot replace a legacy-plan rate.

The multiplier describes **plan quota deduction**. Keep `cost` USD unchanged; never multiply it by that quota rate or claim zero-rate plan use is a free API. Percent remaining cannot be converted into tokens or task counts. A `wait` requires a known improving boundary and a feasible deadline; otherwise explain the optional wait or use `needs_confirmation`.

## Public resets and opportunities

```sh
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.ai/v1/reset-events?provider=openai&lang=en'
curl --fail --silent --show-error --max-time 20 --get \
  --data-urlencode 'provider=zhipu' --data-urlencode 'tz=Asia/Shanghai' \
  'https://modelplan.ai/v1/opportunities'
```

`client.data.resets` is a summary: `status`, `at`, `precision`, `publishedAt`, `url`, `scope`. Read `/v1/reset-events` (`data.events`) for `eventType`, `verificationStatus`, `eligibilityStatus`, `sourcePosts`, `sourceUrl`, `occurredOn`/`datePrecision`, `schedule`, `claimDeadline`. A schedule/deadline is an announcement, not confirmed execution. Publication/fetch/confirmation timestamps do not fill an unknown reset time. Even a confirmed completed public reset does not establish this user's restored balance. Withdrawn/cancelled reports are not current opportunities.

`/v1/opportunities` returns provider/timezone/evaluatedAt/windows/notes; `/v1/calendar` contains events and announcements with their conditions. Both may default to a provider or context: specify the intended public provider/plan/model/client and display timezone rather than accept an unrelated default. The browser timezone does not prove account region. Keep [start,end) boundaries and uncertain eligibility. Public cards-issued records are not owned cards.

## Effort ladder arithmetic

Lead with multipliers. For efforts `lo` → `hi` of one model, both with ability and positive cost on the same `costBasisId`: step = `hi.ability - lo.ability` points and `hi.cost / lo.cost`. Against ★: the same with ★ as `lo`. Round points to one decimal and ratios to two. Time ratios need both `timeBasis` objects equal; keep `timeEstimated` as "estimate". Within one model on one subscription, the cost ratio is the best available estimate of how much faster a step burns quota; say so. Never multiply USD by a quota multiplier, and never turn a percentage into a token or task count.

## Personal state (local only)

Run exactly one of:

```sh
modelplan quota --json                              # when the CLI advertises `quota`
python3 '<this skill directory>/scripts/quota.py'   # otherwise; standard library only
```

Both print the same report and read only:

| Source | File | Notes |
| --- | --- | --- |
| `claude-code` | `<cache>/observed/claude-code.json` | Written by `modelplan statusline` from the `rate_limits`, `effort` and `fast_mode` Claude Code passes to the status line. Present only for claude.ai Pro/Max (or a gateway spend limit) and once the status line has run |
| `codex` | `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl` (default `~/.codex`) | Only the latest `token_count` → `rate_limits` (used %, window minutes, reset time, plan type) and `turn_context` model/effort. Message content is never decoded |
| `user` | `~/.config/modelplan/local.json` | Maintained by the user; schema below |

Report shape: `accounts[]` with `source`, `plan`, `observedAt`, `stale` (older than 60 min), `harness {model, effort, fastMode, version, serviceTier, observedAt, attribution, origin}` (Codex: `attribution` is `current-thread` when `CODEX_THREAD_ID` named the thread, else `recent-thread`, the newest interactive thread; background review threads such as `codex-auto-review` never supply it; an empty `effort` means the turn named none, i.e. the model's default), `windows[]`, `cards[]`, `headroom` (`spend` / `normal` / `conserve` / `exhausted` / `unknown`) and `deciding` (the window kind that set it). Each window: `kind` (`five_hour`, `weekly`, `monthly`, `spend`, `unknown`), optional `limit` (a non-default Codex limit id; windows are merged across recent Codex threads, newest reading per limit id and window, each with its own `observedAt`/`ageMinutes`), `usedPercent`, `windowMinutes`, `resetsAt`, `resetMode`, `remainingPercent`, `resetsInMinutes`, `elapsedPercent`, `projectedPercent` (used share at reset if the current pace holds; only after 10% of the window), `ageMinutes`, `pace`.

Pace rules (identical in Go and Python, tested against shared fixtures): `exhausted` at ≥100% used; `tight` at ≥90% or when projected use exceeds 100% after 20% of the window; `surplus` with ≥30% left and either the reset within the last quarter of the window or projected use ≤60% after half of it; otherwise `on_track`. Rolling or reset-less windows only get `tight`/`exhausted`. Headroom takes the longest window first: any `exhausted` → `exhausted`; any `tight` → `conserve`; an `on_track` window projected above 80% → `normal`; otherwise any `surplus` → `spend`.

`sources[]` gives each source's status: `ok`, `missing`, `empty` (Codex logs without a rate-limit snapshot, e.g. API-key login), `invalid`, `unreadable`, `unsafe_path`, `too_large`, `unsupported_schema`. Interpret literally: `missing` means nothing recorded yet, not a permission problem. If the host refuses to run the reader, say so instead of inventing a status. No usable state means unknown quota, not zero.

How the user turns readings on, when they ask or when it would change the advice:

- **Claude Code**: install the Model Plan plugin and run `/modelplan:statusline` (or set `"statusLine": {"type": "command", "command": "modelplan statusline"}`). A user who keeps their own status line can record without displaying: `input=$(cat); printf %s "$input" | modelplan statusline --record-only` at the top of their script.
- **Codex**: nothing to set up. Readings appear after the first turn of a ChatGPT-login session.
- **Other plans**: create `~/.config/modelplan/local.json` with the schema below. Do not create or overwrite it unless asked.

User-maintained schema (no secrets):

```json
{
  "schemaVersion": 1,
  "plans": [{ "planId": "<plan id from /v1/plans>", "harnesses": ["claude-code"] }],
  "resetCards": [
    { "planId": "<plan id>", "kind": "five_hour", "count": 2, "expiresAt": "2026-10-20T00:00:00+08:00" }
  ],
  "windows": [
    {
      "planId": "<plan id>",
      "kind": "weekly",
      "remainingPercent": 40,
      "resetAt": "2026-10-16T10:00:00+08:00",
      "observedAt": "2026-10-14T10:00:00+08:00",
      "resetMode": "fixed"
    }
  ]
}
```

`resetMode` is `fixed`, `rolling` or `unknown` (default). Labels are dropped by the readers. A future or missing `observedAt` makes a reading unusable. Cards: suggest using them first only when the count is positive, the expiry is in the future and a confirmed natural reset comes after the expiry. Never redeem automatically.

Harness windows (`claude-code`, `codex`) are fixed until `resetsAt`, so allowance left at the reset is lost; that is what `spend` means. A user window marked `rolling` never implies expiring allowance.

## Packaging

`skills/model-plan` in github.com/modelplan/modelplan is the canonical Skill. `node scripts/package-skill.mjs` copies `SKILL.md`, `reference.md` and `scripts/quota.py` into the Claude Code and Codex plugins; `--check` (run in CI) fails on drift. The Skill does not depend on either plugin, the CLI or an MCP server.
