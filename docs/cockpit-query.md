<!-- SPDX-License-Identifier: MIT -->
# Cockpit display query

The ordinary `modelplan app-server` constructor registers `cockpit/query` as a
private query using the same two-query budget and consent publication/write
fences as `history/query`. It does not refresh providers or mutate row state.

Parameters are an empty object. The typed `CockpitData` result contains:

- `projection`: the existing Go-computed `RowsProjection`, including rows,
  account display DTOs and summary.
- `subscriptions`: Go-computed groups of existing verified subscription refs.
  Each has `subscriptionRef` and `accounts`; each member has the stable row `tool`
  ID and its existing `Account` display DTO. Equal known refs alone form a group.
  Unbound/unknown accounts stay on their rows; no shared plan is inferred.

The page renders these display values and does no account-to-subscription
interpretation. This endpoint does not export the broad personal snapshot,
source paths, account identities, credentials, arbitrary files/URLs, commands,
settings changes or plugin operations. It neither reads app presentation
preferences nor writes a filtered row projection back to the engine.

Admission obtains the current permitted scope set from the shared backend.
Display reading and the post-read check must agree on the same scope set and
`(storeEpoch, generation)`. The reply retains its original scope set and stamp
for the server's final publication/write fence. A moved epoch or generation
returns `consent_changed` with no data. An unavailable/empty admission is rejected;
the ordinary rows method continues to report setup and consent summary states.
Context appears once in the response envelope, not repeated inside display DTOs.

The generated app-server schema includes the typed result and empty request.
Ordinary-binary acceptance covers registration, typed/schema decoding, retained
Cursor local history, invalid input, and unchanged row projection after queries.
A separate real-executable build adds only a deterministic delay after the
production source read to reproduce revoke and reset races for both history and
cockpit. It uses the ordinary constructor, shared store, source values and wire
transport; no alternate backend or production test flag is introduced. Native
WKWebView/bridge and final-package evidence remain separate.
