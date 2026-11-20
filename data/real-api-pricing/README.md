# Real API Pricing observation seed and mapping

The offline seed imports every adopted row from
[Fei2411/real-api-pricing@35b06e01ea25dd0ee0d34cf43e4654042c286f84](https://github.com/Fei2411/real-api-pricing/tree/35b06e01ea25dd0ee0d34cf43e4654042c286f84) (the repository was named FeiZhuLulu/real-api-pricing at that commit).
It contains 299 subscription model observations (76 scenario keys) and 19 metered API observations, 318 total. Chart tiers, benchmark scores and raw third-party articles/images are omitted. `seed.json` is a whitelisted source capture, not approved official plan terms. Adopted/convention hashes refer to original upstream file bytes; the seed deliberately does not recreate the original full files.

`mapping.json` is a reviewed **display grouping proposal**, covering every source key. It does not approve model identities, regions, provider qualifications or official plan links. Unknown future keys remain browsable with an unmapped product. MiniMax Token Plan and M Plan remain separate; busy/idle, day/night, modes, customer groups and annual/monthly observations retain their scenario identities.

Original project code/documentation license is [MIT](LICENSE), copyright 2026 Fei2411 (the notice at the pinned commit reads FeiZhuLulu, the owner's former name). Keep this attribution when redistributing substantial project material. Third-party research evidence has its own rights. Public output contains economic values, original-source labels/links and bounded upstream interpretation; it never republishes full third-party articles or screenshots.

Some rows rest on [Awesome Coding Plan](https://github.com/mahonzhan/awesome-coding-plan), by mahonzhan, licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/): `chatgpt_plus` × `gpt-5.6-sol` (source `awesome-coding-plan 2026-07-30`) and the rows derived from it (`chatgpt_plus` Terra and GPT-5.5 by credit-price ratio; the `chatgpt_pro_5x` / `chatgpt_pro_10x` rows by the official multiplier). Changes: Real API Pricing mapped the measurement to served-model identities, normalised it to four-week months and scaled it; ModelPlan divides by four for weekly pools. `shared/quota-capacity.ts` (`awesomeCodingPlanRows`) marks these pools with `attribution: "awesome-coding-plan"` in `/v1/quota-capacity`. Not endorsed by the creator.

## Public contract

`shared/plan-knowledge.ts` defines the strict browser/Worker-compatible DTO at
`publication.components.plans.data.knowledge`. `/v1/plan-knowledge` and MCP `get_plan_knowledge` read a complete pinned publication. Older publications return `data:null`; readers do not splice the offline seed into them.

Prices retain raw quotes separately from USD monthly comparison fees. An explicitly stated annual fee is a yearly payment; its monthly equivalent is not a monthly sale price. Unknown totals remain null. Measured workload does not inherit 97% cache. Promotional zero blended cost is retained as the upstream observation but no unlimited capacity or zero monthly subscription is inferred. Shared model capacities must never be added.

The current Kimi domestic-capacity/international-price combination and Alibaba international capacity copied from China are explicitly diagnosed. GLM midpoint is arithmetic, not an actual calendar window. Time-window remarks remain source clues; only separately reviewed rules enter calendar data.

## Refresh and review

The producer SourceHub polls at six-hour source cadence. It first fetches the GitHub commit with conditional ETag, then adopted CSV and calculation conventions at that same immutable commit. `REAL_API_PRICING_COMMIT=<40-character SHA>` optionally fixes the requested upstream version. No upstream scripts execute and no paid AI is required. Network needs `api.github.com` and `raw.githubusercontent.com`; unavailable transport leaves the complete last-good seed/capture in place.

Source changes append content-addressed added/updated/withdrawn events to private durable SourceHub state and their strict public projection. Repeated captures do not duplicate events. A changed calculation convention or large catalogue drop is quarantined against the current baseHash and appears as review-required. Continue publishing the previous complete catalogue until reviewed with the existing `scripts/review-snapshot.ts` command. Mapping revisions require a code/data PR. The public event history is bounded to the latest 2000 records; immutable publications and private source snapshots preserve prior releases.

Catalogue observations never modify official `plans`, `coverage`, rules, Index coordinates, native effort recommendations or local quota/account state. Actual scheduled publication is delivered by the separate CI ticket; this adapter does not turn on a production schedule.
