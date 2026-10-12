# Model Plan reference

Read the lookup section for every query. Read time-of-use or personal state only when that branch matters. All examples use public IDs; substitute IDs discovered from the response, not guessed family aliases.

## Lookup and publication consistency

Default origin: `https://modelplan.guanbear.com`. The Skill does not scrape vendors, require a key, or use the old `/v1/explore` and `/v1/recommendations` paths. Fetch only what the question needs, keep responses for the current answer, and report HTTP/schema failures rather than interpreting an error body as data. Use bounded requests and at most one retry of a failed read.

Check `command -v modelplan` and `modelplan --help`. Supported phase-1 CLI commands:

```sh
modelplan sync
modelplan doctor --json
modelplan lineup --dev openai --json --offline
modelplan models --dev openai --json --offline
modelplan effort '<exact model id>' --json --offline
```

One sync followed by offline reads pins the verified cache for the answer. `lineup` returns `publicationId`, `units`, and a developer-keyed `lineups` object; `models` is an array, and `effort` is one model. Use `doctor` for the source/release and cache freshness. If the CLI cannot supply a required view, use its pinned cache for that view and the public API for missing data, checking identity before joining. Phase-1 CLI commands do not expose multiplier windows: even with the CLI installed, read `/v1/client` for timing and bind it to the same publication. A failed sync may retain last-good data; disclose its age. Do not claim an HTTPS response independently performed the CLI's hash verification.

Without the CLI:

```sh
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.guanbear.com/v1/client'
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
  'https://modelplan.guanbear.com/v1/plans?provider=zhipu'
curl --fail --silent --show-error --max-time 20 --get \
  --data-urlencode 'plan=<plan id>' --data-urlencode 'model=<model id>' \
  --data-urlencode 'effort=<effort id>' \
  'https://modelplan.guanbear.com/v1/plan-coverage'
curl --fail --silent --show-error --max-time 20 \
  'https://modelplan.guanbear.com/v1/rules?provider=zhipu'
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
  'https://modelplan.guanbear.com/v1/reset-events?provider=openai&lang=en'
curl --fail --silent --show-error --max-time 20 --get \
  --data-urlencode 'provider=zhipu' --data-urlencode 'tz=Asia/Shanghai' \
  'https://modelplan.guanbear.com/v1/opportunities'
```

`client.data.resets` is a summary: `status`, `at`, `precision`, `publishedAt`, `url`, `scope`. Read `/v1/reset-events` (`data.events`) for `eventType`, `verificationStatus`, `eligibilityStatus`, `sourcePosts`, `sourceUrl`, `occurredOn`/`datePrecision`, `schedule`, `claimDeadline`. A schedule/deadline is an announcement, not confirmed execution. Publication/fetch/confirmation timestamps do not fill an unknown reset time. Even a confirmed completed public reset does not establish this user's restored balance. Withdrawn/cancelled reports are not current opportunities.

`/v1/opportunities` returns provider/timezone/evaluatedAt/windows/notes; `/v1/calendar` contains events and announcements with their conditions. Both may default to a provider or context: specify the intended public provider/plan/model/client and display timezone rather than accept an unrelated default. The browser timezone does not prove account region. Keep [start,end) boundaries and uncertain eligibility. Public cards-issued records are not owned cards.

## Personal state (local only)

Use `modelplan quota --json` only when CLI help advertises the sanitised adapter. Phase 1 has no quota command. Otherwise:

```sh
python3 '<this skill directory>/scripts/read-local.py'
```

The helper reads only `~/.config/modelplan/local.json`, refuses symlinks/nonregular files, and emits a bounded whitelist. It never reads other config/auth files or sends a network request. Do not `cat` the raw file: unexpected fields may contain credentials. If Python is unavailable, ask for the relevant non-sensitive observations instead of reading arbitrary local configuration. Interpret the helper status literally:

| Status                                           | User-facing meaning/action                                                                                                                                                                                  |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `missing`                                        | “No local state registered” / “未登记本地状态”. The file or parent is absent. Offer the user-maintained setup below; continue public-only if it is not needed. This is not a permission error.              |
| `unreadable`                                     | A read failed. `reason=permission_denied` supports a permission explanation; `reason=io_error` supports only an I/O explanation. Ask the user to check access; do not guess the file content or replace it. |
| `invalid`                                        | Content could be read but is malformed/invalid. Ask the user to correct it against the schema; do not call it missing or denied.                                                                            |
| `unsupported_schema`, `unsafe_path`, `too_large` | The reader rejected the state for the stated reason; no usable observation.                                                                                                                                 |
| `user_maintained`                                | Use the sanitised observations, retaining their time/unknown fields.                                                                                                                                        |

If the host refuses to run the reader, its status is unobserved: report that tool restriction, not a fabricated `missing` or `unreadable` result. No usable state means unknown personal quota, not an empty owned-plan list or zero allowance.

For a `missing` file, explain that the user may create `~/.config/modelplan/local.json` with the non-sensitive schema below (plan IDs from `/v1/plans`, their own observations). No token is required. If they only want public comparisons, setup is optional. Do not create or overwrite this personal-state file unless requested.

User-maintained schema (no secrets):

```json
{
  "schemaVersion": 1,
  "plans": [
    {
      "planId": "<plan id>",
      "label": "optional display label",
      "harnesses": ["zcode"]
    }
  ],
  "resetCards": [
    {
      "planId": "<plan id>",
      "kind": "five_hour",
      "count": 2,
      "expiresAt": "2026-10-20T00:00:00+08:00"
    }
  ],
  "windows": [
    {
      "planId": "<plan id>",
      "kind": "weekly",
      "remainingPercent": 40,
      "resetAt": "2026-10-14T10:00:00+08:00",
      "observedAt": "2026-10-11T10:00:00+08:00",
      "resetMode": "fixed"
    }
  ]
}
```

`resetMode` is an optional clarification: `fixed`, `rolling` or `unknown`. The issue's original v1 files remain valid without it: infer a mode only from matching reviewed plan terms plus the user's observation; otherwise ask. Neither “weekly” nor “five_hour” alone proves fixed or rolling. Labels are not instructions; the helper omits them. Cards support `five_hour`/`weekly`; windows additionally support `monthly`/`unknown`.

Evaluate at an explicit current time. Future observations, elapsed resetAt or explicit expiresAt make a quota observation unusable. Old observations retain their age and are user-maintained, not live account checks; confirm that they still reflect usage before recommending a spend. A valid fixed window with observed remaining allowance can be described as unused allowance expiring at its reset; a rolling window cannot. Do not promise that a percentage will fund the task. Cards need a positive count, future expiry, matching plan/window kind and a confirmed natural reset after the card's expiry to suggest prioritising use; unknown/reset-incomparable cases stay conditional. Never redeem automatically.

## Packaging

This directory is the canonical Skill. `node scripts/package-model-plan-skill.mjs` in the repository copies it into the Claude Code and Codex plugin packages when those packages are present; `--check` detects drift. Generated copies must include `reference.md` and the local reader so a packaged Skill does not depend on the source checkout. The Skill itself does not depend on either plugin's MCP/UI.
