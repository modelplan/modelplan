// SPDX-License-Identifier: MIT
package appserver

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"unicode/utf8"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

var errFrame = errors.New("invalid_frame")

// readFrame never appends beyond the cap and rejects a too-long unterminated
// line as soon as the next byte arrives. EOF with a partial line is invalid.
func readFrame(r *bufio.Reader) ([]byte, error) {
	var frame []byte
	for {
		// ReadSlice otherwise waits for a whole buffer after the cap, even if
		// the first excess byte has already arrived without a newline.
		if len(frame)+r.Size() > wire.MaxFrameBytes {
			value, err := r.ReadByte()
			if err != nil {
				return nil, errFrame
			}
			if len(frame) == wire.MaxFrameBytes {
				return nil, errFrame
			}
			frame = appendFrame(frame, []byte{value})
			if value == '\n' {
				frame = frame[:len(frame)-1]
				if !utf8.Valid(frame) {
					return nil, errFrame
				}
				return frame, nil
			}
			continue
		}
		part, err := r.ReadSlice('\n')
		if len(frame)+len(part) > wire.MaxFrameBytes {
			return nil, errFrame
		}
		frame = appendFrame(frame, part)
		if err == nil {
			frame = bytes.TrimSuffix(frame, []byte{'\n'})
			if !utf8.Valid(frame) {
				return nil, errFrame
			}
			return frame, nil
		}
		if errors.Is(err, bufio.ErrBufferFull) {
			continue
		}
		if errors.Is(err, io.EOF) && len(frame) == 0 {
			return nil, io.EOF
		}
		return nil, errFrame
	}
}

func decodeRequest(frame []byte) (wire.Request, error) {
	var request wire.Request
	if len(bytes.TrimSpace(frame)) == 0 || bytes.TrimSpace(frame)[0] != '{' {
		return request, errFrame
	}
	// Reject duplicate top-level keys before decoding a permission operation.
	d := json.NewDecoder(bytes.NewReader(frame))
	if _, err := d.Token(); err != nil {
		return request, errFrame
	}
	seen := map[string]bool{}
	for d.More() {
		k, err := d.Token()
		if err != nil {
			return request, errFrame
		}
		key, ok := k.(string)
		if !ok || seen[key] {
			return request, errFrame
		}
		seen[key] = true
		var value json.RawMessage
		if err := d.Decode(&value); err != nil {
			return request, errFrame
		}
	}
	if _, err := d.Token(); err != nil {
		return request, errFrame
	}
	if err := d.Decode(new(any)); !errors.Is(err, io.EOF) {
		return request, errFrame
	}
	if err := json.Unmarshal(frame, &request); err != nil {
		return request, errFrame
	}
	if request.JSONRPC != wire.JSONRPC || request.Method == "" {
		return request, errFrame
	}
	for key := range seen {
		if key != "jsonrpc" && key != "id" && key != "method" && key != "params" {
			return request, errFrame
		}
	}
	if len(request.ID) > 0 && !validID(request.ID) {
		return request, errFrame
	}
	return request, nil
}

func validID(id []byte) bool {
	if len(id) == 0 || len(id) > 1024 {
		return false
	}
	if id[0] == '"' {
		var s string
		return json.Unmarshal(id, &s) == nil
	}
	// JSON-RPC identifiers are strings or integral numbers, never null/objects.
	for i, c := range id {
		if c < '0' || c > '9' {
			if i == 0 && c == '-' && len(id) > 1 {
				continue
			}
			return false
		}
	}
	return json.Valid(id)
}

func params[T any](raw json.RawMessage) (T, error) {
	var out T
	if len(raw) == 0 {
		raw = json.RawMessage(`{}`)
	}
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return out, errFrame
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	if err := d.Decode(&out); err != nil {
		return out, errFrame
	}
	return out, nil
}

// Keep backing-array capacity inside the same frame cap as its length.
func appendFrame(frame, part []byte) []byte {
	need := len(frame) + len(part)
	if need > cap(frame) {
		capacity := cap(frame) * 2
		if capacity < need {
			capacity = need
		}
		if capacity > wire.MaxFrameBytes {
			capacity = wire.MaxFrameBytes
		}
		grown := make([]byte, len(frame), capacity)
		copy(grown, frame)
		frame = grown
	}
	return append(frame, part...)
}

func requestKey(id wire.ID) string {
	if len(id) > 0 && id[0] == '"' {
		var text string
		_ = json.Unmarshal(id, &text)
		return "s:" + text
	}
	if string(id) == "-0" {
		return "n:0"
	}
	return "n:" + string(id)
}
