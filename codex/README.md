# Model Plan for Codex

A compact, read-only GPT effort dashboard for Codex desktop, with a text fallback for Codex CLI. [中文](README.zh-CN.md)

## Install

Requires Node.js 24+ on PATH and a Codex version with plugin support. Runtime dependencies and fonts are bundled; no npm install, API key or Model Plan account is required.

```sh
codex plugin marketplace add modelplan/modelplan
codex plugin add modelplan-codex@modelplan
```

Restart Codex or open a new task after installation. Ask **“Open the Model Plan dashboard”**, or invoke the `model-dashboard` skill. Desktop hosts supporting app panels show the dashboard; use **Expand** if the host offers it. CLI renders the same published comparison as text. Panel placement and expansion depend on the host; this plugin does not force a persistent sidebar.

To update, refresh the marketplace and reinstall the plugin:

```sh
codex plugin marketplace upgrade modelplan
codex plugin add modelplan-codex@modelplan
```

## What you see

- Published OpenAI recommendations, high-capability pick, best value and cheapest.
- One model's native effort lever and a compact capability/cost/time curve. Click a metric to isolate it; click again to restore all. Use arrow keys or Home/End on the lever.
- Gold ★ means recommended effort only. Capability changes are additive points; cost/time are multiples of that model's recommendation. Estimates are marked ≈; missing or incompatible time evidence leaves gaps.
- Public Codex reset notices with source, scope and stated time precision. They do not establish personal eligibility or remaining quota.

The dashboard reads the same verified client publication as [Model Plan](https://modelplan.ai/effort). It does not rank locally, call model inference, buy a plan or change the active model. Cached, unavailable and last-good states stay explicit. The roster is the published evaluated GPT set, not the host's complete picker.

## Transport and development

`mcp.json` configures an internal stdio transport for `open_model_dashboard` and `get_model_dashboard`. Node starts `server.bundle.mjs` from the installed package. The app resource includes its styles and fonts without third-party browser requests. Normal usage contacts Model Plan's public publication endpoint; the local cache contains public data only. No telemetry or credentials are collected.

```sh
cd codex
npm ci --ignore-scripts
npm test
npm run build
node tests/mcp-smoke.mjs --fresh
node tests/codex-host-smoke.mjs
```

The last command requires this version to be installed in Codex. It checks registration, tools and app-resource transport without creating a thread or running inference; it does not validate native panel placement. `npm start` provides an optional loopback preview for UI development. It is not a public server.

`lib/client-reader.mjs` vendors the canonical publication verifier. Both source and the bundled runtime are shipped. UI fonts retain their SIL OFL notices under `ui/fonts`; runtime dependency licenses are in `THIRD-PARTY-NOTICES.md`.

MIT. See [LICENSE](LICENSE).
