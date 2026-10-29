// SPDX-License-Identifier: MIT
package wire

import "log/slog"

// Logging/formatting is deliberately separate from the one intentional JSON
// wire encoding. Do not include any field from this credential-bearing value.
func (CredentialResult) String() string       { return "CredentialResult{redacted}" }
func (CredentialResult) GoString() string     { return "CredentialResult{redacted}" }
func (CredentialResult) LogValue() slog.Value { return slog.StringValue("CredentialResult{redacted}") }
