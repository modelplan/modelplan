// SPDX-License-Identifier: MIT
// Package rows defines the CLI-owned display projection in
// schema/app-cli/rows-design.md. It is independent of readers, consent storage,
// and snapshot serialization so those adapters can share one immutable Input
// without import cycles. Building rows must never collect, allocate identities,
// or change quota --json. This first change defines types only.
package rows
