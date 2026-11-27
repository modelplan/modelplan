// SPDX-License-Identifier: MIT
package speed

import (
	"bytes"
	"encoding/json"
)

// A transcript line is mostly content the readers never use: tool output, file text, thinking.
// encoding/json walks all of it twice (validation, then decoding) and the importer decoded each
// Claude Code line twice more (timing and accounting). reduceLine validates a line once with a
// tight scanner and copies out only the members a decoder will look at; the small result then goes
// through encoding/json as before, so the decoded values are the same:
//   - a line that is not valid JSON is refused, as json.Unmarshal refuses it;
//   - a kept member keeps its raw bytes (or a reduced copy when its spec names sub-members), in
//     order, duplicates included, so the last one wins as before;
//   - member names match as encoding/json matches struct fields (bytes.EqualFold, after unquoting).
type jspec struct {
	keys []jkey // members to keep from an object; nil keeps the value raw
	elem *jspec // for an array: the spec of each element
}

type jkey struct {
	name string
	sub  *jspec // nil keeps the member's value raw
}

// claudeLineSpec: every member ccLine (timing) and the accounting reader decode from a Claude Code
// line. Message content keeps only each block's type, which is all blockIs reads.
var claudeLineSpec = &jspec{keys: []jkey{
	{name: "type"}, {name: "timestamp"}, {name: "isSidechain"}, {name: "isMeta"}, {name: "isCompactSummary"},
	{name: "requestId"}, {name: "sessionId"}, {name: "cwd"}, {name: "effort"}, {name: "thinkingDurationMs"},
	{name: "payload"},
	{name: "message", sub: &jspec{keys: []jkey{
		{name: "id"}, {name: "model"}, {name: "stop_reason"}, {name: "usage"},
		{name: "content", sub: &jspec{elem: &jspec{keys: []jkey{{name: "type"}}}}},
	}}},
}}

// reduceLine returns the reduced line, or false when b is not one valid JSON value.
func reduceLine(b []byte, spec *jspec) ([]byte, bool) {
	r := reducer{b: b, out: make([]byte, 0, 512)}
	r.ws()
	if !r.value(spec, true, 0) {
		return nil, false
	}
	r.ws()
	if r.i != len(r.b) {
		return nil, false
	}
	return r.out, true
}

type reducer struct {
	b   []byte
	i   int
	out []byte
}

// encoding/json refuses deeper nesting.
const reduceMaxDepth = 10000

func (r *reducer) ws() {
	for r.i < len(r.b) {
		switch r.b[r.i] {
		case ' ', '\t', '\n', '\r':
			r.i++
		default:
			return
		}
	}
}

// value scans one value; when emit is set it is written to out, reduced by spec when spec applies.
func (r *reducer) value(spec *jspec, emit bool, depth int) bool {
	if r.i >= len(r.b) {
		return false
	}
	start := r.i
	switch c := r.b[r.i]; {
	case c == '{' && emit && spec != nil && spec.keys != nil:
		return r.object(spec, depth+1)
	case c == '[' && emit && spec != nil && spec.elem != nil:
		return r.array(spec.elem, depth+1)
	case c == '{':
		if !r.skipObject(depth + 1) {
			return false
		}
	case c == '[':
		if !r.skipArray(depth + 1) {
			return false
		}
	case c == '"':
		if !r.str() {
			return false
		}
	case c == '-' || (c >= '0' && c <= '9'):
		if !r.number() {
			return false
		}
	case c == 't':
		if !r.lit("true") {
			return false
		}
	case c == 'f':
		if !r.lit("false") {
			return false
		}
	case c == 'n':
		if !r.lit("null") {
			return false
		}
	default:
		return false
	}
	if emit {
		r.out = append(r.out, r.b[start:r.i]...)
	}
	return true
}

func (r *reducer) object(spec *jspec, depth int) bool {
	if depth > reduceMaxDepth {
		return false
	}
	r.i++ // {
	r.out = append(r.out, '{')
	r.ws()
	if r.i < len(r.b) && r.b[r.i] == '}' {
		r.i++
		r.out = append(r.out, '}')
		return true
	}
	first := true
	for {
		r.ws()
		ks := r.i
		if r.i >= len(r.b) || r.b[r.i] != '"' || !r.str() {
			return false
		}
		key := r.b[ks:r.i]
		r.ws()
		if r.i >= len(r.b) || r.b[r.i] != ':' {
			return false
		}
		r.i++
		r.ws()
		sub, keep := spec.match(key)
		if keep {
			if !first {
				r.out = append(r.out, ',')
			}
			first = false
			r.out = append(r.out, key...)
			r.out = append(r.out, ':')
		}
		if !r.value(sub, keep, depth) {
			return false
		}
		r.ws()
		if r.i >= len(r.b) {
			return false
		}
		switch r.b[r.i] {
		case ',':
			r.i++
		case '}':
			r.i++
			r.out = append(r.out, '}')
			return true
		default:
			return false
		}
	}
}

func (r *reducer) array(elem *jspec, depth int) bool {
	if depth > reduceMaxDepth {
		return false
	}
	r.i++ // [
	r.out = append(r.out, '[')
	r.ws()
	if r.i < len(r.b) && r.b[r.i] == ']' {
		r.i++
		r.out = append(r.out, ']')
		return true
	}
	for n := 0; ; n++ {
		if n > 0 {
			r.out = append(r.out, ',')
		}
		r.ws()
		if !r.value(elem, true, depth) {
			return false
		}
		r.ws()
		if r.i >= len(r.b) {
			return false
		}
		switch r.b[r.i] {
		case ',':
			r.i++
		case ']':
			r.i++
			r.out = append(r.out, ']')
			return true
		default:
			return false
		}
	}
}

// match: whether a member (its quoted, still escaped name) is kept, and its sub-spec.
func (s *jspec) match(quoted []byte) (*jspec, bool) {
	name := quoted[1 : len(quoted)-1]
	if bytes.IndexByte(name, '\\') >= 0 {
		var u string
		if json.Unmarshal(quoted, &u) != nil {
			return nil, false
		}
		name = []byte(u)
	}
	for i := range s.keys {
		if bytes.EqualFold(name, []byte(s.keys[i].name)) {
			return s.keys[i].sub, true
		}
	}
	return nil, false
}

func (r *reducer) skipObject(depth int) bool {
	if depth > reduceMaxDepth {
		return false
	}
	r.i++
	r.ws()
	if r.i < len(r.b) && r.b[r.i] == '}' {
		r.i++
		return true
	}
	for {
		r.ws()
		if r.i >= len(r.b) || r.b[r.i] != '"' || !r.str() {
			return false
		}
		r.ws()
		if r.i >= len(r.b) || r.b[r.i] != ':' {
			return false
		}
		r.i++
		r.ws()
		if !r.value(nil, false, depth) {
			return false
		}
		r.ws()
		if r.i >= len(r.b) {
			return false
		}
		switch r.b[r.i] {
		case ',':
			r.i++
		case '}':
			r.i++
			return true
		default:
			return false
		}
	}
}

func (r *reducer) skipArray(depth int) bool {
	if depth > reduceMaxDepth {
		return false
	}
	r.i++
	r.ws()
	if r.i < len(r.b) && r.b[r.i] == ']' {
		r.i++
		return true
	}
	for {
		r.ws()
		if !r.value(nil, false, depth) {
			return false
		}
		r.ws()
		if r.i >= len(r.b) {
			return false
		}
		switch r.b[r.i] {
		case ',':
			r.i++
		case ']':
			r.i++
			return true
		default:
			return false
		}
	}
}

// strPlain marks the bytes a string may hold without a closer look.
var strPlain = func() (t [256]bool) {
	for c := 0x20; c < 256; c++ {
		t[c] = c != '"' && c != '\\'
	}
	return
}()

// str scans a string at r.i (its opening quote), with encoding/json's escape and control rules.
func (r *reducer) str() bool {
	b := r.b
	i := r.i + 1
	for {
		for i < len(b) && strPlain[b[i]] {
			i++
		}
		if i >= len(b) {
			return false
		}
		switch b[i] {
		case '"':
			r.i = i + 1
			return true
		case '\\':
			if i+1 >= len(b) {
				return false
			}
			switch b[i+1] {
			case '"', '\\', '/', 'b', 'f', 'n', 'r', 't':
				i += 2
			case 'u':
				if i+6 > len(b) {
					return false
				}
				for _, h := range b[i+2 : i+6] {
					if !(h >= '0' && h <= '9' || h >= 'a' && h <= 'f' || h >= 'A' && h <= 'F') {
						return false
					}
				}
				i += 6
			default:
				return false
			}
		default: // a control character
			return false
		}
	}
}

func (r *reducer) number() bool {
	b, i := r.b, r.i
	if b[i] == '-' {
		i++
	}
	digits := func() bool {
		s := i
		for i < len(b) && b[i] >= '0' && b[i] <= '9' {
			i++
		}
		return i > s
	}
	switch {
	case i < len(b) && b[i] == '0':
		i++
	case i < len(b) && b[i] >= '1' && b[i] <= '9':
		digits()
	default:
		return false
	}
	if i < len(b) && b[i] == '.' {
		i++
		if !digits() {
			return false
		}
	}
	if i < len(b) && (b[i] == 'e' || b[i] == 'E') {
		i++
		if i < len(b) && (b[i] == '+' || b[i] == '-') {
			i++
		}
		if !digits() {
			return false
		}
	}
	r.i = i
	return true
}

func (r *reducer) lit(s string) bool {
	if !bytes.HasPrefix(r.b[r.i:], []byte(s)) {
		return false
	}
	r.i += len(s)
	return true
}

// reduceClaudeLines switches the Claude Code readers to reduced lines; tests turn it off to compare
// with decoding whole lines.
var reduceClaudeLines = true

// claudeDoc: what the Claude Code readers decode from line b, or nil when b is not valid JSON.
func claudeDoc(b []byte) []byte {
	if !reduceClaudeLines {
		return b // the whole line, as before; json.Unmarshal refuses it if it is not JSON
	}
	doc, ok := reduceLine(b, claudeLineSpec)
	if !ok {
		return nil
	}
	return doc
}
