// SPDX-License-Identifier: MIT

// Package tokenacct is local token accounting with ccusage's definitions
// (github.com/ccusage/ccusage, MIT, Copyright (c) 2025 ryoppippi; licence in
// LICENSES/ccusage-MIT.txt). Buckets, Windows and Summarize are ModelPlan's own
// code and are tool-neutral, so every reader family can share them. The per-tool
// parsers in this package port ccusage's Rust adapters at ccusage@58866ba6
// (58866ba681343634ab6e5add61f18f3b70aa98f7); each file names its upstream file.
package tokenacct

import (
	"math"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localday"
)

// Reference names the ccusage revision whose accounting this package matches.
const Reference = "ccusage@58866ba681343634ab6e5add61f18f3b70aa98f7"

// Buckets are ccusage's token buckets. Input excludes cached prompt tokens;
// cache reads and writes are separate; Reasoning is ccusage's "extra total"
// (thoughts or reasoning, plus any part of a reported total the other buckets
// do not explain). Total is always the sum of the five buckets, the same
// definition as ccusage's and Tokei's "total tokens".
type Buckets struct {
	Input      int64 `json:"inputTokens"`
	CacheRead  int64 `json:"cacheReadTokens"`
	CacheWrite int64 `json:"cacheWriteTokens"`
	Output     int64 `json:"outputTokens"`
	Reasoning  int64 `json:"reasoningTokens"`
	Total      int64 `json:"totalTokens"`
}

func sat(a, b int64) int64 {
	if b > 0 && a > math.MaxInt64-b {
		return math.MaxInt64
	}
	return a + b
}

// Sum is input + cache read + cache write + output + reasoning, saturating.
func (b Buckets) Sum() int64 {
	return sat(sat(sat(sat(b.Input, b.CacheRead), b.CacheWrite), b.Output), b.Reasoning)
}

// Add adds x bucket by bucket and keeps Total equal to the sum.
func (b *Buckets) Add(x Buckets) {
	b.Input = sat(b.Input, x.Input)
	b.CacheRead = sat(b.CacheRead, x.CacheRead)
	b.CacheWrite = sat(b.CacheWrite, x.CacheWrite)
	b.Output = sat(b.Output, x.Output)
	b.Reasoning = sat(b.Reasoning, x.Reasoning)
	b.Total = b.Sum()
}

// Zero reports whether every bucket is zero.
func (b Buckets) Zero() bool { return b.Sum() == 0 }

// Entry is one counted usage record at its own time.
type Entry struct {
	At time.Time
	Buckets
}

// Windows are calendar-day windows in the machine's local time zone: today,
// the last 7 days and the last 30 days, each including today (ccusage's
// daily report summed over those days).
type Windows struct {
	Reference string  `json:"reference"`
	Today     Buckets `json:"today"`
	Last7d    Buckets `json:"last7Days"`
	Last30d   Buckets `json:"last30Days"`
	Entries   int     `json:"entries"`
}

// Summarize sums entries into windows by local calendar day. Entries after
// today or before the 30-day window are left out.
func Summarize(entries []Entry, now time.Time) Windows {
	loc := time.Local
	n := now.In(loc)
	y, m, d := n.Date()
	today, end := localday.Start(y, m, d, loc), localday.Next(n)
	from7, from30 := localday.Start(y, m, d-6, loc), localday.Start(y, m, d-29, loc)
	w := Windows{Reference: Reference}
	for _, e := range entries {
		if e.At.Before(from30) || !e.At.Before(end) {
			continue
		}
		w.Entries++
		w.Last30d.Add(e.Buckets)
		if !e.At.Before(from7) {
			w.Last7d.Add(e.Buckets)
		}
		if !e.At.Before(today) {
			w.Today.Add(e.Buckets)
		}
	}
	return w
}

// fallback is ccusage's apply_total_token_fallback (ccusage-core utils.rs):
// a reported total larger than the known buckets plus extra adds the missing
// tokens to output when output is zero, else to extra.
func fallback(input, output, cacheWrite, cacheRead, extra, total int64) (int64, int64) {
	known := sat(sat(sat(sat(input, output), cacheWrite), cacheRead), extra)
	missing := total - known
	if total <= known || missing <= 0 {
		return output, extra
	}
	if output == 0 {
		return missing, extra
	}
	return output, sat(extra, missing)
}

func entry(at time.Time, b Buckets) Entry {
	b.Total = b.Sum()
	return Entry{At: at, Buckets: b}
}
