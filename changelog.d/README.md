# Changelog fragments

Each change adds its own file here instead of editing `CHANGELOG.md`, so parallel PRs do not conflict.

- Name the file after your branch or PR: `changelog.d/reader-lock-wait.md`.
- Write one entry: plain English, one paragraph, no heading and no leading `- `.
- Skip it for changes users cannot see.

`node scripts/changelog.mjs --check` validates the fragments. The pin PR for a CLI release runs `node scripts/changelog.mjs --collate vX.Y.Z`, which moves the `Unreleased` entries and every fragment under a new version heading and deletes the fragments.
