// SPDX-License-Identifier: MIT
package shapecapture

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
)

var (
	errUnreadable = errors.New("shape_unreadable")
	errGuard      = errors.New("pattern_guard_hit")
)

func bytesReader(b []byte) io.Reader { return bytes.NewReader(b) }

func verifyValue(v any) error {
	switch x := v.(type) {
	case map[string]any:
		for k, e := range x {
			if !KeyOK(k) {
				return errGuard
			}
			if err := verifyValue(e); err != nil {
				return err
			}
		}
	case []any:
		for _, e := range x {
			if err := verifyValue(e); err != nil {
				return err
			}
		}
	case string:
		if x != strPlace && GuardHit(x) {
			return errGuard
		}
	}
	return nil
}

func marshal(v any, indent bool) ([]byte, error) {
	var b bytes.Buffer
	e := json.NewEncoder(&b)
	e.SetEscapeHTML(false)
	if indent {
		e.SetIndent("", "  ")
	}
	if err := e.Encode(v); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}
