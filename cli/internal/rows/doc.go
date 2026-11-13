// SPDX-License-Identifier: MIT
// Package rows builds the CLI-owned display projection from immutable facts.
// It is independent of readers, consent storage and snapshot serialization.
// Build performs no I/O, allocation of identities or mutation of its input.
// The publishing adapter owns consent retry/fencing; quota --json is separate.
package rows
