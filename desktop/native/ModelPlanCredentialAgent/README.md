# U7 fixed credential helper — R2 default-deny

The fixed helper artifact consumes the existing generated `WireCredentialRequest` and
returns `WireCredentialResult(outcome: denied)` for every valid request. It has no
Keychain, token, quota, HTTP, decoder-for-provider-data, or runtime backend switch.
ADR0001, ADR0003 and the wire contract remain unchanged. The legacy injectable
`NativeCredentialAgent` exists for interface/fake regressions; its system matcher
has no OS lookup and it is not the production helper transport.

Real credential access is gated on **R2**: Developer ID and authenticated XPC with
Apple-anchored team + identifier requirements on both peers. A helper hash checks
artifact integrity, not caller authority. No signed caller-manifest workaround is
implemented. Until R2, denial is the intentional contract result; product copy is
owned by the engine/UI lanes. This stage is not completion of U7 credential reads,
A14, real Keychain ACL tests, or owner-profile acceptance.

## Build once, embed unchanged

On a macOS build runner:

```sh
python3 desktop/native/ModelPlanCredentialAgent/tools/build_fixed_helper.py --universal --output "$ARTIFACT_DIR"
U7_TEST_HELPER_BINARY="$ARTIFACT_DIR/modelplan-credential-agent" swift test --package-path desktop/native/ModelPlanCredentialAgent
U7_TEST_HELPER_BINARY="$ARTIFACT_DIR/modelplan-credential-agent" python3 -m unittest discover -s desktop/native/ModelPlanCredentialAgent/tools/tests -v
```

The builder uses two different clean roots, fixed optimization/target/path-map
flags, no debug records, the linker’s content-derived Mach-O UUID, deterministic
hashing and timestamp-free
ad-hoc build sealing. Hardened runtime and library validation stay enabled; there
are no entitlement exceptions. No certificate, Keychain or trust setting is used.
`proof.json` binds the Swift compiler, SDK, architecture, builder and helper/Wire
source hashes. The final executable bytes must match. Reproducibility is scoped
to those exact inputs; different SDKs/architecture sets are different artifacts.
Universal mode builds both slices, compares both final universal files and runs only
the host-native slice. Foreign-slice execution is explicitly not-run; Rosetta is
never invoked or installed.

Only the helper's own source, generated Wire dependency, toolchain or build recipe
changes require a new helper artifact and pin. App-only changes reuse the existing
reviewed artifact; the app build must not compile or re-sign the embedded helper.
A helper upgrade changes its code identity and may require renewed access once the
real backend is enabled. Avoiding prompts across real app upgrades still needs R2
and A14; this byte proof does not establish an ACL result.

```sh
python3 desktop/native/ModelPlanCredentialAgent/tools/embed_fixed_helper.py --artifact "$ARTIFACT_DIR" First.app
python3 desktop/native/ModelPlanCredentialAgent/tools/embed_fixed_helper.py --artifact "$ARTIFACT_DIR" Second.app
python3 desktop/native/ModelPlanCredentialAgent/tools/check_embedded_agent.py --pin "$ARTIFACT_DIR/credential-agent.json" First.app Second.app
```

Run the pair checker **after** all outer-app packaging/signing, against the trusted
artifact pin rather than a pin taken from either app. Do not recursively re-sign
the helper. The proof builder also compiles two distinct synthetic app hosts and
runs this exact embedding/check chain; it never launches them. Those are packaging
fixtures, not official candidate builds.

## Operation boundary

`FixedHelperCredentialAgent` verifies the pin, launches one bounded helper child,
sends only the generated request on a private pipe, discards stderr and accepts
only a matching denial with no token/expiry. Cancellation and deadlines terminate
only its owned child; the worker slot stays occupied until it exits. Output is
bounded. Current-context vetoes run before launch and after completion; EngineClient
also owns final full operation/session admission. `CredentialAgentAuthority` is a
weak, bind-once bridge to the production `ProcessEngineClient.isCurrent` API and
starts closed. `CredentialAgentClientFactory.make` constructs and binds that same
ProcessEngineClient; missing packaging uses a denial-only agent. No always-true
production fence or in-process reader fallback is
provided. The normal U6 EngineStoreConnection now uses this factory by default and preserves
an explicitly injected agent. Its dependency additions and constructor injection
are the only leased U6 edits. The independent IntegrationTests package drives that
real constructor through a synthetic RPC peer, checking credential capability, R2
denial and the current-context fence. A separate pinned helper fixture must leave
a synthetic launch marker; an in-process denial cannot satisfy that assertion.

Production helper embedding still awaits the packaging owner's separate PR; this
draft does not claim that fallback proves a packaged helper.
The proposed hook is in tools/package-neutral.patch: it consumes an existing
universal artifact plus an independently approved SHA, embeds before outer sealing,
then checks final bytes. It never compiles or re-signs the helper.
