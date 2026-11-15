# Reference first

Some files here follow a reference app, depending on the area:
- widget: widget and Dock interaction (Dock host, edge, drag, card and placement files). Follows Pulse. Read them at Pulse (https://github.com/qunqin24/Pulse).
- menu-bar and native shell: menu bar and native shell (status item and menus, cockpit window controller, help and hint panels, engine lifecycle wake/unlock/display handling). Follows CodexBar, Stats, Maccy, Pulse. Read them at CodexBar (https://github.com/steipete/CodexBar), Stats (https://github.com/exelban/Stats), Maccy (https://github.com/p0deje/Maccy), Pulse (https://github.com/qunqin24/Pulse).
Before changing that behaviour, read how the reference does it at a pinned commit or tag, copy the behaviour (own code unless the licence and docs/readers/integration-standard.md section 3 allow a port), and put `Reference: <app>@<commit-or-tag> <path>` in the PR body, or `Reference: none (<reason of 20+ characters>)` when you deviate on purpose.
The merge gate checks this. Check locally before you push: `node scripts/merge-gates/check-reference.mjs --diff origin/main --body <file with the PR body>`.
Generated from scripts/merge-gates/reference-map.json (`node scripts/merge-gates/reference-docs.mjs --write`); do not edit by hand.
