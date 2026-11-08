package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// D63: the cockpit's peak-hours line reads the same published windows as the advice, declared plans only.
func TestPeaksFindTheCurrentOrNextRaisedRateWindow(t *testing.T) {
	d, at := windowDigest()
	report := quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "pro", Region: "china"}, {Source: "native:synthetic", Plan: "max"}}}
	got := Peaks(d, report, at, 24*time.Hour)
	if len(got) != 1 || got[0].Plan != "pro" || !got[0].StartsAt.Equal(at) || got[0].EndsAt == nil || !got[0].EndsAt.Equal(at.Add(time.Minute)) || got[0].Status != "CONFIRMED" {
		t.Fatalf("in a peak now, ending at the cheaper window: %+v", got)
	}
	later := at.Add(2 * time.Minute)
	got = Peaks(d, report, later, 24*time.Hour)
	if len(got) != 1 || !got[0].StartsAt.Equal(at.Add(8*time.Hour)) || got[0].EndsAt != nil {
		t.Fatalf("the next raised window, open-ended within the horizon: %+v", got)
	}
	if got := Peaks(d, report, later, time.Hour); len(got) != 0 {
		t.Fatalf("nothing raised within an hour: %+v", got)
	}
	if got := Peaks(d, quota.Report{Accounts: []quota.Account{{Source: "native:synthetic", Plan: "pro"}}}, at, 24*time.Hour); len(got) != 0 {
		t.Fatalf("only declared plans: %+v", got)
	}
	if got := Peaks(d, report, at.Add(48*time.Hour), 24*time.Hour); len(got) != 0 {
		t.Fatalf("outside the horizon the rate is unknown: %+v", got)
	}
	if got := Peaks(nil, report, at, 24*time.Hour); len(got) != 0 {
		t.Fatalf("no publication: %+v", got)
	}
}
