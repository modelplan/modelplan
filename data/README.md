# ModelPlan open data

The reviewed data behind [modelplan.ai](https://modelplan.ai): coding plan tiers, prices and quota metering, which models each plan includes, peak and off-peak calendars, model identities and lineages, speed claims and the recommended-effort policies. 中文说明见下方。

- **Mirror, one way.** The data is edited and reviewed against official sources upstream; every change arrives here as a pull request from the `data-sync` workflow, so this directory's history is the public change log. Edits made here directly are overwritten. Something wrong or missing? [Report a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml).
- **Exact copies.** [`manifest.json`](manifest.json) lists every file with its SHA-256 and the ModelPlan release it came from; `node scripts/data-sync.mjs --check` verifies them. One key is removed before publishing: `fetchUrl`, an internal fetch route (the official page stays in `url`).
- **Live data.** The same data, combined with live observations, is served by the read-only API ([OpenAPI](https://modelplan.ai/openapi.json)) and read by the clients in this repo.
- **License.** Per-file SPDX identifiers in `manifest.json` are authoritative. The new original-data publication uses [CC BY-SA 4.0](LICENSE), with attribution to "ModelPlan (https://modelplan.ai)" and applicable ShareAlike duties. Earlier CC BY 4.0 grants remain valid; commercial reuse remains permitted. `real-api-pricing/` is third-party material under its own MIT license. Benchmark figures derived from Artificial Analysis are not in this directory; through the API they keep Artificial Analysis's terms.

<!-- files:start -->
| File | What it holds | License |
| --- | --- | --- |
| [`calibration/official-guidance.json`](calibration/official-guidance.json) | Vendors' own effort guidance and product defaults | CC-BY-SA-4.0 |
| [`client-harness-aliases.json`](client-harness-aliases.json) | Model names as Claude Code, Codex and other clients report them | CC-BY-SA-4.0 |
| [`model-developers.json`](model-developers.json) | Model developers | CC-BY-SA-4.0 |
| [`model-identities.json`](model-identities.json) | Reviewed model identities and names | CC-BY-SA-4.0 |
| [`real-api-pricing/LICENSE`](real-api-pricing/LICENSE) | Real API Pricing license | MIT |
| [`real-api-pricing/README.md`](real-api-pricing/README.md) | Real API Pricing seed (third party, MIT) | MIT |
| [`real-api-pricing/mapping.json`](real-api-pricing/mapping.json) | Real API Pricing display grouping | MIT |
| [`real-api-pricing/seed.json`](real-api-pricing/seed.json) | Real API Pricing observations (third party) | MIT |
| [`schemas/ranker-input.schema.json`](schemas/ranker-input.schema.json) | Ranker input schema | CC-BY-SA-4.0 |
| [`schemas/ranker-output.schema.json`](schemas/ranker-output.schema.json) | Ranker output schema | CC-BY-SA-4.0 |
| [`vendor-effort-defaults.json`](vendor-effort-defaults.json) | Current effort defaults and suggested starts from each vendor's client and API docs, shown beside ★ as a reference | CC-BY-SA-4.0 |
<!-- files:end -->

## 中文

这里是 [modelplan.ai](https://modelplan.ai) 背后经过审核的数据：Coding 套餐档位、价格与额度计量、各套餐包含的模型、高峰与优惠时段、模型身份与谱系、速度声明和推荐档位策略。

- **单向镜像**：数据在上游编辑、对照官方来源审核，每次变化由 `data-sync` 工作流以 PR 形式同步过来，这个目录的历史就是公开的变更记录。直接改这里会被下次同步覆盖；发现错误或缺漏请[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)。
- **原样副本**：[`manifest.json`](manifest.json) 列出每个文件的 SHA-256 和来源版本，`node scripts/data-sync.mjs --check` 可核验。发布前只去掉一个字段 `fetchUrl`（内部抓取路由，官方页面仍在 `url`）。
- **许可**：以 `manifest.json` 的逐文件标识为准；新发布的自产整理数据使用 [CC BY-SA 4.0](LICENSE)，保留署名及适用的相同方式共享要求，允许商用。此前 CC BY 4.0 授权继续有效。`real-api-pricing/` 是第三方资料，沿用其 MIT 许可。Artificial Analysis 的基准数据不在本目录；通过 API 获取时沿用其条款。
