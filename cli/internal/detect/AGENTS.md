# Reference first

Behaviour here (reader, detection, metric and consent code) follows CodexBar, Pulse, TokenMonitor, ccusage, Tokei.
Where to read them: CodexBar (https://github.com/steipete/CodexBar), Pulse (https://github.com/qunqin24/Pulse), TokenMonitor (https://github.com/Javis603/token-monitor), ccusage (https://github.com/ccusage/ccusage), Tokei (https://github.com/cclank/tokei).
Before changing that behaviour, read how the reference does it at a pinned commit or tag, copy the behaviour (own code unless the licence and docs/readers/integration-standard.md section 3 allow a port), and put `Reference: <app>@<commit-or-tag> <path>` in the PR body, or `Reference: none (<reason of 20+ characters>)` when you deviate on purpose.
The merge gate checks this. Check locally before you push: `node scripts/merge-gates/check-reference.mjs --diff origin/main --body <file with the PR body>`.
Generated from scripts/merge-gates/reference-map.json (`node scripts/merge-gates/reference-docs.mjs --write`); do not edit by hand.
