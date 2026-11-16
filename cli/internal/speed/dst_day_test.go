// SPDX-License-Identifier: MIT
package speed

import (
	"testing"
	"time"
	_ "time/tzdata"
)

// CodexBar a0f3376f5 (behaviour only): on a day whose midnight daylight saving skips, the local day
// starts when the clock jumps, not an hour earlier inside the previous day, and the day boundary
// that refreshes the view lands on that instant too.
func TestDayStartAcrossSkippedMidnight(t *testing.T) {
	santiago, err := time.LoadLocation("America/Santiago")
	if err != nil {
		t.Fatal(err)
	}
	old := time.Local
	time.Local = santiago
	t.Cleanup(func() { time.Local = old })
	at := time.Date(2026, 9, 6, 15, 0, 0, 0, time.UTC)  // 12:00 on the 23-hour day
	want := time.Date(2026, 9, 6, 4, 0, 0, 0, time.UTC) // 01:00 -03, the first instant of 6 September
	if got := dayStart(at); !got.Equal(want) {
		t.Fatalf("dayStart = %v, want %v", got, want)
	}
	v := PerfView{OK: true, Now: time.Date(2026, 9, 6, 2, 0, 0, 0, time.UTC), Ledger: PerfLedger{Rows: []PerfRow{{}}}} // 22:00 on 5 September
	found := false
	for _, b := range v.Boundaries() {
		if b.Equal(want) {
			found = true
		}
		if b.Equal(want.Add(-time.Hour)) {
			t.Fatalf("midnight boundary an hour early: %v", b)
		}
	}
	if !found {
		t.Fatalf("no boundary at the start of 6 September: %v", v.Boundaries())
	}
}
