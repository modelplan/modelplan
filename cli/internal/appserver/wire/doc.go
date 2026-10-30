// SPDX-License-Identifier: MIT
// Package wire defines the app-server JSON contract. JSON tags, typed enums and
// Limits are authoritative; schema generation consumes these same Go types.
// Optional/nullable DTO fields declare null:"coalesced", null:"distinct" or
// null:"forbidden". Go encoder and generated Swift tests enforce these states;
// adding a field without a declaration fails the contract checks.
// It contains no consent storage, readers, credential I/O or app preferences.
package wire
