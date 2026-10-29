<!-- SPDX-License-Identifier: MIT -->
# App-server interface

`wire` is the source of truth for JSON names, optional fields, nullability,
enums and flow-control limits. It implements the frozen [protocol](https://github.com/modelplan/modelplan/blob/3306b85d474b3c696aafa078626ff8f147b72c39/schema/app-cli/app-server.md).
`wireschema` generates `schema/app-cli/app-server.json` from those production
DTOs and the typed enum constants in `wire` and `rows`:

```sh
cd cli
go run ./internal/appserver/wire/cmd/schema
go run ./internal/appserver/wire/cmd/schema --check
go test ./internal/appserver/...
```

The schema has named definitions for requests, responses, notifications and each
method's data. Required pointer fields encode explicit null; `omitempty` fields
may be absent. `HistoryItem.model` is nullable. `credentials/result.accessToken`
is the sole token field and is legal only for a successful credential outcome.
The tests validate actual Go encodings, decode them through the concrete wire
DTOs and reject incompatible mutations. These are interface fixtures, not
captures from a running app-server or proof of native integration.

This interface stage does not start a server or change existing CLI output.
Consent persistence, migration, publication fencing and receipt replay belong to
the shared consent package; the app-server consumes that implementation through
a backend interface. No consent store is defined in `wire`.
