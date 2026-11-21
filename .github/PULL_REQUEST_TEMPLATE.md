## What and why

<!-- What changes, and which decision it helps (model, effort, plan). -->

<!-- Reader, detection, metric, widget/Dock, menu-bar or native-shell changes (areas: scripts/merge-gates/reference-map.json):
     name the reference you followed; the merge gate notes a missing line, and reviewers check the change matches it
     (docs/readers/integration-standard.md section 3). A deviation needs a reason here.
     Form: Reference: <app>@<commit-or-tag> <path>  or  Reference: none (<reason, 20+ characters>)
-->

## Checks

- [ ] CI is green (`cli`, `codex`, `skill`)
- [ ] No local ranking: numbers and verdicts come from the publication
- [ ] Read-only, anonymous, nothing uploaded; never switches model or effort
- [ ] English and Chinese text updated together
