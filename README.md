# #718 first-run chooser renders (evidence only, never merge)

Synthetic fixture (Claude Code signed out, Codex, Cursor with a browser session, ZCode with an account login,
Gemini not detected), rendered on a hosted macOS 15 runner by `G345FirstRunChooserJourneyTests` with a
temporary render helper.

- `before/`: run 42430492782, main f8f022b3 plus the failing-first test (branch c/g345-before, 7eab26c7). The test fails there.
- `after/`: run 42431118664, branch c/g345-after 03b49000 (PR #718 head plus the same helper). All 38 first-run/consent journeys and 65 Settings tests passed.
