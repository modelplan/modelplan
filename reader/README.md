# Public publication reader

MIT validation, integrity and caching for published data. This retains the verifier already shipped publicly in the Codex plugin. It does not compute model scores, fit parameters or choose recommendations. Runtime clients display production-published verdicts.

The private producer may consume a reviewed, hash-verified copy of this reader. Production scoring/recommendation source, full calibration records, input construction, entry/exit automation, acquisition/review/publication and official visuals remain private. Formula explanations and source weights remain in the methodology documents. No scoring engine or complete calibration snapshot belongs in this module.

Run `npm ci --prefix reader && npm test --prefix reader` (Node 24+). Source rebuilds require a full checkout; the packaged plugin uses its bundled runtime.
