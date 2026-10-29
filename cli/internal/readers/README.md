# Reader admission interface

This is the U2a **interface only** stage. The U2 scope identifiers come from
[4814e20](https://github.com/modelplan/modelplan/commit/4814e20d36f50dfd0a88cdb87a5f448ef39c22ed).
Production dispatchers do not yet use this package. Consent, revocation,
persistence and the shared cross-process vendor budget remain the caller's
responsibility. No legacy path is removed by this stage.

`CheckAdmission` rejects the Gemini Code Assist and Cursor account-usage scopes
with `policy_pending`, independently of a user's saved-login grant. Their local
history scopes remain eligible under their own consent. Unknown scopes fail
closed. POST approval requires a reviewed code change with the pinned request
set and body schema; no runtime flag can approve it.

`NewReadTransport` is created once per admitted, budget-reserved read. The only
remote scope it currently allows is MiniMax: a GET to the current quota path,
then optionally a GET to the legacy path on the same compiled regional host.
It permits at most two requests, no request parameters or bodies, no redirects,
and no subsequent request after HTTP 401/403. Its authorization stop lasts for
the transport's lifetime; persistent scope state and re-admission belong to U2.
Do not create another transport to retry an authorization failure.

`readertest.Transport` records method, host and escaped path for every attempted
outbound request, including calls beyond its scripted responses. It opens no
socket and keeps no credentials, headers or request bodies. Tests place it
**inside** the admission transport so records represent calls past the gate.
The MiniMax consumer test supplies that boundary to the existing real dispatcher
and quota decoder; this harness injection is not production wiring.

Run from `cli/`:

```sh
go test ./internal/readers/... -count=1
go test -race ./internal/readers/... -count=1
```

| Scenario | L1 pass condition |
| --- | --- |
| U2a-POST | Both Gemini endpoints and Cursor plan/period endpoints make zero recorded calls; changing the method to GET cannot bypass admission. Unguarded negative controls make calls and fail the zero-call oracle. |
| U2a-AUTH | MiniMax 401 and 403, in both regions, leave exactly the current-path GET in the recording, including through the existing dispatcher. An unguarded legacy retry fails that oracle. A valid quota response still decodes. |
| U2a-LOCAL | Both local-history scope IDs remain admitted while their remote scope is blocked; the existing Gemini history reader retains seeded token counts. A vendor-wide deny loses those records. |
| U2a-DESTINATIONS | Inference paths, changed parameters, cross-region fallback, redirects and excess requests never reach the recording transport. Concurrent callers cannot bypass an authorization stop. |

## U14 scenario intent

The completion scenario must use the real app-server and an independent CLI on
one synthetic shared home with fake providers and an approved shape baseline:

1. Grant the Gemini/Cursor account scopes and independent local-history scopes.
   Request refreshes from both entry points, including a retained legacy grant.
   Require `policy_pending` and zero provider calls for the unapproved scopes.
2. Return MiniMax 401 and 403 in separate cases, with a valid legacy-endpoint
   response available. Require exactly one current-path GET and no quota value.
3. Retain local token history and query it through the real handler after the
   remote scopes are blocked. Gemini has a count adapter on this base. Cursor
   has a scope identifier but no count adapter: this interface proves only its
   admission. A missing Cursor history capability must be recorded as unsupported,
   never a passing history query.
4. Bind outcomes to source SHAs, the synthetic profile, scenario IDs and the
   packaged subject when applicable. U10 cites this U14 evidence.

This L2 scenario is not run by these interface tests and remains required for
completion. Real accounts, native UI and L3 are outside this L1 evidence.
