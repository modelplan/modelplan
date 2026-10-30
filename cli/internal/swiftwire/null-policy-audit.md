<!-- SPDX-License-Identifier: MIT -->
# Optional wire null audit

This inventory covers the 55 optional/nullable fields reachable from the production
wire roots, including shared rows. It audits the consumer, not just Go's pointer
representation. `null` tags describe the field's state model; required-key and
outcome/authorization constraints apply separately. In particular, a required
nullable response field does not become optional, and a credential field is legal
only for the permitted outcome.

The Go encoder inventory, generator rule and compiled Swift catalog test cover
every row below. Input declarations are also tied to production decoding/handler
tests in [optional_null_test.go](../appserver/optional_null_test.go). Output rows
are consumed by the generated DTO's actual `init(from:)`, then by the engine
client's [delivery path](../../../clients/swift/ModelPlanEngineClient/Sources/ModelPlanEngineClient/Delivery.swift)
and the store's typed `apply` path. They are not accepted as Go request parameters.
The compiled catalog mutates the capture for each output field through that
production decoder and checks normalization/preservation, including any required
key or authorization rejection.

## Inputs and RPC framing (10 fields)

| Field | Declaration | Actual consumer and observed rule | Regression evidence |
| --- | --- | --- | --- |
| Request.ID | forbidden | [frame.go:108](../appserver/frame.go#L108), `decodeRequest`/`validID`: absent notification ID is legal; explicit null is rejected. | `TestRequestNullPoliciesAtProductionDecoderAndDispatch`; compiled Swift catalog forbidden-null case. |
| Request.Params | distinct | [frame.go:98](../appserver/frame.go#L98) preserves raw absence/null. [frame.go:133](../appserver/frame.go#L133), `params[T]`, treats absent as `{}` but rejects null; a raw value must survive until method validation. | Same Go test dispatches both forms to `diagnostics/get`; `testOptionalRawRequestParamsRetainExplicitNull`. |
| ConsentGrantParams.Forget | coalesced | [server.go:395](../appserver/server.go#L395), `validGrant`, and [shared_backend.go:248](../appserver/shared_backend.go#L248), `Grant`, receive the same empty list for absence/null; neither inspects raw presence. | `TestConsentOptionalNullsThroughGrantHandler`; compiled catalog. |
| ConsentGrantParams.Keychain | coalesced | Same grant path receives the same nil map for absence/null. Entries, when present, must be allow/deny; map absence/null authorizes no Keychain action. | Same Go test; compiled catalog and credential presence tests. |
| CredentialResult.AccessToken | forbidden | [credentials.go:27](../appserver/credentials.go#L27), `validCredential`, requires a nonempty token for `ok`. `credentialParams` rejects token-key presence for other outcomes, including null. Omission is legal only for non-success. | `TestCredentialSuccessOptionalNullsThroughHandler`, `TestCredentialNonSuccessNullPresenceMatchesSwiftAndSchema`; `testCredentialOptionalNullsRespectOutcomePresence`. |
| CredentialResult.ExpiresAt | coalesced | `credentialParams`/`validCredential`: for `ok`, absent/null both mean no expiry; a supplied expiry must be future. For non-success, any expiry-key presence is forbidden by the independent outcome rule. | Same paired Go/Swift outcome tests cover all six non-success outcomes, both keys, and success omission/null controls. |
| RefreshRequestParams.Scopes | coalesced | [refresh.go:92](../appserver/refresh.go#L92), `Request`, defaults a zero-length list to admitted view scopes. Absent/null both take that path. | `TestRefreshOptionalNullThroughHandler` exercises `Handler().Handle`, admitted defaults and offline deferral; compiled catalog. |
| PluginInstallParams.Offline | coalesced | [plugin.go:17](../appserver/plugin.go#L17), `PluginInstallHandler`, uses the decoded false value for absent/null. Neither overrides the server's own offline/read-only policy. | `TestPluginOptionalNullThroughHandler` compares fixed offline installation plans; compiled catalog. |
| HistoryQueryParams.Ref | forbidden | [queries/history.go:62](../appserver/queries/history.go#L62), `historyParams`, rejects raw null before admission/read; omission and empty string are accepted. | Declaration assertions in both `TestHistoryRejectsNullOptionalSelectors` and `TestHistoryAllowsOmittedOptionalSelectors`; ordinary executable `TestU3cHistorySelectorsRealBinary`; `testHistorySelectorsMatchHandlerOmissionAndNullRules`. |
| HistoryQueryParams.Cursor | forbidden | Same handler: raw null is invalid params before admission/read; omitted/empty means the first page. A nonempty cursor must authenticate against the query/session/fence. | Same Go handler, ordinary executable and Swift omission/null regressions. |

The history audit corrected two false coalesced declarations and generated Swift
rejection guards. It also found a pre-existing credential discrepancy: Go's typed
decoder discarded explicit null keys on non-success results, while the schema and
Swift rejected their presence. `credentialParams` now enforces the existing
schema/Swift rule before the operation can be consumed; rejected input leaves the
operation available for a valid result. AccessToken is therefore forbidden-null.
No credential content is logged or included in assertion messages.

## Outputs (45 fields)

Evidence references name the producer and the production decoder consuming each
field. `coalesced` means no third state is exposed: absence/null both produce the
same unavailable/empty optional state when key presence is permitted. The Go
encoder probe independently checks normalization. Publication's required nullable
containers and failure ID retain their required-key checks.

| Field | Declaration | Producer and consumer behavior |
| --- | --- | --- |
| Envelope.Scopes | coalesced | [server.go:228](../appserver/server.go#L228), `envelope`, emits optional scopes. Generated `WireEnvelope.init(from:)` maps absent/null to nil; empty scopes grant no private permission. |
| ErrorContext.StoreEpoch | coalesced | [server.go:213](../appserver/server.go#L213), `errorMessage`; generated `WireErrorContext` returns nil for absent/null. Delivery observes a floor only with both epoch and generation. |
| ErrorContext.ConsentGeneration | coalesced | Same error and delivery path: absent/null cannot advance the floor. |
| Failure.ID | coalesced | `errorMessage` emits an ID or required null ID; generated `WireFailure` treats null as no correlated request. Required-key validation is separate from its nil state. |
| ConsentScope.Keychain | coalesced | [shared_backend.go:162](../appserver/shared_backend.go#L162), `buildView`, builds facts. Generated `WireConsentScope` returns nil for absent/null; the credential intent path requires an explicit allow choice. |
| ConsentScope.Disabled | coalesced | Same facts producer; generated `disabledReason` absent/null both yield no disabled reason. Unknown display reasons retain the existing tolerant behavior. |
| ConsentReceipt.CommittedGeneration | coalesced | [shared_backend.go:248](../appserver/shared_backend.go#L248), `Grant`, emits the committed generation or null. `WireConsentReceipt`/Delivery require a generation for committed receipts; absent/null both fail that contextual check, and neither creates a fabricated generation. |
| ConsentReceipt.CleanupPending | coalesced | Same grant producer; `WireConsentReceipt` returns nil for absent/null, with no pending cleanup entries. |
| Diagnostics.LastErrorClass | coalesced | [server.go:368](../appserver/server.go#L368), diagnostics reply; `WireDiagnostics` absent/null both mean no last-error class. |
| ScopeDiag.LastRead | coalesced | [shared_backend.go:191](../appserver/shared_backend.go#L191), diagnostics projection; `WireScopeDiag` absent/null both yield no timestamp. |
| ScopeDiag.NextDueAt | coalesced | Same projection/decoder: absent/null both yield no scheduled timestamp. |
| RefreshScheduled.DisabledReason | coalesced | [refresh.go:114](../appserver/refresh.go#L114), `Request`, attaches a reason only for deferral. `WireRefreshScheduled` absent/null both yield no reason. |
| HistoryItem.Model | coalesced | [queries/history.go:155](../appserver/queries/history.go#L155), page construction; generated `WireHistoryItem` absent/null mean unknown model, never a manufactured model label. |
| HistoryItem.Tokens | coalesced | Same page/decoder: absent/null are unavailable, not numeric zero. |
| HistoryItem.Window | coalesced | Same page/decoder: absent/null both mean no window label. |
| HistoryItem.Value | coalesced | Same page/decoder: absent/null are unavailable, not numeric zero. |
| HistoryPage.NextCursor | coalesced | [queries/history.go:156](../appserver/queries/history.go#L156), only encodes a cursor for a next position. `WireHistoryPage` absent/null both mean no next cursor. |
| PublicationResult.PublishedAt | coalesced | [queries/publication.go:85](../appserver/queries/publication.go#L85), public projection conversion; `WirePublicationResult` requires the key, accepts null as no date. It does not expose an absent state. |
| PublicationResult.SelectionRevision | distinct | Same conversion preserves raw published JSON. `WirePublicationResult` uses key presence to distinguish nil, `.null`, and value; the store retains the typed result. `TestSelectionRevisionPresenceRegression`/the wire encoder probes and `testSelectionRevisionPreservesAbsenceNullAndString` guard preservation. |
| PublicationResult.Multipliers | coalesced | Same conversion; `WirePublicationResult` requires this nullable container. Null is unavailable; absent fails its independent required-key guard. |
| PublicationResult.MultiplierHorizon | coalesced | Same projection and required-nullable decoder rule; no extra absent state is exposed. |
| PublicationResult.PlanMetering | coalesced | Same projection and required-nullable decoder rule; no extra absent state is exposed. |
| PublicationCapability.Reason | coalesced | Same publication capability projection; generated `WirePublicationCapability` absent/null both mean no reason text. |
| rows.Name.UserAuthored | coalesced | [catalogue.go:85](../rows/catalogue.go#L85), declared-name projection; `RowsName` absent/null both have no authorship marker. |
| rows.NextStep.AvailableAt | coalesced | [build.go:367](../rows/build.go#L367), `nextStep`; `RowsNextStep` absent/null both have no availability timestamp. |
| rows.NextStep.DisabledReason | coalesced | Same projection/decoder: absent/null both have no disabled reason. |
| rows.Row.VendorKey | coalesced | [build.go:168](../rows/build.go#L168), row construction and expiry latching at lines 288–304; `RowsRow` absent/null both have no vendor key. Row authorization validation remains mandatory. |
| rows.Row.NextStep | coalesced | Same projection/decoder: absent/null both have no action. |
| rows.Row.ExpiresAt | coalesced | Same projection/decoder: absent/null both have no expiry. |
| rows.Row.StateAfterExpiry | coalesced | Same projection/decoder: absent/null both have no expiry-state override. |
| rows.ExpiryState.NextStep | coalesced | [build.go:304](../rows/build.go#L304), expiry-latch projection; `RowsExpiryState` absent/null both have no post-expiry action. |
| rows.Account.SubscriptionRef | coalesced | [values.go:56](../rows/values.go#L56), `buildAccounts`; `RowsAccount` absent/null both have no subscription reference; present references still validate. |
| rows.Account.AccountLocator | coalesced | Same projection/decoder: absent/null both have no account locator; present locators still validate. |
| rows.Account.Credits | coalesced | Same projection/decoder: absent/null both have no credit reading. |
| rows.Account.ObservedAt | coalesced | Same projection/decoder: absent/null both have no observation timestamp. |
| rows.Account.FreshUntil | coalesced | Same projection/decoder: absent/null both have no freshness deadline. |
| rows.Account.LastFailure | coalesced | Same projection/decoder: absent/null both have no recorded failure. |
| rows.Plan.Name | coalesced | [catalogue.go:81](../rows/catalogue.go#L81), `planValue`; `RowsPlan` absent/null both have no plan name. |
| rows.Credits.Balance | coalesced | [values.go:77](../rows/values.go#L77), credit projection; `RowsCredits` absent/null both have unavailable balance, not zero. |
| rows.Window.DurationSeconds | coalesced | [values.go:160](../rows/values.go#L160), `buildWindows`; `RowsWindow` absent/null both have no duration. |
| rows.Window.RemainingPercent | coalesced | Same projection/decoder: absent/null both are unavailable, not zero percent. |
| rows.Window.ResetsAt | coalesced | Same projection/decoder: absent/null both have no reset timestamp. |
| rows.Window.ObservedAt | coalesced | Same projection/decoder: absent/null both have no observation timestamp. |
| rows.Window.ValidUntil | coalesced | Same projection/decoder: absent/null both have no validity deadline. |
| rows.RowsSummary.NextStep | coalesced | [build.go:435](../rows/build.go#L435), `summary`; `RowsRowsSummary` absent/null both have no summary action. |

The output DTO implementations are generated together in
[Generated.swift](../../../clients/swift/ModelPlanWire/Sources/ModelPlanWire/Generated.swift).
The compiled `testEveryDeclaredOptionalNullPolicyThroughProductionDecoder` uses
all capture roots to exercise the real initializers, not a substitute decoder.
The row semantic-recovery tests additionally verify that malformed/unauthorized
rows become safe placeholders and cannot retain accounts or private optional data.

No additional null/absence state mismatch was found in the remaining output
consumers. This inventory is a source-backed audit, not a claim that a type-only
encoder probe can prove handler semantics for future fields.
