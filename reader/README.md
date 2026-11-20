# Public publication reader

MIT validation, integrity and caching for published data. This retains the verifier already shipped publicly in the Codex plugin. It does not compute model scores, fit parameters or choose recommendations. Runtime clients display production-published verdicts.

The private producer may consume a reviewed, hash-verified copy of this reader. Production scoring/recommendation source, full calibration records, input construction, entry/exit automation, acquisition/review/publication and official visuals remain private. Formula explanations and source weights remain in the methodology documents. No scoring engine or complete calibration snapshot belongs in this module.

Run `npm ci --prefix reader && npm test --prefix reader` (Node 24+). Source rebuilds require a full checkout; the packaged plugin uses its bundled runtime.

The verifier accepts optional published selection metadata: top-level `selectionRevision` and nullable per-model `lineageId`, `lineageStatus` (`current`, `older`, `preview`, `retired`) and `defaultSelected`. Historical and partial publications remain valid. These are producer verdicts; the reader validates their types and preserves them without computing a selection. Strict model validation, content hashes and dependency checks still apply.

An effort may carry `provisional: true` (absent otherwise; `false` is rejected): its ability rests on evidence outside the range its cross-source link was fitted on. It belongs to its own model's effort ladder only; the producer already leaves such configurations out of every cross-model lineup, so the reader preserves the flag without changing any lineup. Any other unknown effort field is still rejected.

From `projectionVersion: "client-v1.5"` an effort may carry `aaScore` (a finite number above 0, absent when unscored): the raw Artificial Analysis Intelligence Index score for that model and effort, the same value as the publication's model capability. Provisional efforts keep it. A top-level `aaIndexVersion` (non-empty string, for example `"4.3"`) names the index version and is present exactly when some effort carries `aaScore`. A digest below client-v1.5 that carries either field is rejected.

A lineup's `tie` is the ability gap treated as equal, in index display points: `1` on display scale 0.3 and `0.815` on scale 0.4 (the same gap re-expressed; verdicts are unchanged). Both are accepted so historical and current publications validate; any other value is rejected.

From `projectionVersion: "client-v1.6"` the digest may carry public API list prices and a usage trend; below client-v1.6 every one of these fields is rejected (`invalid_client_v16_projection`):

- `models[].price`: `{input, output, cacheRead?, cacheWrite?, source, asOf, longContext?}` in USD per 1M tokens. `input` and `output` are above 0; cache rates are 0 or more and absent (never null) when unpublished; `source` is `litellm` or `modelsdev`; `asOf` is a `YYYY-MM-DD` date. `longContext` (`aboveInputTokens`, a positive integer, plus the same rate fields) applies per request: a request whose input tokens exceed `aboveInputTokens` is priced at those rates as a whole. The reader only validates prices; it never computes a cost.
- `priceUnit`: `usd-per-1m-tokens`, present exactly when some model has a price (`invalid_client_price_unit`).
- `models[].small`: a boolean.
- `models[].evaluation: "pending"`: a listed model that is not yet evaluated. It has `efforts: []`, `recommended: null`, `recommendationBasis: null` (present), `defaultSelected` never `true`, and it never appears in a lineup's `baseline`, `frontier` or `members` (`invalid_client_pending_model`). Consumers must tolerate a model with no efforts and no recommendation.
- `speedTiers[].apiPriceMultiplier`: a finite number above 1, the tier's public API price as a multiple of Standard.
- `usageTrend`: `{source: "openrouter-paid-daily", asOf, days (1–90), ranks}`, where `ranks` maps a published model ID to one daily rank per day (an integer of 1 or more, or null when unranked). Every key is a published model, every array has `days` entries, and the serialized object is at most 8192 bytes (`invalid_client_usage_trend`).

A failed custom rule reports its code as the `message` of the matching `validationIssues` entry.

This reader is the producer's validator and rejects every violation above. The app-facing Go CLI digest (`cli/internal/digest/clientv16.go`) applies the same rules but, as it already does for `aaScore`, `planMetering` and `planModels`, drops a malformed optional field instead of the publication: a bad `models[].small`, `models[].price` or `price.longContext` for that model, a bad `speedTiers[].apiPriceMultiplier` for that tier, and a bad `usageTrend` as a whole, each with a diagnostic. It still rejects v1.6 fields below client-v1.6, any pending-row violation, and a `priceUnit` that is not `usd-per-1m-tokens` or does not match whether a model still has a price after the drops.
