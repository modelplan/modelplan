// SPDX-License-Identifier: MIT
package readers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"regexp"
)

var projectSelector = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}$`)

// object rejects duplicate keys, null, unknown keys and trailing JSON. Nested
// objects are checked separately so Go's usual last-key-wins decoding cannot
// silently change the approved body. It stores no body after validation.
func object(b []byte, allowed ...string) (map[string]json.RawMessage, bool) {
	d := json.NewDecoder(bytes.NewReader(b))
	token, err := d.Token()
	if err != nil || token != json.Delim('{') {
		return nil, false
	}
	result := map[string]json.RawMessage{}
	for d.More() {
		key, err := d.Token()
		if err != nil {
			return nil, false
		}
		name, ok := key.(string)
		if !ok {
			return nil, false
		}
		if _, duplicate := result[name]; duplicate {
			return nil, false
		}
		known := false
		for _, a := range allowed {
			if name == a {
				known = true
				break
			}
		}
		if !known {
			return nil, false
		}
		var value json.RawMessage
		if d.Decode(&value) != nil {
			return nil, false
		}
		result[name] = value
	}
	if token, err = d.Token(); err != nil || token != json.Delim('}') {
		return nil, false
	}
	if _, err = d.Token(); err != io.EOF {
		return nil, false
	}
	return result, true
}
func stringIs(raw json.RawMessage, expected string) bool {
	var s string
	return json.Unmarshal(raw, &s) == nil && s == expected
}
func validProject(raw json.RawMessage) bool {
	var s string
	return json.Unmarshal(raw, &s) == nil && projectSelector.MatchString(s)
}
func validPOSTBody(kind string, b []byte) bool {
	switch kind {
	case "cursor":
		return bytes.Equal(b, []byte("{}"))
	case "gemini_load":
		top, ok := object(b, "mode", "metadata", "cloudaicompanionProject")
		if !ok || !stringIs(top["mode"], "HEALTH_CHECK") {
			return false
		}
		meta, ok := object(top["metadata"], "ideType", "pluginType")
		if !ok || !stringIs(meta["ideType"], "GEMINI_CLI") || !stringIs(meta["pluginType"], "GEMINI") {
			return false
		}
		if project, exists := top["cloudaicompanionProject"]; exists && !validProject(project) {
			return false
		}
		return true
	case "gemini_quota":
		top, ok := object(b, "project")
		return ok && validProject(top["project"])
	}
	return false
}
func (p requestPin) validBody(r *http.Request) bool {
	if p.body == "" {
		return (r.Body == nil || r.Body == http.NoBody) && r.ContentLength == 0 && len(r.TransferEncoding) == 0
	}
	if r.Body == nil || len(r.TransferEncoding) != 0 {
		return false
	}
	b, err := io.ReadAll(io.LimitReader(r.Body, 4097))
	r.Body.Close()
	r.Body = io.NopCloser(bytes.NewReader(b))
	return err == nil && len(b) <= 4096 && r.ContentLength == int64(len(b)) && validPOSTBody(p.body, b)
}
