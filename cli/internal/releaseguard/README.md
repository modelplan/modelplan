# Reader and release regression guards

These checks catch recurring **accidental mistakes**. They are not adversarial
proofs. A reviewer block must name a **realistic accidental pattern**, provide a
minimal reproduction, and identify the guard command that incorrectly accepts it.

From `cli/`:

```sh
go test -count=1 ./internal/testenv ./internal/quota ./internal/connections ./cmd/modelplan -run 'Test(ReaderReason|NativeConnectionReasons|.*ErrorOutput|RuntimeErrorsStayOutOfCLIJSONAndLogs)'
go run ./internal/releaseguard/cmd --root ..
go run ./internal/releaseguard/cmd --binary '/path/to/release.app/Contents/MacOS/ModelPlanCommunity'
```

The reader tables validate actual persisted/returned reason fields and captured
logging against positive code vocabularies. On Linux/macOS, capture redirects
file descriptors 1 and 2 with `dup2`, including package-level loggers bound to
`os.Stderr` before the test starts. A concurrently drained pipe avoids blocking
ordinary bursts of logging. These tests change process-wide descriptors and
must not run in parallel. Other platforms do not claim descriptor coverage.

The source guard checks literal private KVC/selector patterns, including normal
grouping parentheses, nested setter values, and C-family/Swift branches.
`MODELPLAN_TEST_ONLY_SPI` must exclude test-only SPI from release. **Computed or
deliberately obfuscated selectors are out of scope for the source guard.**

The macOS distribution workflow's `neutral-build` job builds the universal Swift
app in release configuration, then scans its actual executable before archive
or upload. The binary backstop checks a small compiled-name denylist, initially
`_webProcessIdentifier`, across raw string/symbol/selector bytes. It covers those
denylisted names regardless of source spelling when they are present in the
built binary; it does not claim to enumerate all Apple SPI. The workflow also
runs when native/Swift source or this guard changes.

Tests include minimal bad inputs and public-key/test-only controls through both
`CheckApple` and the real command, plus a compiled binary whose source splits a
denylisted name into two literals.
