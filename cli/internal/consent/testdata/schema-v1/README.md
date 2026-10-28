This is the unchanged public consent implementation from ModelPlan commit
`f74de08c` (the base of PR #250), under the repository's MIT license. The three
Go files are copied byte-for-byte from `cli/internal/consent/` at that commit.

Only compatibility tests import this package. It deliberately has no knowledge
of the App consent API's Keychain fields or receipts. Keep it frozen: exercising
its real readers, schema-v1 decoder, lock and atomic writer detects restrictions
or metadata that older installed CLI copies would ignore or erase.
