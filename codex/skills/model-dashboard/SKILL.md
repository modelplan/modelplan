---
name: model-dashboard
description: Compare Codex GPT engines and native effort recommendations in the Model Plan console, or read public Codex reset notices.
---

Call `open_model_dashboard` for the sidebar. For a terminal or data answer call `get_model_dashboard`: `view: "lineup"` compares OpenAI models at their ★ recommendations; `view: "effort", modelId: "<exact result ID>"` compares one model's native efforts relative to ★. Choose `lang: "zh"` or `"en"`. Completion: show the published values, verdicts and publication identity, or the explicit unavailable/last-good state.

In Codex CLI the HTML is unavailable. Present the tool's text blocks in their returned order. If MCP is unavailable and the `modelplan` Go binary is installed, run `modelplan lineup --dev openai --no-color`; for a specific model use `modelplan effort <exact ID> --no-color`. Keep the published lineup verdict and baseline; lineups are the published client digest's verdicts, also used by the website kit and Go CLI.

The lever is a comparison setting. Applying a model/effort uses the host picker and an explicit user action. Unknown values stay unknown, and estimated time keeps its label. Ability is additive points; cost/time changes are relative to the same model's ★ recommendation. Cost is USD per declared reference task; label any absolute value as approximate reference-task dollars. Time ratios require matching published time bases.

Public reset notices do not establish personal eligibility, balance or a personal reset time. Preserve source status, scope and stated time precision; posting or confirmation time is not effective time. Model and reset evidence come from one verified publication. See the installed package README for local preview/setup diagnostics.
