// SPDX-License-Identifier: MIT

// Package localday gives calendar-day boundaries that hold across daylight saving. time.Date
// places a nonexistent local midnight before the gap (America/Santiago skips 00:00, and
// time.Date(…, 0, 0, 0, 0, loc) answers 23:00 of the previous day), so "the next midnight" came an
// hour early and that day's first instant belonged to the day before. Behaviour follows CodexBar
// a0f3376f5 (calendar.dateInterval(of: .day)); own code.
package localday

import "time"

// Start is the first instant of the calendar day y-m-d in loc. Out-of-range days normalise as in
// time.Date. When midnight does not exist, the day starts where the clock jumps to.
func Start(y int, m time.Month, d int, loc *time.Location) time.Time {
	// Noon names the intended day after normalisation; no zone moves its clocks at noon.
	y, m, d = time.Date(y, m, d, 12, 0, 0, 0, loc).Date()
	t := time.Date(y, m, d, 0, 0, 0, 0, loc)
	if ty, tm, td := t.Date(); ty != y || tm != m || td != d {
		// Midnight fell in a gap and was placed before it: the day begins at the transition.
		if _, end := t.ZoneBounds(); !end.IsZero() && end.After(t) {
			t = end.In(loc)
		}
	}
	return t
}

// StartOf is the first instant of t's calendar day, in t's location.
func StartOf(t time.Time) time.Time {
	y, m, d := t.Date()
	return Start(y, m, d, t.Location())
}

// Next is the first instant of the calendar day after t's, in t's location.
func Next(t time.Time) time.Time {
	y, m, d := t.Date()
	return Start(y, m, d+1, t.Location())
}
