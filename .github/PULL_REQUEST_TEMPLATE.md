## What and why

<!-- What changes, and which decision it helps (model, effort, plan). -->

<!-- Reader, detection, metric or consent changes (cli/internal/{quota,detect,localusage,speed,consent}/, reader-cause copy):
     name what you followed; the merge gate notes a missing line (docs/readers/integration-standard.md section 3).
     Form: Reference: <app>@<commit-or-tag> <path>  or  Reference: none (<reason>)
-->

## Checks

- [ ] CI is green (`cli`, `codex`, `skill`)
- [ ] No local ranking: numbers and verdicts come from the publication
- [ ] Read-only, anonymous, nothing uploaded; never switches model or effort
- [ ] English and Chinese text updated together
