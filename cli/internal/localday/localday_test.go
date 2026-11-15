// SPDX-License-Identifier: MIT
package localday

import (
	"testing"
	"time"
	_ "time/tzdata"
)

func zone(t *testing.T, name string) *time.Location {
	t.Helper()
	l, err := time.LoadLocation(name)
	if err != nil {
		t.Fatal(err)
	}
	return l
}

func utc(t *testing.T, s string) time.Time {
	t.Helper()
	v, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

// CodexBar a0f3376f5 (behaviour only): a calendar day starts at its first instant even when daylight
// saving skips midnight, and ends where the next one starts, so days can be 23 or 25 hours long.
// Santiago skips 2026-09-06 00:00 (clocks go to 01:00); New York repeats 01:00-02:00 on 2026-11-01.
func TestCalendarDayBoundaries(t *testing.T) {
	santiago, ny := zone(t, "America/Santiago"), zone(t, "America/New_York")
	for _, tc := range []struct {
		name       string
		at         time.Time
		start, end string
	}{
		{"skipped midnight: the day starts at 01:00", utc(t, "2026-09-06T15:00:00Z").In(santiago), "2026-09-06T04:00:00Z", "2026-09-07T03:00:00Z"},
		{"the day before ends at the skipped midnight, not an hour early", utc(t, "2026-09-06T03:30:00Z").In(santiago), "2026-09-05T04:00:00Z", "2026-09-06T04:00:00Z"},
		{"fall back: a 25-hour day", utc(t, "2026-11-01T12:00:00Z").In(ny), "2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z"},
		{"spring forward at 02:00: a 23-hour day", utc(t, "2026-03-08T12:00:00Z").In(ny), "2026-03-08T05:00:00Z", "2026-03-09T04:00:00Z"},
		{"ordinary day", utc(t, "2026-10-14T12:00:00Z").In(ny), "2026-10-14T04:00:00Z", "2026-10-15T04:00:00Z"},
		{"month end rolls over", utc(t, "2026-10-31T23:00:00Z").In(time.UTC), "2026-10-31T00:00:00Z", "2026-11-01T00:00:00Z"},
	} {
		if got := StartOf(tc.at); !got.Equal(utc(t, tc.start)) {
			t.Errorf("%s: start = %v, want %s", tc.name, got.UTC(), tc.start)
		}
		if got := Next(tc.at); !got.Equal(utc(t, tc.end)) {
			t.Errorf("%s: next = %v, want %s", tc.name, got.UTC(), tc.end)
		}
		if got := Next(tc.at); !got.After(tc.at) {
			t.Errorf("%s: next %v is not after %v", tc.name, got, tc.at)
		}
	}
	// Day arithmetic: 30 days back from a day after the skipped midnight lands on whole days.
	if got := Start(2026, time.September, 6, santiago); !got.Equal(utc(t, "2026-09-06T04:00:00Z")) {
		t.Errorf("start of skipped-midnight day = %v", got.UTC())
	}
	if got := Start(2026, time.September, 36, santiago); !got.Equal(utc(t, "2026-10-06T03:00:00Z")) {
		t.Errorf("normalised day = %v", got.UTC())
	}
}
