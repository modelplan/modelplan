<!-- SPDX-License-Identifier: MIT -->
# U3c query interfaces

The ordinary `modelplan app-server` constructor registers history, cockpit and
publication against the shared backend. It owns no separate consent store and
queries never refresh providers. `CockpitHandler` admits every current scope,
returns Go-computed `wire.CockpitData`, and retains the original stamp/scopes for
the shared publication/write fence. Scope changes or a new epoch discard data.
The [cockpit contract](../../../../docs/cockpit-query.md) describes its typed
projection and verified subscription groups. Cursor token history uses the
[optional existing local numeric export](../../../../docs/cursor-local-history.md),
independently of its still-disabled account POST scope.

`HistoryHandler(HistoryConfig)` returns a private, query-limited handler using
the existing `wire.HistoryQueryParams`, `HistoryItem` and `HistoryPage` DTOs.
The constructor rejects missing dependencies. Supply the shared U3 backend,
a `HistorySource`, and the initialized request-session accessor from U3.

`HistorySource.AdmitHistory` must admit the exact requested data under the shared
consent fence, returning its stamp, covered scope set and resolved account
locator. `ReadHistory` receives only that admission and the authenticated backend
position. It reads existing local engine data, respects the requested row limit,
honors cancellation and returns immutable wire items. It never authorizes a
scope from installation presence or an old tool-level grant.

The handler rejects a stale request/admission stamp before reading. After the
read it checks the shared epoch/generation again and discards changed results.
Its reply retains the original stamp and scopes for U3's atomic Publish/enqueue
and final write fence. These layers are separate: a local post-read check does
not replace the transport's final shared-store check.

Cursors use a memory-only AES-GCM key per handler set. Authenticated additional
data binds each cursor to the initialized session, canonical scope set, resolved
account locator, tool, history kind and shared epoch/generation. The encrypted
backend position is bounded and never sent as plain cursor content. A foreign,
old, forged or malformed cursor returns `cursor_stale` without reading history.
New handler instances reject earlier tokens even if a session ID is repeated.
There is no cursor file or credential persistence.

`PublicationHandler` reuses the existing `digest.Publication` public-only DTO
returned by `modelplan publication --json`, preserving published values and
nulls. `VerifiedPublication` calls the existing verified-cache loader only;
it does not sync, open/create a cache or perform remote calls. The public
handler attaches no personal scopes and does not consume a private-query slot.
Its unknown-source errors are reduced to fixed protocol errors.

Run from `cli/`:

```sh
go vet ./internal/appserver/queries
go test ./internal/appserver/queries -count=1
go test -race ./internal/appserver/queries -count=1
```

| Scenario | Interface proof |
| --- | --- |
| U3c-HISTORY-WIRE | The real handler reply encodes as a wire Success, passes the generated app-server schema and decodes through the concrete HistoryPage DTO. Null model values remain null. |
| U3c-HISTORY-FENCE | A revoke or a new store epoch during reading returns `consent_changed` with no data. Denied/stale admissions never read history. |
| U3c-CURSOR | Changes to session, scopes, account, tool, kind, epoch or generation reject a prior cursor before reading history; tampering, key rotation and size bounds are checked. |
| U3c-CANCEL | Invalid parameters and canceled requests never read history, including cancellation that occurs during admission. |
| U3c-PUBLICATION | Existing typed public fields and nulls are preserved; personal fields are excluded; untrusted parameters and raw source errors are refused; an absent cache is not created. |

Handler unit tests use synthetic sources. The command package also tests the
ordinary executable's registered methods and typed Cursor producer, including
continuation, explicit-null/wrong-type rejection and row isolation. A source-delay
only overlay exercises real-process late results after external CLI revoke and
epoch reset with the same production backend and constructor. U14 must seed the
supported Cursor export and refresh it before upgrading its unsupported result.
Native bridge/UI, live exporter accuracy and final-package evidence are not-run.
