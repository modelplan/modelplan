# Desktop contract v1

The two Draft 2020-12 JSON Schemas freeze successful JSON output from:

- `modelplan desktop --json --read-only`: `desktop-v1.json`.
- `modelplan publication --json` (including `--offline`): `publication-v1.json`.

Both declare `contractVersion: 1`, retain `schemaVersion: 1`, and expose a `capabilities` object. Capabilities describe the wire surface, **not** an account's authorization, entitlement, freshness or available observations. Status is `supported`, `source-dependent`, `publication-dependent`, or `unavailable`; `reason` explains important abstentions. Per-source status/coverage and nullable values remain authoritative. Unknown values do not become zero or full quota.

`publication` forwards the verified public `models`, `lineups`, `speedTiers`, `resets`, `windows`, `multipliers`, `multiplierHorizon`, validated `planMetering`, and optional `selectionRevision`. Raw public arrays preserve order, nulls, bases, qualifiers and scoped conditions. Absent optional multipliers/metering remain null, distinct from a published empty array. Publication ID and publication time come from the verified envelope. The command does not export personal accounts or create new recommendations.

`lineageSelection` is `publication-dependent`. Optional model fields `lineageId`, `lineageStatus` (`current`, `older`, `preview`, `retired`) and `defaultSelected` pass through verbatim, along with the publication's optional `selectionRevision`. Missing or null flags mean unknown; `false` is a known exclusion from the published global defaults. Consumers do not derive representatives, retirement or plan visibility from model names, scores or the capability status. The CLI does not compute a selection, and contract version remains 1.

Quota windows retain reported `kind`, `limit`, nullable values and source instants. A reported model/feature label (for example Fable or MCP) is a label, not inferred model entitlement. Source strings and window kinds remain extensible. Current sources do not support a general credit-history/limit/reset feed, exact redemption/correction event provenance or full historical subscription ownership. Those capabilities remain unavailable; consumers show blank/`--` or explicitly source-wide data. Adding plausible synthetic fields does not authorize treating them as real observations.

Times use RFC3339 instants; completion-hour strings retain their original offset, including repeated DST hours. Calendar days retain their source-local `YYYY-MM-DD` identity. Remaining amounts, observations, eligible generation sums, source-wide history, current bindings and proved session-level ownership remain distinct. Today's generation average is eligible output divided by eligible generation seconds with at least five samples, never a mean of averages.

Existing fields and command flags remain compatible. An old feed without `contractVersion` remains decodable by Core. A declared unsupported contract version is rejected. Future additive fields are permitted by schemas and decoders; removing a required field, changing a field's type/meaning/unit, or otherwise breaking a v1 consumer requires a **new contract version and new schema**. Keep these v1 schemas and goldens to test compatibility with existing consumers.

The Go tests validate actual command output against these schemas, compare independent synthetic producer outputs with every golden, and reject version/type/date/missing-field mutations. Schema-format assertions run offline. `github.com/santhosh-tekuri/jsonschema/v6` (Apache-2.0) is a test-only dependency; it is not linked into the CLI binary. Existing binary dependency notices remain authoritative.

Run from the repository root:

```sh
cd cli
go vet ./...
go test ./...
```

`go test ./internal/desktopcontract -run TestContractV1Goldens -update-contract` is an explicit review tool for initial/new-version schema and golden generation, not a routine way to make failures pass. Review semantics and the version before updating a frozen contract.

On macOS, Core decodes the same documents using `swift run --package-path desktop/native ModelPlanContractV1Checks "$PWD/testdata/contract-v1"`.
