<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Cockpit WebKit regression images

Copyright (c) 2026 ModelPlan. Reserved visual material; see ../LICENSE.md.

D489 (2026-11-28) retired the four shared full-cockpit baselines
(`webkit-linux-arm64/full-{day,night}-{en,zh-CN}.png`). Every visual PR had to
regenerate them, so parallel visual PRs conflicted on the same four files.
CI now renders the PR's base and head on one runner and diffs the two renders;
see docs/cockpit-visual-diff.md.

This directory stays the Playwright snapshot path (playwright.config.mjs) for
images that are not shared across PRs, such as the pending zoom baselines in
desktop/tests/cockpit/cockpit-zoom-baselines.pending.json. Such images are
implementation regression references, not owner-confirmed prototype fidelity,
a WKWebView baseline or native acceptance; their hashes belong in the public
source-policy registry before publication.
