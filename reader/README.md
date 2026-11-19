# Public publication reader

MIT validation, integrity and caching for published data. This retains the verifier already shipped publicly in the Codex plugin. It does not compute model scores, fit parameters or choose recommendations. Runtime clients display production-published verdicts.

The private producer may consume a reviewed, hash-verified copy of this reader. Production scoring/recommendation source, full calibration records, input construction, entry/exit automation, acquisition/review/publication and official visuals remain private. Formula explanations and source weights remain in the methodology documents. No scoring engine or complete calibration snapshot belongs in this module.

Run `npm ci --prefix reader && npm test --prefix reader` (Node 24+). Source rebuilds require a full checkout; the packaged plugin uses its bundled runtime.

The verifier accepts optional published selection metadata: top-level `selectionRevision` and nullable per-model `lineageId`, `lineageStatus` (`current`, `older`, `preview`, `retired`) and `defaultSelected`. Historical and partial publications remain valid. These are producer verdicts; the reader validates their types and preserves them without computing a selection. Strict model validation, content hashes and dependency checks still apply.

An effort may carry `provisional: true` (absent otherwise; `false` is rejected): its ability rests on evidence outside the range its cross-source link was fitted on. It belongs to its own model's effort ladder only; the producer already leaves such configurations out of every cross-model lineup, so the reader preserves the flag without changing any lineup. Any other unknown effort field is still rejected.

From `projectionVersion: "client-v1.5"` an effort may carry `aaScore` (a finite number above 0, absent when unscored): the raw Artificial Analysis Intelligence Index score for that model and effort, the same value as the publication's model capability. Provisional efforts keep it. A top-level `aaIndexVersion` (non-empty string, for example `"4.3"`) names the index version and is present exactly when some effort carries `aaScore`. A digest below client-v1.5 that carries either field is rejected.
