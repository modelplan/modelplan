# Model Plan open data

The reviewed data behind [modelplan.ai](https://modelplan.ai): coding plan tiers, prices and quota metering, which models each plan includes, peak and off-peak calendars, model identities and lineages, speed claims and the recommended-effort policies. 中文说明见下方。

- **Mirror, one way.** The data is edited and reviewed against official sources upstream; every change arrives here as a pull request from the `data-sync` workflow, so this directory's history is the public change log. Edits made here directly are overwritten. Something wrong or missing? [Report a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml).
- **Exact copies.** [`manifest.json`](manifest.json) lists every file with its SHA-256 and the Model Plan release it came from; `node scripts/data-sync.mjs --check` verifies them. One key is removed before publishing: `fetchUrl`, an internal fetch route (the official page stays in `url`).
- **Live data.** The same data, combined with live observations, is served by the read-only API ([OpenAPI](https://modelplan.ai/openapi.json)) and read by the clients in this repo.
- **License.** [CC BY 4.0](LICENSE): use, adapt and share it, including commercially, crediting "Model Plan (https://modelplan.ai)". `real-api-pricing/` is third-party material under its own MIT license. Benchmark figures derived from Artificial Analysis are not in this directory; through the API they keep Artificial Analysis's terms.

<!-- files:start -->
| File | What it holds | License |
| --- | --- | --- |
| [`calendar-rule-registry.json`](calendar-rule-registry.json) | Reviewed calendar rules: peaks, off-peak hours, promotions and quota resets | CC-BY-4.0 |
| [`calibration/balanced-coding-v2.json`](calibration/balanced-coding-v2.json) | Recommended-effort policy, v2 | CC-BY-4.0 |
| [`calibration/balanced-coding-v3.1.json`](calibration/balanced-coding-v3.1.json) | Recommended-effort policy, v3.1 | CC-BY-4.0 |
| [`calibration/balanced-coding-v3.json`](calibration/balanced-coding-v3.json) | Recommended-effort policy, v3 | CC-BY-4.0 |
| [`calibration/balanced-coding-v4.json`](calibration/balanced-coding-v4.json) | Recommended-effort policy, v4 | CC-BY-4.0 |
| [`calibration/generic-policy.json`](calibration/generic-policy.json) | Generic quality, cost and time policy | CC-BY-4.0 |
| [`calibration/official-guidance.json`](calibration/official-guidance.json) | Vendors' own effort guidance and product defaults | CC-BY-4.0 |
| [`client-harness-aliases.json`](client-harness-aliases.json) | Model names as Claude Code, Codex and other clients report them | CC-BY-4.0 |
| [`coding-tool-models.json`](coding-tool-models.json) | Models advertised by coding tools | CC-BY-4.0 |
| [`core-plan-evidence.json`](core-plan-evidence.json) | Evidence behind the core subscription plans | CC-BY-4.0 |
| [`core-plan-registry.json`](core-plan-registry.json) | Core subscription plans (generated from plan-tier-registry.json) | CC-BY-4.0 |
| [`current-model-products.json`](current-model-products.json) | Current model products | CC-BY-4.0 |
| [`current-openai-pro-offerings.json`](current-openai-pro-offerings.json) | Current ChatGPT Pro offerings | CC-BY-4.0 |
| [`current-public-plan-registry.json`](current-public-plan-registry.json) | Current public subscription plans (generated) | CC-BY-4.0 |
| [`current-token-plan-registry.json`](current-token-plan-registry.json) | Current token and credit plans (generated) | CC-BY-4.0 |
| [`current-tool-plan-registry.json`](current-tool-plan-registry.json) | Current coding tool plans (generated) | CC-BY-4.0 |
| [`default-lineages.json`](default-lineages.json) | Default model lineages per developer | CC-BY-4.0 |
| [`model-developers.json`](model-developers.json) | Model developers | CC-BY-4.0 |
| [`model-identities.json`](model-identities.json) | Reviewed model identities and names | CC-BY-4.0 |
| [`official-model-lineages.json`](official-model-lineages.json) | Official model lineages | CC-BY-4.0 |
| [`plan-change-log.json`](plan-change-log.json) | Reviewed vendor changes to plans, as shown in Mission Briefing | CC-BY-4.0 |
| [`plan-display-en.json`](plan-display-en.json) | English display text for plan notes | CC-BY-4.0 |
| [`plan-edition-groups.json`](plan-edition-groups.json) | Plan edition groups (China and international editions) | CC-BY-4.0 |
| [`plan-index-aliases.json`](plan-index-aliases.json) | Plan model names mapped to index models | CC-BY-4.0 |
| [`plan-metering.json`](plan-metering.json) | How each plan meters usage: windows, limits, multipliers | CC-BY-4.0 |
| [`plan-model-access.json`](plan-model-access.json) | Which models each plan includes | CC-BY-4.0 |
| [`plan-price-observations.json`](plan-price-observations.json) | Observed plan prices | CC-BY-4.0 |
| [`plan-product-lines.json`](plan-product-lines.json) | Plan product lines | CC-BY-4.0 |
| [`plan-providers.json`](plan-providers.json) | Plan providers | CC-BY-4.0 |
| [`plan-tier-registry.json`](plan-tier-registry.json) | Subscription tiers: the source the plan registries are generated from | CC-BY-4.0 |
| [`real-api-pricing/LICENSE`](real-api-pricing/LICENSE) | Real API Pricing license | MIT |
| [`real-api-pricing/README.md`](real-api-pricing/README.md) | Real API Pricing seed (third party, MIT) | MIT |
| [`real-api-pricing/mapping.json`](real-api-pricing/mapping.json) | Real API Pricing display grouping | MIT |
| [`real-api-pricing/seed.json`](real-api-pricing/seed.json) | Real API Pricing observations (third party) | MIT |
| [`reviewed-plan-registry.json`](reviewed-plan-registry.json) | Reviewed plans (generated) | CC-BY-4.0 |
| [`reviewed-speed-claims.json`](reviewed-speed-claims.json) | Reviewed vendor speed claims | CC-BY-4.0 |
| [`reviewed-speed-tiers.json`](reviewed-speed-tiers.json) | Reviewed speed tiers (fast modes) | CC-BY-4.0 |
| [`schemas/ranker-input.schema.json`](schemas/ranker-input.schema.json) | Ranker input schema | CC-BY-4.0 |
| [`schemas/ranker-output.schema.json`](schemas/ranker-output.schema.json) | Ranker output schema | CC-BY-4.0 |
| [`time-policy-inventory.json`](time-policy-inventory.json) | Time-of-day quota and price rules per product line: modelled, none found or unverified, with the sources that state them | CC-BY-4.0 |
| [`tool-plan-facts-history.json`](tool-plan-facts-history.json) | Frozen usage facts of coding tool plans | CC-BY-4.0 |
<!-- files:end -->

## 中文

这里是 [modelplan.ai](https://modelplan.ai) 背后经过审核的数据：Coding 套餐档位、价格与额度计量、各套餐包含的模型、高峰与优惠时段、模型身份与谱系、速度声明和推荐档位策略。

- **单向镜像**：数据在上游编辑、对照官方来源审核，每次变化由 `data-sync` 工作流以 PR 形式同步过来，这个目录的历史就是公开的变更记录。直接改这里会被下次同步覆盖；发现错误或缺漏请[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)。
- **原样副本**：[`manifest.json`](manifest.json) 列出每个文件的 SHA-256 和来源版本，`node scripts/data-sync.mjs --check` 可核验。发布前只去掉一个字段 `fetchUrl`（内部抓取路由，官方页面仍在 `url`）。
- **许可**：[CC BY 4.0](LICENSE)，可自由使用、改编和商用，注明 “Model Plan (https://modelplan.ai)”。`real-api-pricing/` 是第三方资料，沿用其 MIT 许可。Artificial Analysis 的基准数据不在本目录；通过 API 获取时沿用其条款。
