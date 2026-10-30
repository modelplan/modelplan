# U7 quota-only fixed helper — contract input hold

The helper must never return tokens. Its fixed tool/query-kind enum selects compiled
hosts/endpoints/request shapes, and its fixed decoder emits only normalized quota
fields. Callers supply no URL, host, path, header or raw payload; raw response bodies
and headers are never echoed. No signed-manifest caller anchor is being built now.
Authenticated XPC with Apple team + identifier requirements is deferred to Developer ID.

Harden the executable: hardened runtime and library validation, no get-task-allow,
DYLD/JIT exceptions, and reject a debugged peer where detectable. Keep the accepted
EngineClient.isCurrent veto at each operation boundary. Token-returning paths remain
permanently default-deny. No Keychain/identity/trust or GUI action is authorized here.

## Blocking canonical contract changes

ADR0003 and foundation Credentials still require an access token on credentials/result
success. EngineClient.CredentialAgent returns generated WireCredentialResult, whose
validator rejects ok without accessToken; it has no quota payload. The Go broker
consumes that token and performs the quota read. ADR0001 keeps one Go data/reader engine,
and app-server invariant7 requires the shared per-vendor remote budget.

Do not work around this by stuffing quota into accessToken, editing generated Swift,
copying a second Swift HTTP reader/decoder, or bypassing Go's budget. The canonical
owners must publish the amended ADR/protocol, closed enum, bounded quota result/decoder,
operation cancellation/budget dispatch APIs and regenerated Swift consumer contract.
Reusing the Go fixed-reader core inside the helper is a design candidate, not an
implemented or accepted source move. Quota protocol/HTTP/wiring work is stopped until
these inputs are fixed. The real legacy OS token backend is permanently denied.

## Reproducible artifact / packaging work retained

Build the helper independently from App sources with one frozen source/dependency,
compiler/SDK/architecture and flags closure; remove timestamp/debug/path/UUID variability
and prove identical final bytes across two clean build roots in hosted macOS CI.
Cache that artifact across App-only builds. Rebuild and re-pin only as a reviewed helper
upgrade, including endpoint changes; that upgrade prompts once. App packaging copies
without silently rebuilding/re-signing it, and verifies the pin after final packaging.

Use Contents/Helpers/modelplan-credential-agent and
Contents/Resources/credential-agent.json. The descriptor contains schemaVersion=1,
sha256, bytes, inputSHA256 and bundleIdentifier=ai.modelplan.credential-agent. The trusted
artifact pin is an independent build input, not self-approved by either App.
Run tools/check_embedded_agent.py against two final Apps and the trusted pin. Its eight
hand-made-fixture tests qualify packaging logic only. Real helper implementation,
clean-root reproducibility, real two-App embedding and OS permission checks are not-run.
A14 remains deferred until Developer ID. No wired completion is claimed under this hold.
