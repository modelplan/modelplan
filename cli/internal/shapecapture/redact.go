// SPDX-License-Identifier: MIT

// Package shapecapture writes structure-only samples of the local files our readers consume, so
// reader fixtures can follow real shapes. It keeps key names from a per-tool allow-list, value
// types, array lengths, short non-personal tokens and relative timestamps. Everything else is
// dropped. A final pattern guard refuses any output that still looks like a secret, an email or
// a path.
package shapecapture

import (
	"encoding/json"
	"math"
	"regexp"
	"sort"
	"strconv"
	"time"
)

// Kind says how an allow-listed key's scalar value is written.
type Kind string

const (
	// Struct keeps the key; scalars become type placeholders, objects and arrays are walked.
	Struct Kind = "struct"
	// Enum keeps a short non-personal token (status, role, model id); anything else becomes a placeholder.
	Enum Kind = "enum"
	// Time turns a timestamp into an offset from capture time.
	Time Kind = "time"
)

// Allow maps a key name to how its value is kept. Keys not listed are dropped.
type Allow map[string]Kind

const (
	maxDepth  = 12
	maxArray  = 20
	strPlace  = "<string>"
	maxKeyLen = 48
)

var (
	keyShape  = regexp.MustCompile(`^[A-Za-z_$][A-Za-z0-9_$]{0,47}$`)
	enumShape = regexp.MustCompile(`^[a-z][a-z0-9_.:-]{0,31}$`)
	digitRun  = regexp.MustCompile(`[0-9]{9,}`)
	denyKey   = regexp.MustCompile(`(?i)(token|secret|passw|cookie|authorization|api_?key|bearer|credential|refresh|session_?id|email|path|cwd|prompt|text|content|account|uuid|name|user|org|project|title|dir|file|url|host|ip$)`)
	guardPats = []*regexp.Regexp{
		regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`),                   // email
		regexp.MustCompile(`(?i)(^|[^A-Za-z0-9])(/home/|/users/|/root/|/var/|/tmp/|/mnt/|~/)`), // unix path
		regexp.MustCompile(`(?i)[A-Z]:\\`),                                                     // windows path
		regexp.MustCompile(`(?i)https?://`),                                                    // url
		regexp.MustCompile(`eyJ[A-Za-z0-9_-]{8,}`),                                             // jwt
		regexp.MustCompile(`(?i)\b(sk|pk|ghp|gho|ghs|xox[a-z]|AKIA|AIza)[-_A-Za-z0-9]{10,}`),   // vendor keys
		regexp.MustCompile(`(?i)bearer\s+\S+`),                                                 // bearer
		regexp.MustCompile(`[A-Fa-f0-9]{24,}`),                                                 // long hex
		regexp.MustCompile(`[A-Za-z0-9+/_=-]{32,}`),                                            // long opaque
		regexp.MustCompile(`(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`), // uuid
		regexp.MustCompile(`(?i)-----BEGIN`),                                                   // pem
	}
)

// Report is what one redaction pass kept and dropped.
type Report struct {
	Kept    map[string]Kind `json:"-"`
	Dropped int             `json:"-"`
}

func newReport() *Report { return &Report{Kept: map[string]Kind{}} }

// Redactor shapes decoded JSON against an allow-list.
type Redactor struct {
	Allow Allow
	Now   time.Time
	rep   *Report
}

// NewRedactor builds a redactor; Report accumulates over every Shape call.
func NewRedactor(a Allow, now time.Time) *Redactor {
	return &Redactor{Allow: a, Now: now, rep: newReport()}
}

// Report returns the accumulated kept keys and dropped-key count.
func (r *Redactor) Report() *Report { return r.rep }

// Shape redacts one decoded JSON value (the top level must be an object or array).
func (r *Redactor) Shape(v any) any { return r.walk(v, Struct, 0) }

// KeyOK reports whether name is a legal, non-personal key spelling.
func KeyOK(name string) bool {
	if !keyShape.MatchString(name) || len(name) > maxKeyLen {
		return false
	}
	return !GuardHit(name)
}

// GuardHit reports whether s looks like an email, path, URL, secret or id.
func GuardHit(s string) bool {
	for _, p := range guardPats {
		if p.MatchString(s) {
			return true
		}
	}
	return false
}

func (r *Redactor) walk(v any, kind Kind, depth int) any {
	if depth > maxDepth {
		r.rep.Dropped++
		return nil
	}
	switch x := v.(type) {
	case map[string]any:
		out := map[string]any{}
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			kk, ok := r.Allow[k]
			if !ok || !KeyOK(k) {
				r.rep.Dropped++
				continue
			}
			if kk == Enum && denyKey.MatchString(k) {
				kk = Struct
			}
			r.rep.Kept[k] = kk
			out[k] = r.walk(x[k], kk, depth+1)
		}
		return out
	case []any:
		n := len(x)
		if n > maxArray {
			n = maxArray
		}
		out := make([]any, 0, n)
		for _, e := range x[:n] {
			out = append(out, r.walk(e, kind, depth+1))
		}
		return out
	case string:
		return r.str(x, kind)
	case json.Number:
		f, err := x.Float64()
		if err != nil {
			return 0
		}
		return r.num(f, x.String(), kind)
	case float64:
		return r.num(x, strconv.FormatFloat(x, 'f', -1, 64), kind)
	case bool, nil:
		return x
	}
	r.rep.Dropped++
	return nil
}

func (r *Redactor) str(s string, kind Kind) any {
	if s == "" {
		return ""
	}
	switch kind {
	case Time:
		for _, layout := range []string{time.RFC3339Nano, time.RFC3339} {
			if t, err := time.Parse(layout, s); err == nil {
				return offset(t, r.Now)
			}
		}
	case Enum:
		if enumShape.MatchString(s) && !digitRun.MatchString(s) && !GuardHit(s) {
			return s
		}
	}
	return strPlace
}

func offset(t, now time.Time) string {
	d := int64(math.Round(t.Sub(now).Seconds()/60)) * 60
	return strconv.FormatInt(d, 10) + "s"
}

// num keeps type and sign: 0 stays 0, other integers become +/-1, fractions +/-1.5.
// A Time number is an epoch (seconds or milliseconds) and becomes its offset in the same unit.
func (r *Redactor) num(f float64, lit string, kind Kind) any {
	if kind == Time && f > 0 {
		if f > 1e11 {
			return int64(math.Round((f-float64(r.Now.UnixMilli()))/60000)) * 60000
		}
		if f > 1e8 {
			return int64(math.Round((f-float64(r.Now.Unix()))/60)) * 60
		}
	}
	isInt := f == math.Trunc(f) && !containsAny(lit, ".eE")
	switch {
	case f == 0:
		if isInt {
			return 0
		}
		return 0.0
	case f > 0 && isInt:
		return 1
	case f < 0 && isInt:
		return -1
	case f > 0:
		return 1.5
	}
	return -1.5
}

func containsAny(s, chars string) bool {
	for _, c := range s {
		for _, d := range chars {
			if c == d {
				return true
			}
		}
	}
	return false
}

// Verify is the last guard over a serialized sample: it fails if any string value or key in the
// output looks like a secret, email, path, URL or id, whatever the allow-list said.
func Verify(doc []byte) error {
	var v any
	dec := json.NewDecoder(bytesReader(doc))
	dec.UseNumber()
	if err := dec.Decode(&v); err != nil {
		return errUnreadable
	}
	return verifyValue(v)
}
