<!-- SPDX-License-Identifier: MIT -->
# Foundation preference store

`SettingsStore(foundationAt:product:rowIDMap:)` is the canonical actor for the schema-v1 `ModelPlan/settings.json` document, with `settings` and `core` sections. The caller passes its application-support root and explicit official/community identity. The existing URL initializer continues to handle legacy v1 preference files for compatibility; it does not silently activate migration.

```swift
let store = try SettingsStore(foundationAt: support, product: .community)
let preferences = await store.snapshot()
let core = await store.coreSnapshot()
let status = await store.foundationStatus() // path, source issues and read-only recovery
```

Opening an existing valid target does not read legacy files or rewrite the target. An invalid/unreadable/unsupported target produces an in-memory default-right recovery with an issue and rejects settings/core writes; it is never replaced from legacy sources. A symbolic-link target is not followed.

Only an absent target invokes `FoundationSettingsMigration`. Official/community source preference and independent Core recovery use its unchanged field-group contract. Reads are bounded regular-file reads relative to an opened directory, with symlink directories/files rejected. The old files are never mutated. Unmatched row IDs remain, and only caller-supplied explicit row mappings are applied. No readerConsent is migrated, restored or written as an engine grant; attempted app-consent edits are rejected.

First publication uses an exclusive local writer lock, a private 0600 staging file, a completed write/fsync, and `linkat` to publish without replacement. A competing target wins and is re-read; there is no replacing-rename fallback. Only the transaction's own staging file is cleaned up. Competing bootstrap locks fail busy instead of waiting on the UI thread.

Settings edits and `updateCore(_:expectedRevision:)` both use the same actor and document writer. Each update locks, compares the last loaded bytes and directory identity, then atomically replaces a complete staged document. Cooperating writers serialize on the lock; stale actors and target changes found during the locked comparison are rejected. Core edits preserve settings, and settings edits preserve Core. Validation/read/pre-commit failures keep the last committed in-memory value. A post-publication directory-sync error reports durability uncertainty and blocks further writes until the store is reopened; the published document is never rolled back or deleted.

## Entry integration boundary

The normal-entry owner must switch Settings and Core consumers together: pass this actor to the existing Settings editor and route Core reads/writes through `coreSnapshot`/`updateCore`. Stop using the old Core PreferenceFile writer at that transition. Do not run two stores for one target or open the new document with the legacy URL initializer. Propagate source/recovery issues and expose `foundationStatus().path` as the path in use.

This backend is exercised through the existing SettingsEditor, but the normal CommunityApp entry selection and its Core port remain a separate integration edge. The source change does not activate a half-migrated entry or remove the existing path. Packaged synthetic-profile migration/restart and actual native input remain L2 obligations.

Window-free checks: `swift test --package-path desktop/native/ModelPlanSettings --filter 'FoundationPreferenceStoreTests|FoundationSettingsMigrationTests|PreferencesTests|LoginTests|SettingsEditorTests|SettingsCommitDeliveryTests|FirstRun65Tests'`.
