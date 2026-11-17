// SPDX-License-Identifier: MIT
// Portions ported from ccusage (github.com/ccusage/ccusage, MIT, Copyright (c)
// 2025 ryoppippi) at 58866ba681343634ab6e5add61f18f3b70aa98f7:
// rust/crates/ccusage-core/src/date_utils.rs (parse_ts_timestamp) and
// rust/adapters/common/src/jsonl.rs (lenient field rules). Modified for Go.

package tokenacct

import (
	"bytes"
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"time"
)

// parseTS is ccusage's parse_ts_timestamp: only YYYY-MM-DDTHH:MM:SS, an
// optional exactly-three-digit fraction, and Z or ±HH:MM. Anything else is
// not a timestamp, and the caller uses its fallback time.
func parseTS(s string) (time.Time, bool) {
	b := []byte(s)
	var millis, tzAt int
	switch {
	case (len(b) == 20 || len(b) == 25) && (b[19] == 'Z' || b[19] == '+' || b[19] == '-'):
		tzAt = 19
	case (len(b) == 24 || len(b) == 29) && b[19] == '.':
		v, ok := digits(b[20:23])
		if !ok {
			return time.Time{}, false
		}
		millis, tzAt = v, 23
	default:
		return time.Time{}, false
	}
	if b[4] != '-' || b[7] != '-' || b[10] != 'T' || b[13] != ':' || b[16] != ':' {
		return time.Time{}, false
	}
	year, ok1 := digits(b[0:4])
	month, ok2 := digits(b[5:7])
	day, ok3 := digits(b[8:10])
	hour, ok4 := digits(b[11:13])
	minute, ok5 := digits(b[14:16])
	second, ok6 := digits(b[17:19])
	if !(ok1 && ok2 && ok3 && ok4 && ok5 && ok6) || hour > 23 || minute > 59 || second > 59 {
		return time.Time{}, false
	}
	if month < 1 || month > 12 || day < 1 || day > daysIn(year, month) {
		return time.Time{}, false
	}
	offset := 0
	if tz := b[tzAt:]; !(len(tz) == 1 && tz[0] == 'Z') {
		if len(tz) != 6 || (tz[0] != '+' && tz[0] != '-') || tz[3] != ':' {
			return time.Time{}, false
		}
		h, okh := digits(tz[1:3])
		m, okm := digits(tz[4:6])
		if !okh || !okm || h > 23 || m > 59 {
			return time.Time{}, false
		}
		offset = h*60 + m
		if tz[0] == '-' {
			offset = -offset
		}
	}
	t := time.Date(year, time.Month(month), day, hour, minute, second, millis*int(time.Millisecond), time.UTC)
	return t.Add(-time.Duration(offset) * time.Minute), true
}

func digits(b []byte) (int, bool) {
	v := 0
	for _, c := range b {
		if c < '0' || c > '9' {
			return 0, false
		}
		v = v*10 + int(c-'0')
	}
	return v, true
}

func daysIn(year, month int) int {
	switch month {
	case 1, 3, 5, 7, 8, 10, 12:
		return 31
	case 4, 6, 9, 11:
		return 30
	}
	if (year%4 == 0 && year%100 != 0) || year%400 == 0 {
		return 29
	}
	return 28
}

// str is serde's Value::as_str: the verbatim string, or false for any other type.
func str(raw json.RawMessage) (string, bool) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '"' {
		return "", false
	}
	var s string
	if json.Unmarshal(raw, &s) != nil {
		return "", false
	}
	return s, true
}

// nonEmpty is ccusage's non_empty_json_string: a trimmed, non-empty string.
func nonEmpty(raw json.RawMessage) string {
	s, _ := str(raw)
	return strings.TrimSpace(s)
}

// u64 is serde's Value::as_u64 (jsonl::lenient_u64): a non-negative integer
// literal, else 0. Floats, strings, nulls and negatives are 0.
func u64(raw json.RawMessage) int64 {
	n, err := strconv.ParseUint(string(bytes.TrimSpace(raw)), 10, 64)
	if err != nil {
		return 0
	}
	return clampU(n)
}

// f64u is Value::as_f64 then max(0).trunc() as u64 (Gemini's value_u64): any
// finite JSON number, truncated. ok is false for a non-number.
func f64u(raw json.RawMessage) (int64, bool) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || !(raw[0] == '-' || (raw[0] >= '0' && raw[0] <= '9')) {
		return 0, false
	}
	f, err := strconv.ParseFloat(string(raw), 64)
	if err != nil || math.IsInf(f, 0) || math.IsNaN(f) {
		return 0, false
	}
	if f <= 0 {
		return 0, true
	}
	if f >= math.MaxInt64 {
		return math.MaxInt64, true
	}
	return int64(f), true
}

func clampU(n uint64) int64 {
	if n > math.MaxInt64 {
		return math.MaxInt64
	}
	return int64(n)
}

// present is serde's Option<Value>: a missing field or JSON null is absent.
func present(raw json.RawMessage) bool {
	raw = bytes.TrimSpace(raw)
	return len(raw) > 0 && string(raw) != "null"
}

// lines splits JSONL content into non-empty lines.
func lines(b []byte) [][]byte {
	out := [][]byte{}
	for _, line := range bytes.Split(b, []byte{'\n'}) {
		if line = bytes.TrimSpace(line); len(line) > 0 {
			out = append(out, line)
		}
	}
	return out
}
