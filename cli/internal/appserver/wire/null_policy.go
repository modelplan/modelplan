// SPDX-License-Identifier: MIT
package wire

import "fmt"

// NullPolicy is declared by the null tag on optional/nullable wire fields.
// Coalesced permits one representation for null and absence; distinct requires
// three states (absent, null, value); forbidden makes explicit null invalid.
// Required-field and contextual authorization rules still apply independently.
type NullPolicy string

const (
	NullCoalesced NullPolicy = "coalesced"
	NullDistinct  NullPolicy = "distinct"
	NullForbidden NullPolicy = "forbidden"
)

func ParseNullPolicy(value string) (NullPolicy, error) {
	switch policy := NullPolicy(value); policy {
	case NullCoalesced, NullDistinct, NullForbidden:
		return policy, nil
	default:
		return "", fmt.Errorf("optional wire field needs null:\"coalesced\", null:\"distinct\" or null:\"forbidden\" (got %q)", value)
	}
}
